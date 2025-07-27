import asyncio
import datetime
import os
import logging

from django.conf import settings
from django.core.cache import cache
from django.core.exceptions import BadRequest
from django.db.models import Q, F
from rest_framework import viewsets, generics, filters, mixins
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.exceptions import APIException
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import status
from django.forms import ValidationError
from django.db import IntegrityError
from pktools.helpers import time_it_and_log
from parser_kaspi.tasks import notify_user_registration_telegram_channel, healthcheck_other_services
from .service import sms_service
from .service.kaspi.kaspi_common_methods import request_sms_verification_code_to_login_in_kaspi, \
    verify_kaspi_cabinet_login_security_code, create_new_user_and_send_password_to_email
from .service.project_logger import format_exception
from .service.read_emails_service import check_email_and_try_to_read_its_content
from .service.string import filter_phone_number
from mixins import CustomViewSet
from .models import KaspiProduct, ProductPrice, Merchant, CustomUser, competitors_to_exclude_validator, Comment, \
    UserNotification
from .permissions import IsOwnerOrReadOnly, ReadOnly
from .serializers import (KaspiProductSerializer, ProductPriceSerializer,
                          MerchantSerializer, CustomUserSerializer, ChangePasswordSerializer, CommentSerializer,
                          UserNotificationSerializer, LoginPayloadSerializer)
from .service.kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods
from .service.project_exceptions import MerchantSettingsRetrieveException, IncorrectLoginException, XmlFileLinkIsNone, \
    KaspiLoginAlreadyExistsException, KaspiCabinetSmsSendingException, SmsVerificationFailedException


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)
auth_logger = logging.getLogger(settings.AUTH_LOGGER_NAME)


class KaspiProductViewSet(CustomViewSet):
    queryset = KaspiProduct.objects.filter(recently_parsed=True)
    serializer_class = KaspiProductSerializer
    permission_classes = (IsOwnerOrReadOnly,)
    filter_backends = (filters.SearchFilter,)
    search_fields = ('title', 'code', 'master_sku',)
    ordering_fields = ('id',)

    def get_queryset(self):
        queryset_filter = {
            'recently_parsed': True,
        }
        if not self.request.user.has_group('Manager'):
            queryset_filter['merchant__user'] = self.request.user

        if self.request.GET.get('merchant_ids', '').strip():
            merchant_ids = self.request.GET.get('merchant_ids', '').strip().split(',')
            queryset_filter['merchant__id__in'] = merchant_ids

        if self.request.GET.get('current_price_place', '').strip():
            current_price_place = self.request.GET.get('current_price_place', '').strip().split(',')
            queryset_filter['current_price_place__in'] = current_price_place

        if self.request.GET.get('price', '').strip() == 'min_price':
            queryset_filter['price'] = F("min_price")

        min_price_q = Q()

        if self.request.GET.get('min_price', '').strip() == 'is_null':
            min_price_q = Q(min_price__isnull=True) | Q(min_price=0)

        if self.request.GET.get('min_price', '').strip() == 'gt_competitor':
            queryset_filter['min_price__gt'] = F("first_place_price")

        if self.request.GET.get('product_flag', '').strip():
            product_flag = self.request.GET.get('product_flag', '').strip()
            queryset_filter['product_flag__iexact'] = product_flag

        if self.request.GET.get('price_auto_change', '').strip():
            price_auto_change = self.request.GET.get('price_auto_change', '').strip()
            queryset_filter['price_auto_change__iexact'] = price_auto_change

        queryset = KaspiProduct.objects.filter(**queryset_filter)

        if min_price_q:
            queryset = queryset.filter(min_price_q)

        if self.request.GET.get('order_by', '').strip():
            order_by = self.request.GET.get('order_by', '').strip()
            queryset = queryset.order_by(order_by)

        return queryset

    @action(methods=['PUT'], url_path='bulk_update', detail=False, permission_classes=[IsAuthenticated])
    def bulk_update(self, request):
        products_ids = request.data.get('ids')
        products = []
        for product_id in list(set(products_ids)):
            try:
                product: KaspiProduct = KaspiProduct.objects.get(pk=product_id, merchant__user=self.request.user)
                if product:
                    products.append(product)
            except KaspiProduct.DoesNotExist:
                return Response({'error': f'Товара {product_id} нет в базе'}, status.HTTP_404_NOT_FOUND)
        for product in products:
            if request.data.get('price_auto_change') is not None:
                product.price_auto_change = request.data.get('price_auto_change')
            if request.data.get('target_price_place') is not None:
                product.target_price_place = request.data.get('target_price_place')
            if request.data.get('price_difference') is not None:
                product.price_difference = request.data.get('price_difference')
            product.save()

        return Response(status=status.HTTP_200_OK)


class ProductPriceList(generics.ListAPIView):
    queryset = ProductPrice.objects.all()
    serializer_class = ProductPriceSerializer
    permission_classes = [ReadOnly]
    filter_backends = (DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter)
    filterset_fields = ('product',)
    search_fields = ('product', 'date_of_changing',)

    def get_queryset(self):
        queryset = ProductPrice.objects.all()
        if self.request.user.has_group('Manager'):
            return queryset

        return queryset.filter(product__merchant__user=self.request.user)


class ClientLoginView(APIView):
    permission_classes = (AllowAny,)

    def post(self, request):
        auth_logger.info('ClientLoginView.post: attempting sign in',
                         extra={'phone_numer': request.data.get('phone_number')})
        serializer = LoginPayloadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        user: CustomUser = authenticate(phone_number=serializer.data['phone_number'],
                                        password=serializer.data['password'])
        if user:
            token, created = Token.objects.get_or_create(user=user)
            auth_logger.info('ClientLoginView.post: Sign in success',
                             extra={'phone_number': request.data['phone_number']})
            return Response({'token': token.key,
                             "user": {
                                 "id": user.id,
                                 "full_name": f'{user.first_name} {user.last_name}',
                                 "company_name": user.company_name,
                                 "email": user.email,
                                 "phone_number": user.phone_number
                             }}
                            )
        else:
            auth_logger.error('ClientLoginView.post: Sign in invalid',
                              extra={'phone_number': request.data['phone_number']})
            return Response({'error': 'Invalid credentials'}, status=401)


class TokenRefreshApi(APIView):
    permission_classes = (AllowAny,)

    def post(self, request):
        try:
            user: CustomUser = Token.objects.get(key=request.data['token']).user
            Token.objects.filter(user=user).delete()
            new_token, created = Token.objects.get_or_create(user=user)
            return Response({'token': new_token.key,
                             "user": {
                                 "id": user.id,
                                 "full_name": f'{user.first_name} {user.last_name}',
                                 "company_name": user.company_name,
                                 "email": user.email,
                                 "phone_number": user.phone_number
                             }}
                            )
        except Token.DoesNotExist:
            return Response({'error': 'Пользователя с таким токеном не существует'}, status=401)


class TokenDetailApi(APIView):
    permission_classes = [AllowAny]

    def get(self, request, token):
        try:
            user: CustomUser = Token.objects.get(key=token).user
            user_data = {
                "id": user.id,
                "full_name": f'{user.first_name} {user.last_name}',
                "company_name": user.company_name,
                "email": user.email,
                "phone_number": user.phone_number
            }

            return Response({"user": user_data})

        except Token.DoesNotExist:
            return Response({'error': 'Пользователя с таким токеном не существует'}, status=401)
        except Exception as e:
            logger.error("TokenDetailApi.get: raised error %s", str(e))
            return Response({"error": "Please try again!"}, status=500)


class ChangePasswordView(generics.UpdateAPIView):
    queryset = CustomUser.objects.all()
    permission_classes = (IsAuthenticated,)
    serializer_class = ChangePasswordSerializer


class SendVerificationCodeView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            phone_number = filter_phone_number(str(request.data['phone_number']))
            if not phone_number:
                return Response({'error': 'Phone number is required'}, status=status.HTTP_400_BAD_REQUEST)

            if CustomUser.objects.filter(phone_number=phone_number).exists():
                return Response({'error': 'Пользователь с таким номером телефона уже существует.'},
                                status=status.HTTP_409_CONFLICT)

            sms_response = sms_service.send_verification_code(phone_number)
            uid = sms_response['uid']
            if uid:
                cache.set(key=uid, value=phone_number, timeout=settings.CACHE_TTL)
                data = {'uid': uid, 'phone_number': phone_number}
                logger.info(f'Verification code sent to {phone_number} with uid {uid}')
                return Response(data, status=status.HTTP_200_OK)
            else:
                logger.error(f'Failed to send verification code to {phone_number}')
                return Response({'error': 'Failed to send verification code'},
                                status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as e:
            logger.error(f'Unexpected error during sending verification code:{e}')
            return Response({'error': 'An unexpected error occured while sending the verification code.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class VerifyCodeView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            uid = request.data['uid']
            verification_code = request.data['verification_code']
            if not uid or not verification_code:
                return Response({'error': 'Uid and verification code are required'}, status=status.HTTP_400_BAD_REQUEST)

            if uid:
                phone_number = cache.get(uid)
                verification_response = sms_service.verify_code(uid, verification_code)
                data = {'uid': uid, 'phone_number': phone_number}

                if verification_response.status_code == 200:
                    logger.info(f' {phone_number} validated successfully , {uid}')
                    return Response(data, status=status.HTTP_200_OK)
                else:
                    logger.warning(f'Invalid verification code for UID {uid}.')
                    return Response({'error': 'Invalid verification code'}, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            logger.error(f'Unexpected error during verification code:{e}')
            return Response({'error': 'An unexpected error occurred while verifying code.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ClientRegistrationView(APIView):
    permission_classes = [AllowAny]

    @time_it_and_log
    def post(self, request):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        uid = request.data['uid']

        if not uid:
            return Response({'error': 'Uid is required'}, status=status.HTTP_400_BAD_REQUEST)

        phone_number = cache.get(uid)
        data = {
            "phone_number": phone_number,
            "password": request.data['password'],
        }
        auth_logger.info('ClientRegistrationView.post: Attempting to sign up', extra={'phone_number': phone_number})
        serializer = CustomUserSerializer(data=data)

        if serializer.is_valid():
            user: CustomUser = serializer.save()
            user.set_password(serializer.validated_data["password"])
            user.save()

            token, _ = Token.objects.get_or_create(user=user)

            # sending healthcheck request to other service to synchronize db
            healthcheck_other_services.delay(token.key, phone_number)

            notify_user_registration_telegram_channel.delay(
                dict(
                    date_time=datetime.datetime.now().strftime('%d.%m.%Y %H:%M'),
                    full_name=f'{serializer.data["last_name"]} {serializer.data["first_name"]}',
                    email=serializer.data["email"],
                    phone_number=serializer.data["phone_number"],
                )
            )

            auth_logger.info('ClientRegisterView.post: Sign up success', extra={'phone_number': phone_number})

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        auth_logger.error('ClientRegisterView.post: Sign up invalid %s', serializer.errors,
                          extra={'phone_number': phone_number})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            auth_logger.info(
                'ForgotPasswordView.post: Attempting to forgot password',
                extra={'phone_number': request.data.get('phone_number')}
            )
            phone_number = request.data.get('phone_number')
            if not phone_number:
                auth_logger.error(
                    'ForgotPasswordView.post: Phone number is required',
                    extra={'phone_number': request.data.get('phone_number')}
                )
                return Response({'error': 'Phone number is required'}, status=status.HTTP_400_BAD_REQUEST)
            user = CustomUser.objects.filter(phone_number=phone_number).first()
            if not user:
                auth_logger.error(
                    'ForgotPasswordView.post: User does not exist',
                    extra={'phone_number': request.data.get('phone_number')}
                )
                return Response({'error': 'User does not exist'}, status=status.HTTP_400_BAD_REQUEST)

            sms_response = sms_service.send_verification_code(phone_number)
            uid = sms_response['uid']

            if uid:
                cache.set(uid, phone_number, timeout=settings.CACHE_TTL)
                data = {'uid': uid, 'phone_number': phone_number}
                logger.info(f'Verification code sent to {phone_number} with uid {uid} for for password reset')
                auth_logger.info(
                    'ForgotPasswordView.post: sms code sent',
                    extra={'phone_number': request.data.get('phone_number')}
                )
                return Response(data, status=status.HTTP_200_OK)
            else:
                auth_logger.error(
                    'ForgotPasswordView.post: error while sending sms code',
                    extra={'phone_number': request.data.get('phone_number')}
                )
                logger.error(f'Failed to send verification code to {phone_number}')
                return Response({'error': 'Failed to send verification code'},
                                status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        except Exception as e:
            auth_logger.error(
                'ForgotPasswordView.post: Unexpected error %s', e,
                extra={'phone_number': request.data.get('phone_number')}
            )
            return Response({'error': 'An unexpected error occurred while sending the verification code.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            uid = request.data['uid']
            new_password = request.data['new_password']
            if not uid or not new_password:
                return Response({'error': 'Uid and password are required'}, status=status.HTTP_400_BAD_REQUEST)

            phone_number = cache.get(uid)

            if not phone_number:
                return Response({'error': 'Invalid phone number'}, status=status.HTTP_400_BAD_REQUEST)

            user = CustomUser.objects.get(phone_number=phone_number)
            user.set_password(new_password)
            user.save()

            data = {'phone_number': phone_number, 'password': user.password}
            logger.info(f'Password reset for {user.phone_number}')
            return Response(data, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f'Unexpected error during password reset {e}')
            return Response({'error': 'An unexpected error occurred during password reset.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MerchantViewSet(viewsets.ModelViewSet):
    queryset = Merchant.objects.all()
    serializer_class = MerchantSerializer
    permission_classes = (IsOwnerOrReadOnly,)
    lookup_field = 'merchant_id'

    def get_queryset(self):
        queryset_filter = {}

        if self.request.GET.get('filter', '').strip().lower() == "true":
            queryset_filter['enabled'] = True

        if not self.request.user.has_group('Manager'):
            queryset_filter['user'] = self.request.user

        return Merchant.objects.filter(**queryset_filter)

    def perform_create(self, serializer):
        kaspi_login = self.request.data.get('kaspi_login')
        extra_data = self.request.data

        if Merchant.objects.filter(login=kaspi_login).exists():
            raise KaspiLoginAlreadyExistsException("Магазин с таким именем пользователя уже существует.")

        try:
            kaspi_merchant_cabinet_methods = KaspiMerchantCabinetMethods(self.request.data.get('kaspi_login'),
                                                                         self.request.data.get('kaspi_password'))
            merchant_settings = kaspi_merchant_cabinet_methods.get_merchant_settings()
        except MerchantSettingsRetrieveException:
            logger.exception('parser_kaspi_data.views.MerchantViewSet.perform_create failed - bad response',
                             extra=extra_data)
            raise BadRequest("Не удалось получить информацию о магазине в каспи кабинете")
        except IncorrectLoginException:
            logger.exception(
                'parser_kaspi_data.views.MerchantViewSet.perform_create failed - incorrect login or password',
                extra=extra_data)
            raise BadRequest("Неправильный логин или пароль от каспи кабинета")

        extra_data.update(merchant_settings)
        logger.info('parser_kaspi_data.views.MerchantViewSet.perform_create fetching shop info success',
                    extra=extra_data)

        serializer.save(name=merchant_settings['merchant_name'],
                        merchant_id=merchant_settings['merchant_id'],
                        login=self.request.data.get('kaspi_login'),
                        password=self.request.data.get('kaspi_password'), price_auto_change=False
                        )

    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except IntegrityError as exc:
            logger.exception('parser_kaspi_data.views.MerchantViewSet.create failed IntegrityError',
                             extra=request.data)
            raise APIException(detail=exc)
        except BaseException as e:
            logger.exception('parser_kaspi_data.views.MerchantViewSet.create failed BaseException',
                             extra=request.data)
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @action(methods=['POST'], detail=True, url_path='set-subscription', permission_classes=[IsAuthenticated])
    def set_subscription(self, request, merchant_id=None):
        try:
            merchant = Merchant.objects.get(merchant_id=merchant_id)
        except Merchant.DoesNotExist:
            return Response({'error': 'Merchant not found'}, status=status.HTTP_404_NOT_FOUND)

        days = request.data.get('days')
        if not days:
            return Response({'error': 'Invalid data , "days" is required"'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            days = int(days)
        except ValueError:
            return Response({'error': '"days" must be an integer'}, status=status.HTTP_400_BAD_REQUEST)

        merchant.set_subscription_days(days)
        return Response({'success': 'Subscription set successfully'}, status=status.HTTP_200_OK)

    @action(methods=['PUT'], url_path='ignore-competitors', detail=True, permission_classes=[IsAuthenticated])
    def ignore_competitors(self, request, merchant_id=None):
        try:
            merchant: Merchant = Merchant.objects.get(merchant_id=merchant_id, user=request.user)
            competitors_data = request.data.get('competitors_to_exclude')
            competitors_to_exclude_validator(competitors_data)
            merchant.competitors_to_exclude = competitors_data
            merchant.save()
            return Response({"competitors_to_be_ignored": competitors_data}, status=status.HTTP_200_OK)
        except ValidationError:
            return Response({"error": "Каждое значение в списке значений не должно быть списком, или пустой строкой"},
                            status=500)
        except Merchant.DoesNotExist:
            return Response({"error": "Магазин с таким pk не найден"}, status=404)

    @action(methods=['POST'], url_path='get-login-security-code', detail=False, permission_classes=[IsAuthenticated])
    def get_login_security_code(self, request):
        try:
            phone_number = (request.data['phone_number'])
            if not phone_number:
                return Response({'error': 'Phone number is required'}, status=status.HTTP_400_BAD_REQUEST)

            filtered_phone_number = filter_phone_number(str(phone_number), forced_country_code='8')
            session_id, ngs = request_sms_verification_code_to_login_in_kaspi(filtered_phone_number)
            if session_id and ngs:
                cache_key = f"kaspi_login_sms_verification_{filtered_phone_number}"
                cache.set(key=cache_key, value=(session_id, ngs), timeout=settings.CACHE_TTL)
                logger.info(f'Login security code sent to {filtered_phone_number} with session_id {session_id}')
                return Response({}, status=status.HTTP_200_OK)
            else:
                logger.error(f'Failed to send login security code to {filtered_phone_number}')
                return Response({'error': 'Failed to send security code'},
                                status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except KaspiCabinetSmsSendingException as e:
            logger.error(f'Failed to send login security code, error :: {e}')
            return Response({"error": "Failed to send security code"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        except Exception as e:
            logger.error(f'Unexpected error during sending security code:{e}')
            return Response({"error": "Failed to send security code"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(methods=['POST'], url_path='verify-login-security-code', detail=False, permission_classes=[IsAuthenticated])
    def verify_login_security_code(self, request):
        try:
            phone_number = (request.data['phone_number'])
            security_code = request.data['security_code']

            if not phone_number or not security_code:
                return Response({'error': 'Session_id and security_code code are required'},
                                status=status.HTTP_400_BAD_REQUEST)

            filtered_phone_number = filter_phone_number(str(phone_number), forced_country_code='8')
            cache_key = f"kaspi_login_sms_verification_{filtered_phone_number}"

            cache_data = cache.get(cache_key)
            logger.info(cache_data)

            if not cache_data:
                return Response({'error': 'Login attempt not found'}, status=status.HTTP_400_BAD_REQUEST)
            session_id, ngs = cache_data

            logger.info(f'Session_id :: {session_id}, security code :: {security_code}, ngs :: {ngs}')
            session_id = verify_kaspi_cabinet_login_security_code(security_code, session_id, ngs)
            logger.info(f'Login to kaspi cabinet with {phone_number} was successful, session_id :: {session_id}')

            kaspi_merchant_cabinet_methods = KaspiMerchantCabinetMethods(session_id=session_id)
            merchant_settings = kaspi_merchant_cabinet_methods.get_merchant_settings()
            merchant_id = merchant_settings['merchant_id']
            merchant_name = merchant_settings['merchant_name']
            logger.info(f'Merchant_id :: {merchant_id}, merchant_name :: {merchant_name}')
            email = f'new_user+{merchant_id}-{int(datetime.datetime.now().timestamp())}@skymetrics.kz'
            create_new_user_and_send_password_to_email(session_id, email, 'New User', '7779005148', merchant_id)
            # create new shop -save shop name, id and login
            Merchant.objects.create(name=merchant_name, merchant_id=merchant_id, login=email, user=request.user)
            check_email_and_try_to_read_its_content(merchant_id)

            return Response({"merchant_name": merchant_name}, status=status.HTTP_200_OK)

        except SmsVerificationFailedException as e:
            logger.error(f'Sms verification error during login to kaspi with security code:{e}')
            logger.error(format_exception(e))
            return Response({'error': 'Unexpected error during login to kaspi with security code'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except IncorrectLoginException as e:
            logger.error(f'Something wrong with new login or new password from kaspi cabinet:{e}')
            logger.error(format_exception(e))
            return Response({'error': 'Unexpected error during login to kaspi with new credentials'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as e:
            logger.error(f'Unexpected error during login to kaspi with security code:{e}')
            logger.error(format_exception(e))
            return Response({'error': 'Unexpected error during login to kaspi with security code'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CommentCreateApi(generics.CreateAPIView):
    serializer_class = CommentSerializer
    queryset = Comment.objects.all()


class XmlFileGeneratedLinkView(APIView):
    permission_classes = [IsOwnerOrReadOnly]

    def get(self, request: Request):
        try:
            merchant_pk = int(request.query_params.get('merchant_pk'))
            merchant = Merchant.objects.get(pk=merchant_pk)
            file_link = merchant.xml_file_path
            if file_link is None:
                raise XmlFileLinkIsNone
            now = datetime.datetime.now()
            creation_date = now.strftime('%d.%m.%Y %H:%M')
            return Response({"merchant_pk": merchant_pk, "file_path": file_link, "creation_date": creation_date},
                            status=200)
        except Merchant.DoesNotExist:
            return Response({"error": "Магазин с таким pk не найден"}, status=404)

        except XmlFileLinkIsNone:
            return Response({"error": "Файл еще не сгенерирован"}, status=404)


class CustomUserInformationUpdate(generics.UpdateAPIView):
    permission_classes = [IsOwnerOrReadOnly]
    queryset = CustomUser.objects.all()
    serializer_class = CustomUserSerializer


class ViewSet(mixins.ListModelMixin,
              mixins.RetrieveModelMixin,
              mixins.DestroyModelMixin,
              viewsets.GenericViewSet):
    pass


class UserNotificationViewSet(ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = UserNotificationSerializer

    def get_queryset(self):
        queryset = UserNotification.objects.filter(user=self.request.user)

        return queryset

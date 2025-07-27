from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import KaspiProductViewSet, ProductPriceList, ClientRegistrationView, MerchantViewSet, ClientLoginView, \
    ChangePasswordView, TokenRefreshApi, CommentCreateApi, XmlFileGeneratedLinkView, CustomUserInformationUpdate, \
    UserNotificationViewSet, SendVerificationCodeView, VerifyCodeView, ForgotPasswordView, ResetPasswordView, \
    TokenDetailApi

router = DefaultRouter()
router.register('kaspi_products', KaspiProductViewSet)
router.register('merchants', MerchantViewSet)
router.register('notifications', UserNotificationViewSet, basename='notifications')


urlpatterns = [
    path('', include(router.urls)),
    path('product_prices/', ProductPriceList.as_view()),
    path('registration/', ClientRegistrationView.as_view()),
    path('send_verification_code/', SendVerificationCodeView.as_view()),
    path('verify_code/', VerifyCodeView.as_view()),
    path('forgot_password/', ForgotPasswordView.as_view()),
    path('reset_password/', ResetPasswordView.as_view()),
    path('login/', ClientLoginView.as_view()),
    path('change_password/<int:pk>/', ChangePasswordView.as_view(), name='auth_change_password'),
    path('refresh_token/', TokenRefreshApi.as_view()),
    path('create_comment/', CommentCreateApi.as_view()),
    path('generate_xml_file_link/', XmlFileGeneratedLinkView.as_view()),
    path('update_user/<int:pk>/', CustomUserInformationUpdate.as_view()),
    path('token/<str:token>/', TokenDetailApi.as_view(), name='token_detail'),
]

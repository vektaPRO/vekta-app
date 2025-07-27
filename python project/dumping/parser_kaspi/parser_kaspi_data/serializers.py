import datetime
from typing import Union
from django.core.cache import cache
import pytz
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from rest_framework import serializers
from .models import KaspiProduct, ProductPrice, Merchant, CustomUser, Comment, UserNotification


class KaspiProductSerializer(serializers.ModelSerializer):
    last_price_change = serializers.SerializerMethodField()
    merchant_name = serializers.SerializerMethodField()

    def get_last_price_change(self, product: KaspiProduct):
        cache_key = f'{product.id}'
        last_price_change = cache.get(cache_key)

        if last_price_change:
            recent_produce_price = timezone.localtime(last_price_change, pytz.timezone('Asia/Almaty'))
            return recent_produce_price.strftime('%d.%m.%Y %H:%M')

        recent_price: Union[None, ProductPrice] = product.prices.order_by('-date_of_changing').first()
        if not recent_price:
            return ''

        recent_produce_price = timezone.localtime(recent_price.date_of_changing, pytz.timezone('Asia/Almaty'))
        return recent_produce_price.strftime('%d.%m.%Y %H:%M') if recent_price else ''

    def get_merchant_name(self, product: KaspiProduct):
        return product.merchant_name

    class Meta:
        fields = '__all__'
        model = KaspiProduct
        extra_kwargs = {
            'merchant': {'read_only': True},
            'title': {'read_only': True},
            'price': {'read_only': True},
            'current_price_place': {'read_only': True},
            'first_place_price': {'read_only': True},
            'second_place_price': {'read_only': True},
            'third_place_price': {'read_only': True},
            'code': {'read_only': True},
            'master_sku': {'read_only': True},
            'available': {'read_only': True},
            'date_of_parsing': {'read_only': True},
            'calculated_remainders': {'read_only': True},
            'reserved_remainders': {'read_only': True},
            'sold_remainders': {'read_only': True},
            'product_card_link': {'read_only': True},
            'product_image_link': {'read_only': True},
            'recently_parsed': {'read_only': True},
            'num_checks_to_skip': {'read_only': True},
            'num_checks_without_changed_price': {'read_only': True},
            'product_flag': {'read_only': True},
            'last_price_change': {'read_only': True},
            'merchant_name': {'read_only': True},
        }


class ProductPriceSerializer(serializers.ModelSerializer):
    class Meta:
        fields = '__all__'
        model = ProductPrice


class LoginPayloadSerializer(serializers.Serializer):
    phone_number = serializers.CharField(max_length=11)
    password = serializers.CharField()


class CustomUserSerializer(serializers.ModelSerializer):
    class Meta:
        fields = ('id', 'first_name', 'last_name', 'company_name', 'password', 'email', 'phone_number',)
        model = CustomUser
        extra_kwargs = {
            'username': {'required': False},
            'password': {'write_only': True, 'required': False},
        }

    def update(self, instance, validated_data):
        if 'password' in validated_data:
            validated_data['password'] = make_password(validated_data['password'])
        return super().update(instance, validated_data)

class ChangePasswordSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    old_password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = CustomUser
        fields = ('old_password', 'password',)

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError({"old_password": "Old password is not correct"})
        return value

    def update(self, instance, validated_data):
        instance.set_password(validated_data['password'])
        instance.save()

        return instance


class MerchantSerializer(serializers.ModelSerializer):
    subscription_days_left = serializers.SerializerMethodField()

    class Meta:
        model = Merchant
        exclude = ('login', 'password', 'kaspi_token')

    @staticmethod
    def get_subscription_days_left(obj):
        days_left = 0
        if obj.subscription_date_start is not None and obj.subscription_days is not None:
            period_end_date = obj.subscription_date_start + datetime.timedelta(days=obj.subscription_days)
            date_now = timezone.now()
            if period_end_date > date_now:
                 days_left = (period_end_date - timezone.now()).days
            return days_left

    def create(self, validated_data):
        request = self.context.get("request")
        if not request.user.has_group('Manager'):
            validated_data['enabled'] = False
        merchant = Merchant.objects.create(user=request.user,
                                           **validated_data)

        return merchant

    def update(self, instance, validated_data):
        request = self.context.get("request")
        if not request.user.has_group('Manager'):
            validated_data['enabled'] = instance.enabled

        return super().update(instance, validated_data)


class CommentSerializer(serializers.ModelSerializer):
    class Meta:
        fields = '__all__'
        model = Comment

    def create(self, validated_data):
        request = self.context.get("request")
        comment = Comment.objects.create(user=request.user,
                                         **validated_data)
        return comment


class UserNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        fields = '__all__'
        model = UserNotification

import datetime

from django.db import models
from django import forms
from django.contrib import admin
from django.contrib.auth.models import AbstractUser, UserManager
from django.utils.html import format_html
from django.utils import timezone
from pktools.stash import cached


class CustomerUserManager(UserManager):

    def _create_user(self, phone_number, email, password, **extra_fields):
        """
        Create and save a user with the given username, email, and password.
        """
        if not phone_number:
            raise ValueError("The given phone_number must be set")
        email = self.normalize_email(email)
        user = self.model(phone_number=phone_number, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, phone_number, email=None, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(phone_number, email, password, **extra_fields)

    def create_superuser(self, phone_number, email=None, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self._create_user(phone_number, email, password, **extra_fields)


class CustomUser(AbstractUser):
    username = None
    email = models.EmailField(max_length=300, blank=True, null=True, verbose_name='email клиента')
    phone_number = models.CharField(max_length=11, blank=True, null=True, unique=True, verbose_name='номер телефона')
    company_name = models.CharField(max_length=300, blank=True, null=True, verbose_name='название компании')
    used_trial = models.BooleanField(blank=True, null=True, default=False, verbose_name='использованный пробный период')
    informed_about_login_problems = models.BooleanField(blank=True, null=True, default=False,
                                                        verbose_name='информирован о проблемах с логином')

    USERNAME_FIELD = 'phone_number'
    REQUIRED_FIELDS = []

    objects = CustomerUserManager()

    class Meta:
        verbose_name = 'Пользователь'
        verbose_name_plural = 'Пользователи'

    def __str__(self):
        return self.phone_number if self.phone_number else ''

    @admin.display(description='ФИО')
    def get_full_name(self):
        return super().get_full_name()

    def has_group(self, group_name):
        return self.groups.filter(name=group_name).exists()


def competitors_to_exclude_validator(value):
    if not isinstance(value, list):
        raise forms.ValidationError('Competitors to exclude must be a list')

    for competitor in value:
        if not isinstance(competitor, str) or competitor.strip() == '':
            raise forms.ValidationError('Каждое значение в списке значений не должно быть списком, или пустой строкой')


class Merchant(models.Model):
    PRICE_PLACES = [
        ('1', '1'),
        ('2', '2'),
        ('3', '3')
    ]

    EXECUTION_TYPE_A = 'A'
    EXECUTION_TYPE_B = 'B'

    EXECUTION_TYPES = (
        (EXECUTION_TYPE_A, 'A'),
        (EXECUTION_TYPE_B, 'B'),
    )

    name = models.CharField(max_length=300, blank=True, null=True, verbose_name='название магазина', db_index=True)
    merchant_id = models.CharField(max_length=300, blank=True, null=True, verbose_name='id магазина', unique=True)
    enabled = models.BooleanField(blank=True, null=True, default=False, verbose_name='активирован')
    enable_parsing = models.BooleanField(blank=True, null=True, default=False, verbose_name='авто парсинг')
    subscription_date_start = models.DateTimeField(blank=True, null=True, verbose_name='дата начала подписки')
    subscription_date_end = models.DateTimeField(blank=True, null=True, verbose_name='дата оконч-я подписки')
    subscription_days = models.IntegerField(blank=True, default=0, verbose_name='дни по подписке')
    login = models.CharField(max_length=300, blank=True, null=True, verbose_name='kaspi логин')
    kaspi_token = models.CharField(max_length=300, blank=True, null=True, verbose_name='kaspi токен')
    password = models.CharField(max_length=300, blank=True, null=True, verbose_name='kaspi пароль')
    created_date = models.DateTimeField(auto_now_add=True,blank=True, null=True, verbose_name='дата регистрации')
    price_auto_change = models.BooleanField(blank=True, null=True, default=False, verbose_name='авто изм-е цены')
    price_difference = models.IntegerField(blank=True, null=True, default=None, verbose_name='разница в цене')
    price_place = models.CharField(max_length=1, choices=PRICE_PLACES, blank=True, null=True,
                                   default='1', verbose_name='ценовой ориентир') # TODO should be integer field with default 1
    allowed_number_of_products_with_price_change = models.IntegerField(blank=True, null=True, default=None,
                                                                       verbose_name='установл.кол-во товаров с измен-ем цены')
    allowed_number_of_products_with_remainders = models.IntegerField(blank=True, null=True, default=None,
                                                                     verbose_name='установл.кол-во товаров с остатками')
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, verbose_name='клиент', blank=True, null=True,
                             related_name='shops')
    competitors_to_exclude = models.JSONField(
        default=list,
        verbose_name='исключить конкурентов',
        blank=True,
        validators=[competitors_to_exclude_validator]
    )
    xml_file_path = models.CharField(max_length=500, blank=True, null=True, verbose_name='xml-файл')

    execution_type = models.CharField(max_length=5, choices=EXECUTION_TYPES, default=EXECUTION_TYPE_B, verbose_name='Тип (A - если товаров много)')

    @admin.display(description='Xml-файл c ценами')
    def hyperlinked_xml_file_path(self):
        if self.xml_file_path:
            return format_html(f'<a href="{self.xml_file_path}" target="_blank">{self.xml_file_path}</a>')
        return ''

    class Meta:
        verbose_name = 'Магазин Kaspi'
        verbose_name_plural = 'Магазины Kaspi'
        constraints = [
            models.UniqueConstraint(fields=['merchant_id'], name='unique_shop_id')
        ]

        indexes = [
            models.Index(fields=['enable_parsing', 'enabled', 'execution_type'])
        ]

    def __str__(self):
        return self.name if self.name else ''

    def save(self, *args, **kwargs):
        if not self.user.used_trial and not self.subscription_days:
            self.subscription_date_start = timezone.now()
            self.subscription_days = 3
            self.subscription_date_end = self.subscription_date_start + datetime.timedelta(days=self.subscription_days)
            self.user.used_trial = True
            self.user.save()
            self.enabled = True
            self.enable_parsing = True

        if self.subscription_days:
            self.subscription_date_end = self.subscription_date_start + datetime.timedelta(days=self.subscription_days)

        super().save(*args, **kwargs)
        return

    def set_subscription_days(self, days):
        self.subscription_date_start = timezone.now()
        self.subscription_days = days
        self.save()

    @admin.display(description='Остаток дней по подписке')
    def readable_subscription_days_left(self):
        if self.subscription_date_start is not None and self.subscription_days is not None:
             if self.subscription_days_left > 15:
                    color = 'green'
             elif 15 > self.subscription_days_left > 3:
                    color = 'orange'
             else:
                    color = 'red'
             return format_html(
                    '<b style="color:{};">{}</b>',
                    color,
                    self.subscription_days_left
                )

    @property
    def subscription_days_left(self):
        if self.subscription_date_start is None:
            self.subscription_date_start = timezone.now()

        if self.subscription_days is None:
            self.subscription_days = 0

        period_end_date = self.subscription_date_start + datetime.timedelta(days=self.subscription_days)
        date_now = timezone.now()
        days_left = (period_end_date - timezone.now()).days if period_end_date > date_now else 0
        return days_left

    @admin.display(description='Кол-во товаров с автоизменением цены')
    def readable_count_products_with_auto_price_change(self):
        return self.kaspi_products.filter(price_auto_change=True).count()

    @admin.display(description='Кол-во товаров с остатками')
    def readable_count_products_with_remainders(self):
        return self.kaspi_products.filter(remainders__isnull=False).exclude(remainders=0).count()


class KaspiProduct(models.Model):
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, verbose_name='продавец', blank=True, null=True,
                                 related_name='kaspi_products')
    title = models.CharField(max_length=300, blank=True, null=True, verbose_name='название')
    price = models.IntegerField(blank=True, null=True, verbose_name='ваша цена')
    current_price_place = models.IntegerField(blank=True, null=True, verbose_name='текущее ценовое место')
    first_place_price = models.IntegerField(blank=True, null=True, verbose_name='цена 1 места')
    second_place_price = models.IntegerField(blank=True, null=True, verbose_name='цена 2 места')
    third_place_price = models.IntegerField(blank=True, null=True, verbose_name='цена 3 места')
    target_price_place = models.IntegerField(blank=True, null=True, verbose_name='ценовой ориентир')
    min_price = models.IntegerField(blank=True, null=True, verbose_name='минимальная цена')
    max_price = models.IntegerField(blank=True, null=True, verbose_name='максимальная цена')
    code = models.CharField(max_length=150, blank=True, null=True, verbose_name='код продукта')
    master_sku = models.CharField(max_length=150, blank=True, null=True, verbose_name='SKU продукта', db_index=True)
    available = models.BooleanField(blank=True, null=True, verbose_name='в наличии')
    price_auto_change = models.BooleanField(blank=True, null=True, default=False, verbose_name='авто изм-е цены')
    price_difference = models.IntegerField(blank=True, null=True, default=None, verbose_name='разница в цене')
    date_of_parsing = models.DateTimeField(auto_now=True, verbose_name='время парсинга')
    remainders = models.IntegerField(blank=True, null=True, verbose_name='внесен. остаток')
    calculated_remainders = models.IntegerField(blank=True, null=True, verbose_name='высчитан. остаток', default=0)
    remainders_date = models.DateTimeField(blank=True, null=True, verbose_name='время внесения остатков')
    reserved_remainders = models.IntegerField(blank=True, null=True, verbose_name='в резерве')
    sold_remainders = models.IntegerField(blank=True, null=True, verbose_name='продано')
    product_card_link = models.CharField(max_length=500, blank=True, null=True, verbose_name='ссылка на карточку товара')
    product_image_link = models.CharField(max_length=500, blank=True, null=True, verbose_name='фотография товара')
    recently_parsed = models.BooleanField(default=True, verbose_name='актуальный', db_index=True)
    availabilities = models.JSONField(
        default=list,
        verbose_name='данные для xml-файла',
        blank=True,
    )
    num_checks_to_skip = models.IntegerField(default=0, verbose_name='кол-во пропусков цикла')
    num_checks_without_changed_price = models.IntegerField(default=0, verbose_name='кол-во итераций без изм-я цены')
    product_flag = models.CharField(max_length=100, default='Hot', verbose_name='ценовой флаг')

    class Meta:
        verbose_name = 'Продукт Kaspi'
        verbose_name_plural = 'Продукты Kaspi'

        ordering = ['pk']

        indexes = [
            models.Index(fields=['master_sku', 'merchant_id']),
            models.Index(fields=['price_auto_change', 'available', 'merchant_id', 'recently_parsed'])
        ]

    def __str__(self):
        return self.code if self.code else ''

    @admin.display(description='Карточка товара')
    def hyperlinked_product_link(self):
        if self.product_card_link:
            return format_html(f'<a href="{self.product_card_link}" target="_blank">{self.product_card_link}</a>')
        return ''

    @admin.display(description='Фото товара')
    def hyperlinked_product_image(self):
        if self.product_image_link:
            return format_html(f'<a href="{self.product_image_link}" target="_blank">{self.product_image_link}</a>')
        return ''

    @cached.property(cached.FOREVER, exclude_args=[])
    def merchant_name(self):
        if self.merchant:
            return self.merchant.name
        return ''


class ProductPrice(models.Model):
    product = models.ForeignKey(KaspiProduct, on_delete=models.CASCADE, verbose_name='продукт', blank=True, null=True,
                                related_name='prices')
    date_of_changing = models.DateTimeField(blank=True, null=True, verbose_name='время изменения')
    changed_price = models.IntegerField(blank=True, null=True, verbose_name='измененная цена')

    class Meta:
        verbose_name = 'Цена продуктов'
        verbose_name_plural = 'Цены продуктов'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.date_of_changing = timezone.now()


class KaspiOrder(models.Model):
    order_id = models.CharField(max_length=200, blank=True, null=True, verbose_name='номер заказа')
    order_date = models.DateTimeField(blank=True, null=True, verbose_name='дата заказа')
    order_type = models.CharField(max_length=200, blank=True, null=True, verbose_name='тип заказа')
    order_status = models.CharField(max_length=200, blank=True, null=True, verbose_name='статус заказа')

    class Meta:
        verbose_name = 'Заказ Kaspi'
        verbose_name_plural = 'Заказы Kaspi'

    def __str__(self):
        return self.order_id if self.order_id else ''

    def renew_status(self, status):
        self.order_status = status


class KaspiOrderProduct(models.Model):
    order = models.ForeignKey(KaspiOrder, on_delete=models.CASCADE, verbose_name='заказ', blank=True, null=True,
                              related_name='order_products')
    product = models.ForeignKey(KaspiProduct, on_delete=models.CASCADE, verbose_name='продукт', blank=True, null=True,
                                related_name='order_products')
    quantity = models.IntegerField(blank=True, null=True, verbose_name='количество')

    class Meta:
        verbose_name = 'Продукт из заказа Kaspi'
        verbose_name_plural = 'Продукты из заказа Kaspi'


class Comment(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, verbose_name='клиент', blank=True, null=True,
                             related_name='comments')
    rating = models.IntegerField(verbose_name='рейтинг')
    text = models.TextField(blank=True, null=True, verbose_name='текст комментария')

    class Meta:
        verbose_name = 'Комментарий пользователей'
        verbose_name_plural = 'Комментарии пользователей'


class UserNotification(models.Model):
    MESSAGE_LEVELS = [
        ('Info', 'Info'),
        ('Warning', 'Warning'),
        ('Critical', 'Critical')
    ]
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, verbose_name='пользователь', blank=True, null=True,
                             related_name='notifications')
    message_text = models.TextField(blank=True, null=True, verbose_name='текст сообщения')
    message_type = models.CharField(max_length=200, blank=True, null=True, verbose_name='тип сообщения')
    message_level = models.CharField(max_length=10, choices=MESSAGE_LEVELS, blank=True, null=True, verbose_name='уровень сообщения')
    message_datetime = models.DateTimeField(auto_now_add=True, blank=True, null=True, verbose_name='дата сообщения')


    class Meta:
        verbose_name = 'Сообщение пользователя'
        verbose_name_plural = 'Сообщения пользователей'

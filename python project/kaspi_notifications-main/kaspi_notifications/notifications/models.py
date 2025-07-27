import datetime
import json
import os
import random
import string
import uuid

from django.db import models
from django.contrib.auth.models import AbstractUser
from django.contrib import admin
from django.utils.html import format_html
from dotenv import load_dotenv

from notifications.constants import MERCHANT_HELP_TEXT_GREEN_API, MERCHANT_HELP_TEXT_GREEN_API_REVIEW, CREATED, \
    MERCHANT_HELP_TEXT_GREEN_API_NEGATIVE_REVIEW, MERCHANT_HELP_TEXT_GREEN_API_CONFIRM_REVIEW, \
    MERCHANT_HELP_TEXT_GREEN_API_POSTAMAT_ORDER
from django.core.exceptions import ValidationError
from django.utils import timezone
load_dotenv()

from notifications.kaspi_api.api_requests import is_token_valid
from notifications.greenapi_instance_functions import create_new_green_api_instance_green_api, \
    delete_green_api_instance, send_message_through_green_api_auto_fill
from notifications.utils import format_phone_number, set_settings_green_api_util


class Manager(models.Model):
    name = models.CharField(max_length=250, blank=False, null=True, verbose_name='имя')
    phone_number = models.CharField(max_length=350, blank=False, null=True, verbose_name='телефон номер менеджера')

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = 'Менеджер'
        verbose_name_plural = 'Менеджеры'


BASE_URL = os.getenv('BASE_URL')


class Merchant(models.Model):
    TYPES = [
        ('GREEN_API', 'Green Api'),
        ('WHATSAPP', 'Whatsapp Api'),
    ]
    TEMPLATE_TYPES = [
        ('WITH_BUTTONS', 'с кнопками'),
        ('WITHOUT_BUTTONS', 'без кнопок'),
    ]
    MESSAGE_LANGUAGE = [
        ('RU', 'русский'),
        ('KZ', 'казахский'),
    ]
    SUBSCRIPTION_TYPES = [
        ('demo', 'Демо'),
        ('standard', 'Стандарт'),
        ('standard+', 'Стандарт+'),
        ('business', 'Бизнес')
    ]

    EXECUTION_TYPE_A = 'A'
    EXECUTION_TYPE_B = 'B'

    EXECUTION_TYPES = (
        (EXECUTION_TYPE_A, 'A'),
        (EXECUTION_TYPE_B, 'B'),
    )

    execution_type = models.CharField(max_length=5, choices=EXECUTION_TYPES, default=EXECUTION_TYPE_A,
                                      verbose_name='Тип (Для разработчиков)')
    uid = models.CharField(default=uuid.uuid4, unique=True, db_index=True, blank=False, null=True, editable=False)
    kaspi_token = models.CharField(max_length=250, blank=True, null=True, verbose_name='id аккаунта каспи')
    kaspi_shop_uid = models.CharField(max_length=100, blank=True, null=True, verbose_name='uid каспи магазин')
    whatsapp_token = models.CharField(max_length=300, blank=True, null=True, verbose_name='ватсап токен')
    whatsapp_id = models.CharField(max_length=250, blank=True, null=True, verbose_name='id аккаунта ватсап')
    whatsapp_number = models.CharField(max_length=250, blank=True, null=True, verbose_name='номер ватсап')
    promo_code = models.CharField(max_length=10, blank=True, null=True, verbose_name='Промо-код')
    creation_date = models.DateTimeField(auto_now_add=True, verbose_name='время создания записи')
    subscription_date_start = models.DateField(blank=True, null=True, verbose_name='дата начала подписки')
    subscription_date_end = models.DateField(blank=True, null=True, verbose_name='дата оконч-я подписки')
    subscription_days = models.IntegerField(blank=True, null=True, default=3, verbose_name='дни по подписке')
    name = models.CharField(max_length=250, blank=False, null=True, verbose_name='имя')
    enabled = models.BooleanField(default=False, blank=True, null=True, verbose_name='активирован')
    daily_message_counts = models.JSONField(default=dict, verbose_name='Ежедневные количества сообщений')
    type_of_subscription = models.CharField(max_length=100, choices=SUBSCRIPTION_TYPES, blank=False, null=True,
                                            verbose_name='тип подписки')
    manager = models.ForeignKey(Manager, on_delete=models.CASCADE, related_name='merchants', blank=False, null=True,
                                verbose_name='менеджер')
    contact_number = models.CharField(max_length=350, blank=False, null=True, verbose_name='телефон для связи')
    communication_type = models.CharField(max_length=250, choices=TYPES, blank=False, null=True,
                                          verbose_name='тип коммуникации')
    autofill_green_api = models.BooleanField(default=False, blank=True, null=True,
                                             verbose_name='автоматическое заполнение грин апи')
    merchant_shop_link = models.CharField(max_length=350, blank=True, null=True, verbose_name='ссылка на сайт')
    manager_whatsapp_number = models.CharField(max_length=350, blank=True, null=True, verbose_name='номер менеджера')
    message_language = models.CharField(max_length=250, choices=MESSAGE_LANGUAGE, blank=True, null=True, default='RU',
                                        verbose_name='язык')
    template_type = models.CharField(max_length=250, choices=TEMPLATE_TYPES, blank=True, null=True,
                                     verbose_name='тип шаблона')
    send_first_message = models.BooleanField(default=True, blank=True, null=True,
                                             verbose_name='отправить первое сообщение')
    send_second_message = models.BooleanField(default=True, blank=True, null=True,
                                              verbose_name='отправить второе сообщение')
    message_template_name_new_order = models.CharField(max_length=350, blank=True, null=True,
                                                       verbose_name='шаблон для новых заказов')
    message_template_name_ask_for_comment = models.CharField(max_length=350, blank=True, null=True,
                                                             verbose_name='шаблон для отзывов')
    message_template_name_ask_for_self_call = models.CharField(max_length=350, blank=True, null=True,
                                                               verbose_name='шаблон для самовызов')
    green_api_token = models.CharField(max_length=350, blank=True, null=True, verbose_name='токен грин апи')
    green_api_instance_id = models.CharField(max_length=350, blank=True, null=True, verbose_name='инстанс грин апи')
    green_api_qr_link = models.CharField(max_length=350, blank=True, null=True, verbose_name='ссылка на QR грин апи')
    second_message_delay = models.IntegerField(default=0, blank=True, null=True,
                                               verbose_name='отправить второе сообщения с задержкой в минутах')
    green_api_message_text_new_order = models.TextField(blank=True, null=True,
                                                        verbose_name='шаблон текста для новых заказов грин апи',
                                                        help_text=MERCHANT_HELP_TEXT_GREEN_API)
    green_api_message_text_for_review = models.TextField(blank=True, null=True,
                                                         verbose_name='шаблон текста для отзыва грин апи',
                                                         help_text=MERCHANT_HELP_TEXT_GREEN_API_REVIEW)
    green_api_message_text_for_negative_review = models.TextField(
        blank=True, null=True,
        verbose_name='Шаблон текста для обработки негативного отзыва в Green API',
        help_text=MERCHANT_HELP_TEXT_GREEN_API_NEGATIVE_REVIEW
    )
    green_api_message_text_for_confirm_review = models.TextField(
        blank=True, null=True,
        verbose_name='Шаблон текста для запроса отзыва с подтверждением (1, 2)',
        help_text=MERCHANT_HELP_TEXT_GREEN_API_CONFIRM_REVIEW
    )
    green_api_message_text_for_postamat_order = models.TextField(blank=True, null=True,
                                                         verbose_name='шаблон текста для заказа в постомат',
                                                         help_text=MERCHANT_HELP_TEXT_GREEN_API_POSTAMAT_ORDER)
    green_api_review_with_confirm = models.BooleanField(default=False, blank=True, null=True,
                                                        verbose_name='отзыв green api с подтверждением')
    auto_accepting = models.BooleanField(default=False, blank=True, null=True, verbose_name='автопринятие заказов')
    send_messages_by_status = models.BooleanField(default=False, blank=True, null=True,
                                                  verbose_name='отправка сообщений по статусу')
    chat_id = models.CharField(max_length=200, blank=True, null=True, verbose_name='id телеграм-чата')
    membership_status = models.CharField(max_length=200, blank=True, null=True, verbose_name='статус подключения')
    telegram_mode = models.CharField(max_length=200, blank=True, null=True, verbose_name='режим сообщений в тг')
    freeze_tariff = models.BooleanField(default=False, blank=True, null=True, verbose_name='заморозкa тарифа')
    webhook_url = models.CharField(max_length=255, blank=True, null=True, verbose_name='Webhook URL')

    def update_message_count(self):
        today = timezone.now().date().isoformat()

        if "today" in self.daily_message_counts:
            last_update = self.daily_message_counts.get("last_update")
            if last_update and last_update != today:
                self.daily_message_counts[last_update] = self.daily_message_counts["today"]
                del self.daily_message_counts["today"]

        if "today" in self.daily_message_counts:
            self.daily_message_counts["today"] += 1
        else:
            self.daily_message_counts["today"] = 1

        self.daily_message_counts["last_update"] = today
        self.save()

    def todays_message_count(self):
        return self.daily_message_counts.get("today", 0)

    todays_message_count.short_description = 'сообщений за сегодня (шт)'

    def format_json_pretty(self, data):
        formatted_data = '\n'
        for key, value in data.items():
            formatted_data += f'  {key} = {value},\n'
        formatted_data = formatted_data.rstrip(',\n') + '\n'
        return formatted_data

    def formatted_daily_message_counts(self):
        try:
            formatted_data = self.format_json_pretty(self.daily_message_counts)
            html_content = format_html(
                '<pre style="background: #f8f8f8; padding: 10px; border-radius: 5px; border: 1px solid #ddd; font-family: monospace;">{}</pre>',
                formatted_data
            )
            return html_content
        except (TypeError, json.JSONDecodeError):
            return self.daily_message_counts

    formatted_daily_message_counts.short_description = 'Ежедневные количества сообщений'

    class Meta:
        verbose_name = 'Продавец Kaspi'
        verbose_name_plural = 'Продавцы Kaspi'

    def __str__(self):
        return self.name if self.name else ''

    def clean(self):
        super().clean()
        link = f'https://sharex.ddns.net/qr-link-whatsapp/{self.uid}'
        self.green_api_qr_link = link

        if self.second_message_delay != 0:
            if not (29 < self.second_message_delay < 1441):
                raise ValidationError(
                    {
                        'second_message_delay': 'Время задержкой должно составлять от 30 до 1440 минут'
                    }
                )

        if self.kaspi_token:
            existing_merchants = Merchant.objects.filter(kaspi_token=self.kaspi_token)
            if self.pk:
                existing_merchants = existing_merchants.exclude(pk=self.pk)

            if existing_merchants.exists():
                existing_merchant = existing_merchants.first()
                if not self.kaspi_shop_uid:
                    raise ValidationError(
                        {
                            'kaspi_token': f'Продавец с таким токеном Kaspi уже существует: имя={existing_merchant.name}.\n'
                                           'Если вы хотите назначить один и тот же токен Kaspi нескольким продавцам, '
                                           'пожалуйста, укажите UID магазина Kaspi.'})

            if not is_token_valid(self.kaspi_token, self.kaspi_token, self.kaspi_shop_uid):
                raise ValidationError(
                    {
                        'kaspi_token': 'Токен Kaspi недействителен или не правильно указан UID магазина Kaspi'
                    }
                )

        if self.communication_type == 'GREEN_API':
            print('Green api')
            if not self.green_api_instance_id or not self.green_api_token:
                raise ValidationError(
                    {
                        'green_api_instance_id': 'Пожалуйста, укажите instance id и токен Green Api'
                    }
                )

        if self.green_api_review_with_confirm:
            self.webhook_url = f"{BASE_URL}/webhook/{str(self.uid)}/"

        if self.green_api_instance_id:
            if not self.green_api_token:
                raise ValidationError(
                    {
                        'green_api_token': 'Пожалуйста, укажите токен Green Api'
                    }
                )
            else:
                if self.green_api_review_with_confirm:
                    setting_green_api = set_settings_green_api_util(self.green_api_instance_id, self.green_api_token, self.webhook_url, os.getenv('GREEN_API_TOKEN'))
                else:
                    setting_green_api = set_settings_green_api_util(self.green_api_instance_id, self.green_api_token, '', '')
                if not setting_green_api:
                    raise ValidationError(
                        {
                            'green_api_instance_id': 'Ошибка Green Api'
                        }
                    )

        if self.green_api_message_text_new_order:
            required_placeholders = ['{client_name}', '{merchant_name}', '{product_names}', '{planned_delivery_date}',
                                     '{kaspi_order_code}']
            for placeholder in required_placeholders:
                if placeholder not in self.green_api_message_text_new_order:
                    raise ValidationError({
                        'green_api_message_text_new_order': (
                            f'Шаблон должен содержать все необходимые заполнители, пожалуйста, проверьте внимательно: {", ".join(required_placeholders)}'
                        )
                    })

        if self.green_api_message_text_for_postamat_order:
            required_placeholders = ['{client_name}', '{kaspi_order_code}', '{product_names}']
            for placeholder in required_placeholders:
                if placeholder not in self.green_api_message_text_for_postamat_order:
                    raise ValidationError({
                        'green_api_message_text_for_postamat_order': (
                            f'Шаблон должен содержать все необходимые заполнители, пожалуйста, проверьте внимательно: {", ".join(required_placeholders)}'
                        )
                    })

        if self.autofill_green_api:
            if self.communication_type == 'GREEN_API':
                try:
                    if not self.green_api_instance_id:
                        green_api_instance_data = create_new_green_api_instance_green_api()
                        instance = green_api_instance_data['idInstance']
                        api_token = green_api_instance_data['apiTokenInstance']
                    else:
                        instance = self.green_api_instance_id
                        api_token = self.green_api_token

                    self.green_api_instance_id = instance
                    self.green_api_token = api_token

                    if self.contact_number:
                        phone_number = format_phone_number(self.contact_number)
                        message_link = f'Откройте эту ссылку и отсканируйте QR-код. Если QR-код не активен, пожалуйста, попробуйте обновить страницу: {link}'
                        send_message_through_green_api_auto_fill.apply_async(args=(
                            phone_number, message_link, '7700939485',
                            '9c3a7af9ee3c47cf90551a9a576e69bca3e91732b9f4452e83'),
                            countdown=30)
                        self.autofill_green_api = False
                    else:
                        raise ValidationError({
                            'contact_number': (
                                f'Пожалуйста, введите номер клиента в WhatsApp'
                            )
                        })

                except BaseException as e:
                    raise ValidationError({
                        'autofill_green_api': (
                            f'Ошибка при автозаполнении, пожалуйста, отключите автозаполнение и выполните вручную, error = {e}'
                        )
                    })

            else:
                raise ValidationError({
                    'autofill_green_api': (
                        f'Если вы хотите автоматически заполнить green api, выберите green api'
                    )
                })

        if self.promo_code:
            try:
                promo_code = PromoCode.objects.get(code=self.promo_code)
            except PromoCode.DoesNotExist:
                raise ValidationError({'promo_code': 'Промо-код не существует'})

        if self.freeze_tariff:
            delete_green_api_instance(self.green_api_instance_id)
            self.green_api_instance_id = ''
            self.green_api_token = ''
            self.enabled = False

    def save(self, *args, **kwargs):
        if self.subscription_date_start and self.subscription_days:
            self.subscription_date_end = self.subscription_date_start + datetime.timedelta(days=self.subscription_days)

        if self.promo_code:
            try:
                promo_code = PromoCode.objects.get(code=self.promo_code)
                if promo_code.merchant.id != self.id:
                    promo_code.apply_cashback(self)
                    Cashback.objects.create(
                        merchant=promo_code.merchant,
                        days=promo_code.cashback_days,
                        description=f'Кэшбэк за привлечение {self.kaspi_token}'
                    )
                else:
                    raise ValidationError({'promo_code': 'Это ваш промо код. Промо код должен быть с другого магазина'})
            except PromoCode.DoesNotExist:
                pass  # Handle invalid promo code case

        super(Merchant, self).save(*args, **kwargs)

        if not PromoCode.objects.filter(merchant=self).exists():
            code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
            while PromoCode.objects.filter(code=code).exists():
                code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
            PromoCode.objects.create(
                code=code,
                merchant=self,
                cashback_days=5)

    @admin.display(description='Остаток дней по подписке')
    def readable_subscription_days_left(self):
        if self.subscription_date_start is not None and self.subscription_days is not None:
            period_end_date = self.subscription_date_start + datetime.timedelta(days=self.subscription_days)
            date_now = datetime.datetime.now().date()
            days_left = (period_end_date - date_now).days if period_end_date > date_now else 0

            if int(days_left) > 15:
                color = 'green'
            elif 15 > int(days_left) > 3:
                color = 'orange'
            else:
                color = 'red'
            return format_html(
                '<b style="color:{};">{}</b>',
                color,
                days_left,
            )

    def is_whatsapp_communication(self) -> bool:
        return self.communication_type == 'WHATSAPP'

    def get_subscription_type(self) -> str:
        return self.type_of_subscription

    def is_template_without_buttons(self) -> bool:
        return self.template_type == 'WITHOUT_BUTTONS'

    def is_template_rus(self) -> bool:
        return self.message_language == 'RU'

    def is_auto_accepting_orders(self) -> bool:
        return self.auto_accepting and (not self.is_whatsapp_communication() or self.is_template_without_buttons())


class KaspiNewOrder(models.Model):
    PICKUP_DELIVERY_TYPE = 'Самовывоз'
    POSTOMAT_DELIVERY_TYPE = 'Postamat'

    kaspi_order_id = models.CharField(max_length=100, blank=True, null=True, verbose_name='id заказа в каспи', db_index=True)
    kaspi_order_code = models.CharField(max_length=100, blank=True, null=True, verbose_name='код заказа в каспи', db_index=True)
    order_date = models.DateField(blank=True, null=True, verbose_name='дата заказа в каспи')
    order_status = models.CharField(max_length=100, blank=True, null=True, verbose_name='статус заказа')
    notification_status = models.CharField(max_length=100, blank=True, null=True, verbose_name='статус уведомления')
    notification_time = models.DateTimeField(auto_now=True, verbose_name='время уведомления')
    phone_number = models.CharField(max_length=100, blank=True, null=True, verbose_name='номер телефона')
    full_name = models.CharField(max_length=100, blank=True, null=True, verbose_name='ФИО клиента')
    client_answer = models.CharField(max_length=100, blank=True, null=True, verbose_name='ответ клиента')
    first_message_delivery_status = models.CharField(max_length=700, blank=True, null=True,
                                                     verbose_name='статус первого сообщения')
    first_message_sending_time = models.DateTimeField(blank=True, null=True,
                                                      verbose_name='время уведомления первого сообшения')
    second_message_delivery_status = models.CharField(max_length=700, blank=True, null=True,
                                                      verbose_name='статус второго сообщения')
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, related_name='orders', blank=True, null=True,
                                 verbose_name='продавец')
    auto_accepted = models.BooleanField(default=False, blank=True, null=True, verbose_name='заказ автопринят ботом')
    api_order_status = models.CharField(max_length=200, blank=True, null=True, verbose_name='статус заказа по АПИ')
    api_order_state = models.CharField(max_length=200, blank=True, null=True, verbose_name='состояние заказа по АПИ')
    is_delivery_to_postamat = models.BooleanField(default=False, blank=True, null=True,
                                                  verbose_name='доставка на постамат')
    planned_delivery_date = models.CharField(max_length=100, blank=True, null=True,
                                             verbose_name='планируемая дата поставки')
    is_kaspi_postamat = models.BooleanField(default=False, blank=True, null=True)
    created_at = models.DateTimeField(verbose_name='Время создание в нашей системе', auto_now_add=True, null=True, blank=True)

    class Meta:
        verbose_name = 'Новый заказ Kaspi'
        verbose_name_plural = 'Новые заказы Kaspi'
        ordering = ('-id',)

    def __str__(self):
        return self.kaspi_order_code

    def order_can_be_auto_accepted(self):
        return self.api_order_status == 'APPROVED_BY_BANK'


class OrderProduct(models.Model):
    order = models.ForeignKey(KaspiNewOrder, on_delete=models.CASCADE, related_name='products', blank=True, null=True,
                              verbose_name='заказ каспи')
    name = models.CharField(max_length=1000, blank=True, null=True, verbose_name='название')
    product_code = models.CharField(max_length=600, blank=True, null=True, verbose_name='код продукта')
    product_mastercode = models.CharField(max_length=600, blank=True, null=True, verbose_name='мастеркод продукта')
    category = models.CharField(max_length=600, blank=True, null=True, verbose_name='категория')
    quantity = models.IntegerField(blank=True, null=True, verbose_name='количество')
    price = models.IntegerField(blank=True, null=True, verbose_name='цена')

    class Meta:
        verbose_name = 'Продукт'
        verbose_name_plural = 'Продукты'


class CustomUser(AbstractUser):
    user_company = models.ForeignKey(Merchant, on_delete=models.CASCADE, blank=True, null=True,
                                     verbose_name='компания пользователя',
                                     related_name='companies')
    core_id = models.IntegerField(unique=True, blank=True, null=True,
                                  verbose_name='core id пользователя')

    def has_group(self, group_name):
        return self.groups.filter(name=group_name).exists()


class Invoice(models.Model):
    creation_date = models.DateField(auto_now_add=True, verbose_name='дата создания')
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, related_name='invoices', blank=True, null=True,
                                 verbose_name='продавец')
    type = models.CharField(max_length=300, verbose_name='тип инвойса')
    currency = models.CharField(max_length=10, default='KZT', verbose_name='тип инвойса')
    amount = models.IntegerField(blank=True, null=True, verbose_name='сумма')
    status = models.CharField(max_length=10, default='draft', verbose_name='статус инвойса')

    class Meta:
        verbose_name = 'Инвойс'
        verbose_name_plural = 'Инвойсы'

    def is_draft(self) -> bool:
        return self.status == 'draft'

    def is_paid(self) -> bool:
        return self.status == 'paid'


class PromoCode(models.Model):
    code = models.CharField(max_length=10, unique=True, verbose_name='Код')
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, verbose_name='Магазин')
    cashback_days = models.IntegerField(default=5, verbose_name='Дни кэшбэка')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создан')

    class Meta:
        verbose_name = 'Промо-код'
        verbose_name_plural = 'Промо-коды'

    def __str__(self):
        return self.code

    def apply_cashback(self, referred_merchant):
        pass
        # self.merchant.subscription_days += self.cashback_days
        # self.merchant.save()


class Cashback(models.Model):
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, related_name='cashbacks', verbose_name='Магазин')
    days = models.IntegerField(verbose_name='Дни')
    description = models.CharField(max_length=255, verbose_name='Описание')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создан')

    class Meta:
        verbose_name = 'Кэшбэк'
        verbose_name_plural = 'Кэшбэки'

    def __str__(self):
        return f"{self.merchant.name} - {self.days} дней"


class Mailing(models.Model):
    name = models.CharField(max_length=250, blank=True, null=True, verbose_name='имя')
    kaspi_token = models.CharField(max_length=250, blank=True, null=True, verbose_name='id аккаунта каспи')
    message_id = models.CharField(max_length=250, blank=True, null=True, verbose_name='ид сообщения')
    status_message = models.CharField(max_length=100, blank=True, null=True, verbose_name='статус уведомления')
    notification_status = models.CharField(max_length=100, blank=True, null=True, verbose_name='статус сообщение')
    green_api_token = models.CharField(max_length=350, blank=True, null=True, verbose_name='токен грин апи')
    green_api_instance_id = models.CharField(max_length=350, blank=True, null=True, verbose_name='инстанс грин апи')
    phone_number = models.CharField(max_length=350, blank=False, null=True, verbose_name='телефон номер')

    class Meta:
        verbose_name = 'Рассылки'
        verbose_name_plural = 'Рассылки'

    def __str__(self):
        return self.name


class ResendMessage(models.Model):
    merchant = models.ForeignKey(Merchant, on_delete=models.CASCADE, verbose_name='Магазин', blank=False, null=True)
    start_date = models.DateField(blank=False, null=True, verbose_name='с какого число')
    first_message_delivery_status = models.CharField(max_length=250, blank=False, null=True,
                                                     verbose_name='статус первого сообщения')
    status = models.CharField(max_length=100, blank=True, null=True, verbose_name='статус')

    def save(self, *args, **kwargs):
        self.status = CREATED
        super().save(*args, **kwargs)
        from notifications.hand_do_functions import get_kaspi_new_orders
        merchant_id = self.merchant.id
        creation_date = self.start_date.strftime("%d.%m.%Y")
        first_message_delivery_status = self.first_message_delivery_status
        # get_kaspi_new_orders(merchant_id, creation_date, first_message_delivery_status, self.id)
        get_kaspi_new_orders.apply_async(
            args=[merchant_id, creation_date, first_message_delivery_status, self.id],
            countdown=20
        )

    class Meta:
        verbose_name = 'Переотправить сообщений'
        verbose_name_plural = 'Переотправить сообщений'

    def __str__(self):
        return 'Переотправить сообщений'

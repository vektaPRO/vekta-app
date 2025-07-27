import logging
import time
from typing import Dict

from django.conf import settings
from pktools.string import prettify_phone_number
from notifications.utils import greeting
from notifications.models import Merchant, KaspiNewOrder
from api.service.green_api.client import Client

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class DefaultMessageMixin:
    NEW_ORDER_MESSAGE_TYPE = 'NEW_ORDER_MESSAGE_TYPE'
    REVIEW_MESSAGE_TYPE = 'REVIEW_MESSAGE_TYPE'
    INSTANCE_STATUS_MESSAGE_TYPE = 'INSTANCE_STATUS_MESSAGE_TYPE'
    CONFIRM_REVIEW_MESSAGE_TYPE = 'CONFIRM_REVIEW_MESSAGE_TYPE'
    POSTAMAT_MESSAGE_TYPE = 'POSTAMAT_MESSAGE_TYPE'

    KK_LANG = 'KK'
    RU_LANG = 'RU'
    MIXED_LANG = 'MIXED'
    DEFAULT_TEMPLATE = 'DEFAULT_TEMPLATE'
    PICKUP_OR_POSTOMAT_TEMPLATE = 'PICKUP_OR_POSTOMAT_TEMPLATE'
    REGULAR_TEMPLATE = 'REGULAR_TEMPLATE'
    CONFIRM_REVIEW_TEMPLATE = 'CONFIRM_REVIEW_TEMPLATE'
    REGULAR_REVIEW_TEMPLATE = 'REGULAR_REVIEW_TEMPLATE'
    INSTANCE_STATUS_TEMPLATE = 'INSTANCE_STATUS_TEMPLATE'
    POSTOMAT_DELIVERY_NOTIFICATION_TEMPLATE = 'POSTOMAT_DELIVERY_NOTIFICATION_TEMPLATE'

    MESSAGES = {
        KK_LANG: {
            PICKUP_OR_POSTOMAT_TEMPLATE: '{greeting}, {client_name}!\n'
                                         '*{merchant_name}* дүкенінен тапсырыс бергеніңіз үшін рақмет\n'
                                         'Сіздің тапсырысыңыз: {product_names}\n'
                                         'Жеткізу түрі: {delivery_type}.\n'
                                         'Тапсырыс нөмірі: {kaspi_order_code}\n'
                                         '\nСаудаңыз сәтті болсын!',
            REGULAR_TEMPLATE: '{greeting}, {client_name}!\n'
                              '*{merchant_name}* дүкенінен тапсырыс бергеніңіз үшін рақмет.\n'
                              'Сіздің тапсырысыңыз:\n\n{product_names}\n\n'
                              'Жоспарланған жеткізу күні: {planned_delivery_date}.\n'
                              'Жеткізу көрсетілген күні жүзеге асырылады.\n'
                              'Тапсырыс нөмірі: {kaspi_order_code}\n'
                              'Тапсырысыңызды тез арада жинап, сізге жібереміз.\n'
                              'Саудаңыз сәтті болсын!',

            REGULAR_REVIEW_TEMPLATE: '{greeting}, {client_name}!\n'
                                     '*{merchant_name}* дүкенінен сатып алуыңызбен құттықтаймыз!\n'
                                     'Cізге барлығы ұнады деп үміттенеміз.\n'
                                     'Cілтеме арқылы өтіп, *біздің дүкеннің атауын* көрсете отырып, '
                                     'пікір қалдыра кетсеңіз⤵️:\n'
                                     '{products_urls}\n'
                                     '\nБіз үшін сіздің пікіріңіз өте маңызды! '
                                     'Сілтеме белсенді болу үшін жауап ретінде кез келген хабарлама жазыңыз.',

            CONFIRM_REVIEW_TEMPLATE: '{greeting}, {client_name}!\n'
                                     'Сатып алуыңызбен құттықтаймыз!\n'
                                     'Сізге барлығы ұнады ма?\n'
                                     '1 - Иә, барлығы жақсы.\n'
                                     '2 - Жоқ, маған ұнамады.\n'
                                     'Өтініш, тек 1 немесе 2 санын жіберіңіз.',

            INSTANCE_STATUS_TEMPLATE: 'Құрметті {merchant_name} дүкені,\niRocket.kz командасы сізді алаңдатып отыр.\n'
                                      'Сіздің Whatsapp есептік жазбаңыз жүйемізден авторизацияланғанын анықтадық және, '
                                      'өкінішке орай, онсыз бот сіздің клиенттеріңізге хабар жібере алмайды.\n'
                                      'Ботқа қайта қосылу үшін бізге хат жазыңыз.',
            POSTOMAT_DELIVERY_NOTIFICATION_TEMPLATE: 'Сәлеметсіз бе, құрметті {client_name},\nТапсырыс нөміріңіз '
                                                     '{kaspi_order_code} Kaspi пошта бөлімшесіне сәтті жеткізілді.\n'
                                                     'Өніміңіз: {product_names}\nТапсырысыңыз автоматты түрде жойылмай.'
                                                     ' тұрып, оны алуды ұмытпаңыз.\nСатып алғаныңыз үшін рақмет!\n'
        },
        RU_LANG: {
            PICKUP_OR_POSTOMAT_TEMPLATE: '{greeting}, {client_name}!\n'
                                         'Спасибо за заказ в магазине *{merchant_name}*\n'
                                         'Вы заказали: {product_names}\n'
                                         'Тип вызова: {delivery_type}.\n'
                                         'Номер заказа: {kaspi_order_code}\n\n'
                                         'Хороших покупок!',
            REGULAR_TEMPLATE: '{greeting}, {client_name}!\n'
                              'Спасибо за заказ в магазине *{merchant_name}*.\n'
                              'Вы заказали:\n\n{product_names}\n\n'
                              'Плановая дата доставки: {planned_delivery_date}.\n'
                              'Доставка будет осуществлена в указанную дату.\n'
                              'Номер заказа: {kaspi_order_code}\n'
                              'В ближайшее время мы соберём заказ и отправим вам.\n'
                              'Хороших покупок!',

            REGULAR_REVIEW_TEMPLATE: '{greeting}, {client_name}!\n'
                                     'Поздравляем с покупкой с магазина *{merchant_name}*!\n'
                                     'Мы надеемся, что вам все понравилось.\n'
                                     'Если вам не сложно, пожалуйста оставьте отзыв *с указанием названия нашего '
                                     'магазина* перейдя по ссылке⤵️:\n'
                                     '{products_urls}\n'
                                     '\nВаш отзыв очень важен для нас!'
                                     'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.',

            CONFIRM_REVIEW_TEMPLATE: '{greeting}, {client_name}!\n'
                                     'Поздравляем с покупкой!\n'
                                     'Всё ли вам понравилось?\n'
                                     '1 - Да, всё хорошо.\n'
                                     '2 - Нет, мне не понравилось.\n'
                                     'Пожалуйста, отправьте только цифру (1 или 2).',

            INSTANCE_STATUS_TEMPLATE: 'Уважаемый магазин {merchant_name},\nВас беспокоит команда iRocket.kz.'
                                      '\nМы обнаружили, что ваш Whatsapp аккаунт разавторизовался с нашей системы и, '
                                      'к сожалению, без этого бот не сможет отправлять сообщения вашим клиентам.'
                                      '\nПросьба написать нам для подключения бота снова.',

            POSTOMAT_DELIVERY_NOTIFICATION_TEMPLATE:  'Здравствуйте, уважаемый(ая) {client_name},\nВаш заказ с номером '
                                                      '{kaspi_order_code} был успешно доставлен в Kaspi постомат.\n'
                                                      'Ваш товар: {product_names}\nНе забудьте забрать его до '
                                                      'автоматической отмены заказа.\nСпасибо за покупку!\n'
        },
        DEFAULT_TEMPLATE: '{greeting}, {client_name}!\n'
                          'Спасибо за заказ в магазине *{merchant_name}*\n'
                          'Вы заказали: {product_names}\n'
                          'Плановая дата доставки: {planned_delivery_date}.\n'
                          'Доставка будет осуществлена в указанную дату.\n'
                          'Номер заказа: {kaspi_order_code}.\n'
                          'В ближайшее время мы соберем заказ и отправим вам.\n'
                          'Хороших покупок!',
    }

    merchant: Merchant

    def merchant_template(self, message_type: str):
        if message_type == self.NEW_ORDER_MESSAGE_TYPE:
            return self.merchant.green_api_message_text_new_order
        if message_type == self.CONFIRM_REVIEW_MESSAGE_TYPE:
            return self.merchant.green_api_message_text_for_confirm_review
        if message_type == self.POSTAMAT_MESSAGE_TYPE:
            return self.merchant.green_api_message_text_for_postamat_order
        return self.merchant.green_api_message_text_for_review

    def merchant_message(self, context: dict, message_type: str):
        template = self.merchant_template(message_type=message_type)

        if "{hello_rus}" in template:
            context['hello_rus'] = greeting(language_rus=True)

        if "{hello_kaz}" in template:
            context['hello_kaz'] = greeting(language_rus=False)
        message = None
        try:
            message = template.format(**context)
            message = message.replace('\\n', '\n')
        except KeyError:
            # TODO: 2 - sms қате болса да 1 - sms жібереді, ол дұрыс емес
            if message_type == self.NEW_ORDER_MESSAGE_TYPE:
                message = self.__message(context, self.NEW_ORDER_MESSAGE_TYPE)
            elif message_type == self.REVIEW_MESSAGE_TYPE:
                message = self.__message(context, self.REGULAR_REVIEW_TEMPLATE)
            elif message_type == self.CONFIRM_REVIEW_MESSAGE_TYPE:
                message = self.__message(context, self.CONFIRM_REVIEW_TEMPLATE)
            elif message_type == self.POSTAMAT_MESSAGE_TYPE:
                message = self.__message(context, self.POSTOMAT_DELIVERY_NOTIFICATION_TEMPLATE)

            logger.exception("#DefaultMessageMixin.merchant_message", extra={
                "context": context})

        return message

    def __message(self, context: dict, template: str):
        kk_message = self.MESSAGES[self.KK_LANG][template].format(greeting=greeting(language_rus=False), **context)
        ru_message = self.MESSAGES[self.RU_LANG][template].format(greeting=greeting(language_rus=True), **context)

        if context['lang'] == self.RU_LANG:
            return ru_message

        if context['lang'] == self.MIXED_LANG:
            return '%s\n\n🔸🔸🔸\n\n%s' % (kk_message, ru_message)

    def construct_message(self, order: KaspiNewOrder, products: list, message_type: str):
        # TODO product_info тілді реттеу
        # TODO delivery_type modelkaga qosu kerek
        # TODO: есім мен тегті бөлек сақтау БД
        product_info = [f'{product[1]}, количество: {product[2]} шт.' for product in products]
        products_urls = [settings.KASPI_ORDER_REVIEW_URL % (order.kaspi_order_code, product[3]) for product in products]
        products_names = [f'{product[1]}' for product in products]
        context = {
            'client_name': order.full_name.split(' ')[1],
            'merchant_name': self.merchant.name,
            'product_names': '\n\n'.join(product_info),
            'planned_delivery_date': order.planned_delivery_date,
            'delivery_type': order.planned_delivery_date,
            'kaspi_order_code': order.kaspi_order_code,
            'products_urls': ',\n\n '.join(products_urls),
            'only_products_name': ', '.join(products_names),
        }

        if self.merchant.is_template_rus():
            context['lang'] = self.RU_LANG
        else:
            context['lang'] = self.MIXED_LANG

        if message_type == self.NEW_ORDER_MESSAGE_TYPE:
            # Егер магазиннің өзінің смс шамблоны болса соны қолдану
            if self.merchant.green_api_message_text_new_order:
                return self.merchant_message(context, message_type=message_type)

            if order.planned_delivery_date in (
                    KaspiNewOrder.PICKUP_DELIVERY_TYPE,
                    KaspiNewOrder.POSTOMAT_DELIVERY_TYPE
            ):
                return self.__message(context, self.PICKUP_OR_POSTOMAT_TEMPLATE)
            return self.__message(context, self.REGULAR_TEMPLATE)

        if message_type == self.REVIEW_MESSAGE_TYPE:
            if self.merchant.green_api_review_with_confirm:
                if self.merchant.green_api_message_text_for_confirm_review:
                    return self.merchant_message(context, message_type=self.CONFIRM_REVIEW_MESSAGE_TYPE)
                return self.__message(context, self.CONFIRM_REVIEW_TEMPLATE)

            if self.merchant.green_api_message_text_for_review:
                return self.merchant_message(context, message_type=message_type)

            return self.__message(context, self.REGULAR_REVIEW_TEMPLATE)

    def construct_message_for_merchant(self, merchant: Merchant, message_type: str, data: Dict = None):

        context = {
            'merchant_name': merchant.name if merchant.name else 'клиент',
            'lang': self.MIXED_LANG,
        }

        if data:
            context.update(data)

        if message_type == self.INSTANCE_STATUS_MESSAGE_TYPE:
            return self.__message(context=context,
                                  template=DefaultMessageMixin.INSTANCE_STATUS_TEMPLATE)

    def construct_message_for_postomat_delivery(self, order: KaspiNewOrder):
        context = {
            'client_name': order.full_name.split(" ")[1],
            'kaspi_order_code': order.kaspi_order_code,
            'product_names': ', '.join([f'{product.name}, количество: {product.quantity} шт.' for product in order.products.all()]),
            'lang': order.merchant.message_language,

        }

        if self.merchant.green_api_message_text_for_postamat_order:
            return self.merchant_message(context, message_type=self.POSTAMAT_MESSAGE_TYPE)

        return self.__message(context=context, template=DefaultMessageMixin.POSTOMAT_DELIVERY_NOTIFICATION_TEMPLATE)


class GreenApiConnector(DefaultMessageMixin):
    REQUESTS_RETRY_TIMEOUT_SECONDS = 2
    DELAY_SEND_MESSAGE_MILLISECONDS = 5000
    OUTGOING_WEBHOOK = 'yes'
    OUTGOING_MESSAGE_API_WEBHOOK = 'yes'

    def __init__(self, merchant: Merchant = None):
        self.client = Client()
        self.merchant = merchant

    def create_instance(self, name: str = None):
        """
           Creates a new instance in GreenApi and returns the instance
           Args:
            name (str, optional): The name of the instance to be created.
            If not provided and a Merchant instance is available, the Merchant's name will be used.
        """
        extra_data = {
            'instance_name': name
        }

        if name is None and self.merchant is not None:
            extra_data.update(
                {
                    'merchant': self.merchant.name,
                    'merchant_pk': self.merchant.pk,
                    'merchant_cabinet_id': self.merchant.kaspi_shop_uid,
                }
            )
            name = self.merchant.name

        instance = None

        try:
            instance = self.client.create_instance(name=name)

        except BaseException as err:
            logger.error("#GreenApiConnector.create_instance request error: %s", str(err), extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    instance = self.client.create_instance(name=name)

                    if instance is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenApiConnector.create_instance request retry error: %s", str(err),
                                 extra=extra_data)

        if instance is not None:
            logger.info(
                "#GreenApiConnector.create_instance response successful.Instance_id: %s, instance_api_token: %s, "
                "instance_type: %s", instance.id,
                instance.api_token,
                instance.type, extra=extra_data)

        return instance

    def delete_instance(self, instance_id: int = None):

        """
            Deletes an instance by instance_id in GreenApi and
            returns the instance with field "deleteInstanceAccount: true"

            Args:
            instance_id (str, optional): The ID of the instance to be deleted.
            If not provided and a Merchant instance is available, the Merchant's `green_api_instance_id` will be used.

        """
        extra_data = {
            'instance_id': instance_id
        }

        if self.merchant is not None and instance_id is None:
            instance_id = self.merchant.green_api_instance_id
            extra_data.update(
                {
                    'instance_id': instance_id,
                    'merchant': self.merchant.name,
                    'merchant_pk': self.merchant.pk,
                    'merchant_cabinet_id': self.merchant.kaspi_shop_uid
                }
            )

        instance = None

        try:
            instance = self.client.delete_instance(instance_id=instance_id)
        except BaseException as err:
            logger.error("#GreenApiConnector.delete_instance request error: %s",
                         str(err), extra=extra_data)

            for _ in range(3):
                try:
                    time.sleep(self.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    instance = self.client.delete_instance(instance_id=instance_id)
                    if instance is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenApiConnector.delete_instance request retry error: %s",
                                 str(err), extra=extra_data)

        if instance is None:
            logger.error("#GreenApiConnector.delete_instance response failed.", extra=extra_data)
            return None

        logger.info('#GreenApiConnector.delete_instance response successful.Instance_id: %s',
                    instance.id, extra=extra_data)
        return instance

    def send_message(self, chat_id: str, text: str):
        """
           Sends a text message using the Green API.
           The chat_id parameter should be the recipient's phone number.
           If the message is sent to a group, use the group ID as chat_id.
        """

        current_instance_id = getattr(self.merchant, 'green_api_instance_id', settings.IROCKET_INSTANCE_ID)
        current_api_token = getattr(self.merchant, 'green_api_token', settings.IROCKET_INSTANCE_TOKEN)
        chat_id = prettify_phone_number(chat_id)
        extra_data = {
            'merchant': getattr(self.merchant, 'name', 'IRocket'),
            'merchant_cabinet_id': getattr(self.merchant, 'kaspi_shop_uid', None),
            'instance_id': current_instance_id,
            'api_token': current_api_token,
            "chat_id": chat_id,
            "text": text
        }

        logger.info('#GreenApiConnector.send_message started', extra=extra_data)

        message = None
        try:
            message = self.client.send_message(instance_id=current_instance_id,
                                               api_token=current_api_token,
                                               chat_id=chat_id,
                                               text=text)
        except BaseException as err:
            logger.error("#GreenApiConnector.send_message request error: %s", str(err), extra=extra_data)

            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    message = self.client.send_message(instance_id=current_instance_id,
                                                       api_token=current_api_token,
                                                       chat_id=chat_id,
                                                       text=text)
                    if message is not None:
                        break

                except BaseException as err:
                    logger.error("#GreenApiConnector.send_message request retry error: %s", str(err), extra=extra_data)
        if message is None:
            logger.error(
                "#GreenApiConnector.send_message failed.", extra=extra_data)
            return None

        logger.info("#GreenApiConnector.send_message response successful. Message_id: %s",
                    message.id, extra=extra_data)

        return message

    def get_message(self, chat_id: str, message_id: str):
        """
            Retrieves information about a message previously sent using the Green API, including its status.
            The chat_id parameter should be the recipient's phone number.
            If the message was sent to a group, use the group ID as chat_id.
        """
        extra_data = {
            "chat_id": chat_id,
            "message_id": message_id,
            "merchant": self.merchant.name,
            "merchant_pk": self.merchant.pk,
            "merchant_cabinet_id": self.merchant.kaspi_shop_uid,
            "instance_id": self.merchant.green_api_instance_id,
            "api_token": self.merchant.green_api_token,
        }

        message = None

        try:
            message = self.client.get_message(instance_id=self.merchant.green_api_instance_id,
                                              api_token=self.merchant.green_api_token,
                                              chat_id=chat_id,
                                              message_id=message_id)
        except BaseException as err:
            logger.error("#GreenApiConnector.get_message request error: %s", str(err), extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    message = self.client.get_message(instance_id=self.merchant.green_api_instance_id,
                                                      api_token=self.merchant.green_api_token,
                                                      chat_id=chat_id,
                                                      message_id=message_id)
                    if message is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenApiConnector.get_message request retry error: %s", str(err),
                                 extra=extra_data)
        if message is None:
            logger.error(
                "#GreenApiConnector.get_message response failed.", extra=extra_data)
            return None

        logger.info("#GreenApiConnector.get_message response successful. Message_id: %s",
                    message.id, extra=extra_data)

        return message

    def get_instance_settings(self):
        """
            Retrieve current instance settings.
        """
        extra_data = {
            'instance_id': self.merchant.green_api_instance_id,
            'api_token': self.merchant.green_api_token,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'merchant_cabinet_id': self.merchant.kaspi_shop_uid
        }

        instance = None

        try:
            instance = self.client.get_instance_settings(
                instance_id=self.merchant.green_api_instance_id,
                api_token=self.merchant.green_api_token,
            )
        except BaseException as err:
            logger.error("#GreenApiConnector.get_instance_settings request error: %s", str(err), extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    instance = self.client.get_instance_settings(instance_id=self.merchant.green_api_instance_id,
                                                                 api_token=self.merchant.green_api_token, )
                    if instance is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenApiConnector.get_instance_settings request retry error: %s",
                                 str(err), extra=extra_data)
        if instance is None:
            logger.error("#GreenApiConnector.get_instance_settings response failed.", extra=extra_data)
            return None

        logger.info("#GreenApiConnector.get_instance_settings response successful.", extra=extra_data)

        return instance

    def set_instance_settings(self, outgoing_webhook: str = None, outgoing_message_api_webhook: str = None,
                              delay_send_messages_milliseconds: int = None, incoming_webhook: str = None,
                              webhook_url: str = None, webhook_token: str = None):
        """
            Set instance settings.
        """
        extra_data = {
            'instance_id': self.merchant.green_api_instance_id,
            'api_token': self.merchant.green_api_token,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'merchant_cabinet_id': self.merchant.kaspi_shop_uid
        }

        instance = None

        outgoing_webhook = outgoing_webhook or GreenApiConnector.OUTGOING_WEBHOOK
        delay_send_messages_milliseconds = (delay_send_messages_milliseconds or
                                            GreenApiConnector.DELAY_SEND_MESSAGE_MILLISECONDS)

        outgoing_message_api_webhook = outgoing_message_api_webhook or GreenApiConnector.OUTGOING_MESSAGE_API_WEBHOOK

        try:
            instance = self.client.set_instance_settings(
                instance_id=self.merchant.green_api_instance_id,
                api_token=self.merchant.green_api_token,
                outgoing_message_api_webhook=outgoing_message_api_webhook,
                outgoing_webhook=outgoing_webhook,
                delay_send_messages_milliseconds=delay_send_messages_milliseconds,
                incoming_webhook=incoming_webhook,
                webhook_url=webhook_url,
                webhook_token=webhook_token,
            )
        except BaseException as err:
            logger.error("#GreenApiConnector.set_instance_settings request error: %s", str(err), extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    instance = self.client.set_instance_settings(instance_id=self.merchant.green_api_instance_id,
                                                                 api_token=self.merchant.green_api_token,
                                                                 outgoing_message_api_webhook=outgoing_message_api_webhook,
                                                                 outgoing_webhook=outgoing_webhook,
                                                                 delay_send_messages_milliseconds=delay_send_messages_milliseconds,
                                                                 incoming_webhook=incoming_webhook,
                                                                 webhook_url=webhook_url,
                                                                 webhook_token=webhook_token)

                    if instance is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenApiConnector.set_instance_settings request retry error: %s",
                                 str(err), extra=extra_data)
        if instance is None or instance.save_settings is False:
            logger.error("#GreenApiConnector.set_instance_settings response failed.", extra=extra_data)
            return None

        logger.info("#GreenApiConnector.set_instance_settings response successful.", extra=extra_data)

        return instance

    def generate_qr_code(self):

        extra_data = {
            'instance_id': self.merchant.green_api_instance_id,
            'api_token': self.merchant.green_api_token,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'merchant_cabinet_id': self.merchant.kaspi_shop_uid
        }

        qr_code_object = None

        try:
            qr_code_object = self.client.generate_qr_code(instance_id=self.merchant.green_api_instance_id,
                                                          api_token=self.merchant.green_api_token)
        except BaseException as err:
            logger.error("#GreenAPIConnector.generate_qr_code request error: %s", str(err), extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    qr_code_object = self.client.generate_qr_code(instance_id=self.merchant.green_api_instance_id,
                                                                  api_token=self.merchant.green_api_token)
                    if qr_code_object is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenAPIConnector.generate_qr_code request retry error: %s", err, extra=extra_data)

        if qr_code_object is None:
            logger.error("#GreenAPIConnector.generate_qr_code response failed.", extra=extra_data)
            return None

        logger.info("#GreenAPIConnector.generate_qr_code response successful. QR_code_type: %s",
                    qr_code_object.type, extra=extra_data)

        return qr_code_object

    def get_authorization_code(self, phone_number: int = None):
        extra_data = {
            'instance_id': self.merchant.green_api_instance_id,
            'api_token': self.merchant.green_api_token,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'merchant_cabinet_id': self.merchant.kaspi_shop_uid,
            'phone_number': phone_number,
        }

        authorization_code_object = None

        try:
            authorization_code_object = self.client.get_authorization_code(
                instance_id=self.merchant.green_api_instance_id,
                api_token=self.merchant.green_api_token,
                phone_number=phone_number)

        except BaseException as err:
            logger.error("#GreenAPIConnector.authorization_code request error: %s", str(err), extra=extra_data)

            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    authorization_code_object = self.client.get_authorization_code(
                        instance_id=self.merchant.green_api_instance_id,
                        api_token=self.merchant.green_api_token,
                        phone_number=phone_number)
                    if authorization_code_object is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenAPIConnector.authorization_code request retry error: %s", err, extra=extra_data)

        if authorization_code_object is None:
            logger.error("#GreenAPIConnector.authorization_code response failed.", extra=extra_data)
            return None

        logger.info("#GreenAPIConnector.authorization_code response successful. Authorization_code_status: %s",
                    authorization_code_object.status, extra=extra_data)

        return authorization_code_object

    def logout(self):
        extra_data = {
            'instance_id': self.merchant.green_api_instance_id,
            'api_token': self.merchant.green_api_token,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'merchant_cabinet_id': self.merchant.kaspi_shop_uid
        }

        logout_object = None

        try:
            logout_object = self.client.logout(instance_id=self.merchant.green_api_instance_id,
                                               api_token=self.merchant.green_api_token)
        except BaseException as err:
            logger.error("#GreenAPIConnector.logout request error: %s", err, extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    logout_object = self.client.logout(instance_id=self.merchant.green_api_instance_id,
                                                       api_token=self.merchant.green_api_token)
                    if logout_object is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenAPIConnector.logout request retry error: %s", str(err), extra=extra_data)

        if logout_object is None:
            logger.error("#GreenAPIConnector.logout response failed.", extra=extra_data)
            return None

        logger.info("#GreenAPIConnector.logout response successful. Logout_status: %s",
                    logout_object.is_logout, extra=extra_data)

        return logout_object

    def new_order_notify(self, new_order: KaspiNewOrder, uid: str):
        products = list(new_order.products.using('default').values_list('id', 'name', 'quantity', 'product_mastercode'))
        extra = {
            'uid': uid,
            'kaspi_order_code': new_order.kaspi_order_code,
            'phone_number': new_order.phone_number,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'products': [product[0] for product in products]
        }

        logger.info('#api.service.green_api_connector.new_order_notify started', extra=extra)
        message = self.construct_message(
            order=new_order,
            products=products,
            message_type=GreenApiConnector.NEW_ORDER_MESSAGE_TYPE)
        result = self.send_message(chat_id=new_order.phone_number, text=message)
        logger.info('#api.service.green_api_connector.new_order_notify completed', extra=extra)
        return result

    def order_review_notify(self, order: KaspiNewOrder):
        products = list(order.products.using('default').values_list('id', 'name', 'quantity', 'product_mastercode'))

        extra = {
            'order_code': order.kaspi_order_code,
            'phone_number': order.phone_number,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk,
            'products': list(order.products.values_list('id', 'name'))
        }

        logger.info('#api.service.green_api_connector.order_review_notify started', extra=extra)
        message = self.construct_message(order=order,
                                         products=products,
                                         message_type=GreenApiConnector.REVIEW_MESSAGE_TYPE)
        result = self.send_message(chat_id=order.phone_number, text=message)
        logger.info('#api.service.green_api_connector.order_review_notify completed', extra=extra)
        return result

    def send_notification_to_merchant_about_instance_status(self, merchant: Merchant):
        extra = {
            'merchant': merchant.name,
            'merchant_pk': merchant.pk,
            'instance_id': merchant.green_api_instance_id
        }
        logger.info('#api.service.green_api_connector.send_notification_to_merchant_about_instance_status started', extra=extra)
        message = self.construct_message_for_merchant(merchant=merchant,
                                                      message_type=self.INSTANCE_STATUS_MESSAGE_TYPE)

        chat_id = prettify_phone_number(merchant.contact_number)

        result = self.send_message(
            chat_id=chat_id,
            text=message
        )
        logger.info('#api.service.green_api_connector.send_notification_to_merchant_about_instance_status completed', extra=extra)
        return result

    def send_notification_about_postomat_order(self, order: KaspiNewOrder):
        extra = {
            'order_code': order.kaspi_order_code,
            'phone_number': order.phone_number,
            'merchant': self.merchant.name,
            'merchant_pk': self.merchant.pk
        }

        logger.info('#api.service.green_api_connector.send_notification_about_postomat_order started', extra=extra)
        message = self.construct_message_for_postomat_delivery(order)
        chat_id = prettify_phone_number(order.phone_number)

        result = self.send_message(
            chat_id=chat_id,
            text=message
        )
        logger.info('#api.service.green_api_connector.send_notification_about_postomat_order completed', extra=extra)
        return result

    def get_instance_status(self, merchant):
        """
            Retrieve current instance status.
        """
        extra_data = {
            'instance_id': merchant.green_api_instance_id,
            'api_token': merchant.green_api_token,
            'merchant': merchant.name,
        }
        instance_status = None
        try:
            instance_status = self.client.get_instance_status(
                instance_id=merchant.green_api_instance_id,
                api_token=merchant.green_api_token,
            )
        except BaseException as err:
            logger.error("#GreenApiConnector.get_instance_status request error: %s", str(err), extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(GreenApiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    instance_status = self.client.get_instance_status(
                        instance_id=merchant.green_api_instance_id,
                        api_token=merchant.green_api_token,
                    )
                    if instance_status is not None:
                        break
                except BaseException as err:
                    logger.error("#GreenApiConnector.get_instance_status request retry error: %s",
                                 str(err), extra=extra_data)
        if instance_status is None:
            logger.error("#GreenApiConnector.get_instance_status response failed, instance status is None",
                         extra=extra_data)
            return None

        logger.info(f"#GreenApiConnector.get_instance_status response successful, instance status :: {instance_status}",
                    extra=extra_data)

        return instance_status


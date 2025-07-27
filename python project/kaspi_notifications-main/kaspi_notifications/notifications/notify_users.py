import logging
import notifications.kaspi_api.api_requests as kaspi_api
from django.conf import settings
from datetime import datetime

from notifications import constants
from notifications.green_api import send_message_through_green_api
from notifications.models import KaspiNewOrder, OrderProduct, Merchant
from notifications.order_storage import Orders
from notifications.tasks_for_second_message_delay import send_message_for_second_message
from notifications.utils import greeting
from notifications.whatsapp_functions import send_template_message_about_new_order_without_buttons, \
    send_template_message_about_new_order, send_template_message_for_reviews
from kaspi_notifications.additional_tasks import save_notification_status

from pktools.helpers import time_it_and_log

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@time_it_and_log
def notify_about_new_order(order_id: int, planned_delivery_date: str, client_name: str, is_resend: bool) -> None:
    extra = {
        'order_code': order_id,
        'client': client_name,
        'planned_delivery_date': planned_delivery_date,
        'is_resend': is_resend
    }
    logger.info(f'notify_about_new_order:: started', extra=extra)
    kaspi_new_order: KaspiNewOrder = KaspiNewOrder.objects.filter(kaspi_order_code=order_id).first()

    message_id = {}

    if kaspi_new_order is None:
        logger.info(f'notify_about_new_order:: order is not found', extra=extra)
        return

    if not is_resend:
        if kaspi_new_order.first_message_sending_time is not None:
            logger.info(f'notify_about_new_order:: order is already notified '
                        f'at {kaspi_new_order.first_message_sending_time.strftime("%d.%m.%Y %H:%M:%S")}', extra=extra)
            return

    merchant = kaspi_new_order.merchant
    phone_number = kaspi_new_order.phone_number
    product_names = [f'{product.name}, количество: {product.quantity} шт.' for product in
                     kaspi_new_order.products.all()]
    extra.update(
        {
            'merchant_name': merchant.name,
            'product_names': product_names.__str__(),
        }
    )
    logger.info('#notifications.notify_users.notify_about_new_order generating message', extra=extra)

    # if not merchant.is_template_rus():
    #     product_names = [f'{product.name}, {product.quantity} дана.' for product in kaspi_new_order.products.all()]
    if merchant.is_whatsapp_communication():
        logger.info('#notifications.notify_users.notify_about_new_order generating whatsapp business', extra=extra)
        if planned_delivery_date == 'Самовывоз' or planned_delivery_date == 'Postamat':
            whatsapp_template = merchant.message_template_name_ask_for_self_call
        else:
            whatsapp_template = merchant.message_template_name_new_order
        if merchant.is_template_without_buttons():
            delivery_status = send_template_message_about_new_order_without_buttons(phone_number,
                                                                                    client_name,
                                                                                    ', '.join(product_names),
                                                                                    kaspi_new_order.kaspi_order_code,
                                                                                    planned_delivery_date,
                                                                                    merchant.whatsapp_id,
                                                                                    merchant.whatsapp_token,
                                                                                    whatsapp_template)

        else:
            delivery_status = send_template_message_about_new_order(phone_number, client_name,
                                                                    ', '.join(product_names),
                                                                    kaspi_new_order.kaspi_order_code,
                                                                    'want_to_order_',
                                                                    'not_want_to_order_',
                                                                    kaspi_new_order.kaspi_order_id,
                                                                    planned_delivery_date,
                                                                    merchant.whatsapp_id,
                                                                    merchant.whatsapp_token,
                                                                    whatsapp_template)

        kaspi_new_order.first_message_delivery_status = delivery_status
        kaspi_new_order.first_message_sending_time = datetime.now()
        merchant.update_message_count()
        kaspi_new_order.save()

        logger.info(f'notify_about_new_order:: completed', extra={'merchant': merchant.name,
                                                                  'order': order_id,
                                                                  'communication_type': merchant.communication_type,
                                                                  'delivery_status': kaspi_new_order.first_message_delivery_status,

                                                                  'planned_delivery_date': planned_delivery_date})


@time_it_and_log
def notify_about_order_review(order_code: str) -> None:
    logger.info(f'notify_about_order_review:: started', extra={'order': order_code})
    order_storage = Orders()
    try:
        order = KaspiNewOrder.objects.filter(kaspi_order_code=order_code).first()
        extra = {'merchant': order.merchant.name, 'order': order.kaspi_order_id, 'client_number': order.phone_number,
                 'communication_type': order.merchant.communication_type}
        if not order.merchant.send_second_message:
            order_storage.change_new_order_notification_status(constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT,
                                                               order.kaspi_order_id)
            order_storage.change_order_review_delivery_status('второе сообщение отключено', order.kaspi_order_id)
            logger.info('notify_about_order_review:: sending second message func is not activated, skipping',
                        extra=extra)
            return

        if order.notification_status != constants.STATUS_CLIENT_TO_BE_NOTIFIED:
            logger.info(f'notify_about_order_review:: status is not {constants.STATUS_CLIENT_TO_BE_NOTIFIED}, skipping',
                        extra=extra)
            return

        order_status_in_kaspi = kaspi_api.get_order_by_code(order.kaspi_order_code, order.merchant.kaspi_token,
                                                            order.merchant.kaspi_shop_uid)

        if order_status_in_kaspi == 'not_need_message':
            logger.info(f'notify_about_order_review:: not_need_message', extra=extra)
            order.notification_status = "client_must_not_be_notified"
            order.second_message_delivery_status = "ошибка каспи апи"
            order.save()
            return
        if order_status_in_kaspi == 'ERROR':
            logger.error(f'notify_about_order_review:: error retrieving data from Kaspi 2: {order.kaspi_order_code}',
                         extra=extra)
            return
        if order_status_in_kaspi == 'CANCELLED':
            logger.info(f'notify_about_order_review:: order status in Kaspi is CANCELLED, skipping',
                        extra=extra)
            order.api_order_status = 'CANCELLED'
            order.notification_status = constants.STATUS_CLIENT_NOT_TO_BE_NOTIFIED
            order.save()
        elif order_status_in_kaspi != 'COMPLETED':
            logger.info(
                f'notify_about_order_review:: order status in Kaspi is not COMPLETED, status = {order_status_in_kaspi}',
                extra=extra)
        else:
            order.api_order_status = 'COMPLETED'
            order.save()
            products = OrderProduct.objects.filter(order=order)

            extra.update(
                { 'products_id': products.values_list('id', flat=True) }
            )

            logger.info("Notify_about_order_review.Gathering products link of order is started",
                        extra=extra)

            product_links = [
                f'https://kaspi.kz/shop/review/productreview?orderCode={order.kaspi_order_code}&productCode={product.product_mastercode}&rating=5'
                for product in products]

            if order.merchant.is_whatsapp_communication():
                message_status = send_template_message_for_reviews(order.phone_number, order.full_name.split(' ')[1],
                                                                   ", ".join(product_links),
                                                                   order.merchant.whatsapp_id,
                                                                   order.merchant.whatsapp_token,
                                                                   order.merchant.message_template_name_ask_for_comment)
                order_storage.change_order_review_delivery_status(message_status, order.kaspi_order_id)
                order_storage.change_new_order_notification_status(constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT,
                                                                   order.kaspi_order_id)
                order.merchant.update_message_count()
            else:
                phone_number = order.phone_number
                phone_number = '7' + phone_number

                if order.merchant.green_api_review_with_confirm:
                    if order.merchant.is_template_rus():
                        message = (f'{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой!\n\n'
                                   f'Всё ли вам понравилось? \n1 - Да, всё хорошо. \n2 - Нет, мне не понравилось\n'
                                   f'Пожалуйста, присылайте только цифр (1 или 2).')
                    else:
                        message = (
                            f'{greeting(False)}, {order.full_name.split(" ")[1]}!\nСатып алуыңызбен құттықтаймыз!\n\n'
                            f'Сізге барлығы ұнады ма? \n1 - Иә, барлығы жақсы. \n2 - Жоқ, маған ұнамады.\n'
                            f'Өтініш, тек 1 немесе 2 санын жіберіңіз. \n\n🔸🔸🔸\n\n'
                            f'{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой!\n\n'
                            f'Всё ли вам понравилось? \n1 - Да, всё хорошо. \n2 - Нет, мне не понравилось.\n'
                            f'Пожалуйста, присылайте только цифр (1 или 2).')

                    send_message_through_green_api(phone_number, message, order.merchant.green_api_instance_id,
                                                   order.merchant.green_api_token)
                    order_storage.change_new_order_notification_status(constants.STATUS_CLIENT_NEED_ANSWER,
                                                                       order.kaspi_order_id)

                else:
                    if order.merchant.green_api_message_text_for_review:
                        template = order.merchant.green_api_message_text_for_review
                        try:
                            format_dict = {
                                "client_name": order.full_name.split(" ")[1],
                                "link": ", ".join(product_links)
                            }

                            if "{hello_rus}" in template:
                                format_dict["hello_rus"] = greeting(True)
                            if "{hello_kaz}" in template:
                                format_dict["hello_kaz"] = greeting(False)

                            message = template.format(**format_dict)
                            message = message.replace("\\n", "\n")
                        except KeyError as e:
                            message = f'{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой с магазина {order.merchant.name}!\n' \
                                      f'Мы надеемся, что вам все понравилось.\nЕсли вам не сложно, пожалуйста оставьте отзыв *с указанием названия нашего магазина* перейдя по ссылке⤵️:\n' \
                                      f'{", ".join(product_links)}\n' \
                                      f'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.'
                            logger.error(
                                f'notify_about_order_review:: error formatting message, error is {e}',
                                extra=extra)

                    elif order.merchant.is_template_rus():
                        message = f'{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой с магазина {order.merchant.name}!\n' \
                                  f'Мы надеемся, что вам все понравилось.\nЕсли вам не сложно, пожалуйста оставьте отзыв *с указанием названия нашего магазина* перейдя по ссылке⤵️:\n' \
                                  f'{", ".join(product_links)}\n' \
                                  f'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.'
                    else:
                        message = f'{greeting(False)}, {order.full_name.split(" ")[1]}!\n{order.merchant.name} дүкенінен сатып алуыңызбен құттықтаймыз!\n' \
                                  f'Сізге бәрі ұнады деп үміттенеміз.\nСілтеме арқылы өтіп, *біздің дүкеннің атауын* көрсете отырып, пікір қалдыра аласыз ба, бұл біз үшін маңызды⤵️:\n' \
                                  f'{", ".join(product_links)}\nСілтеме белсенді болуы үшін жауап ретінде бірдеңе жазыңыз.' \
                                  f'\n\n🔸🔸🔸\n\n{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой с магазина {order.merchant.name}!\n' \
                                  f'Мы надеемся, что вам все понравилось.\nЕсли вам не сложно, пожалуйста оставьте отзыв *с указанием названия нашего магазина* перейдя по ссылке⤵️:\n' \
                                  f'{", ".join(product_links)}\n' \
                                  f'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.'

                    if order.merchant.second_message_delay != 0:
                        send_message_for_second_message.apply_async(
                            args=[phone_number, message, order.merchant.green_api_instance_id,
                                  order.merchant.green_api_token, order.kaspi_order_code],
                            countdown=order.merchant.second_message_delay * 60)
                        order_storage.change_new_order_notification_status(constants.STATUS_CLIENT_WITH_DELAY,
                                                                           order.kaspi_order_id)

                    else:
                        message_id = send_message_through_green_api(phone_number, message,
                                                                    order.merchant.green_api_instance_id,
                                                                    order.merchant.green_api_token)
                        if message_id == 'null':
                            order.second_message_delivery_status = "ошибка грин апи"
                            order.save()
                            logger.info(
                                f'notify_about_order_review:: Green API message id is null',
                                extra=extra)

                        else:
                            save_notification_status.apply_async(args=(
                                phone_number, message_id['idMessage'], order.merchant.green_api_instance_id,
                                order.merchant.green_api_token, order_code, False),
                                countdown=1 * 60)

                        order_storage.change_new_order_notification_status(
                            constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT, order.kaspi_order_id)
                    order.merchant.update_message_count()

            logger.info(
                f'notify_about_order_review:: order status is COMPLETED, client is notified',
                extra=extra)
    except BaseException as e:
        logger.error(
            f'notify_about_order_review:: client was not notified, error is {e}',
            extra={'order': order_code})

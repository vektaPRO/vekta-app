import os
from datetime import datetime

import requests
from celery import shared_task
from django.utils.timezone import now
from dotenv import load_dotenv

from kaspi_notifications.additional_tasks import save_notification_status
from notifications import constants
from notifications.green_api import send_message_through_green_api
from notifications.kaspi_api.api_requests import get_headers_with_uid, get_headers
from notifications.models import KaspiNewOrder, OrderProduct, ResendMessage, Merchant
from notifications.notify_users import notify_about_order_review, notify_about_new_order
from notifications.order_storage import Orders
from notifications.utils import log, convert_datetime_from_milliseconds, greeting, set_settings_green_api_util

load_dotenv()

@shared_task
def get_kaspi_new_orders(merchant_id, order_date_str, first_message_delivery_status, resendmessage_id):
    log(f'resend Message to notify about new order started')
    ResendMessage.objects.filter(id=resendmessage_id).update(status=constants.IN_PROGRESS)

    # Convert the order_date_str to a date object
    order_date = datetime.strptime(order_date_str, "%d.%m.%Y").date()
    current_date = now().date()  # get the current date

    if first_message_delivery_status == 'None':
        first_message_delivery_status = None
    # Query the KaspiNewOrder model
    orders = KaspiNewOrder.objects.filter(
        merchant_id=merchant_id,
        order_date__gte=order_date,
        order_date__lte=current_date,
        first_message_delivery_status=first_message_delivery_status
    )

    if len(orders) == 0:
        log(f'len is null')
        ResendMessage.objects.filter(id=resendmessage_id).update(status=constants.IS_NULL_OR_0)
        return

    for order in orders:
        try:
            kaspi_response = get_order_by_code_for_hand_do(order.kaspi_order_code,
                                                           order.merchant.kaspi_token,
                                                           order.merchant.kaspi_shop_uid)
            if kaspi_response == 'ERROR':
                pass

            if kaspi_response['attributes']['status'] == 'ACCEPTED_BY_MERCHANT':
                if 'plannedDeliveryDate' in kaspi_response['attributes']:
                    planned_delivery_date = convert_datetime_from_milliseconds(
                        kaspi_response['attributes']['plannedDeliveryDate']).strftime('%d.%m.%Y')
                else:
                    planned_delivery_date = 'Самовывоз'
                notify_about_new_order(order.kaspi_order_code, planned_delivery_date,
                                       kaspi_response['attributes']['customer']['firstName'], True)
                log(f'client notified new order, order_code: {order.kaspi_order_code}')
            elif kaspi_response['attributes']['status'] == 'COMPLETED':
                notify_about_order_review(order.kaspi_order_code)
                log(f'client notified order review, order_code: {order.kaspi_order_code}')
            else:
                continue
        except BaseException as e:
            ResendMessage.objects.filter(id=resendmessage_id).update(status=constants.IS_ERROR)
            log(f'error on resending message function get_kaspi_new_orders, error: {e}')
            continue

    ResendMessage.objects.filter(id=resendmessage_id).update(status=constants.DONE)


def get_kaspi_new_orders_by_hand(merchant_id, order_date_str, first_message_delivery_status):
    log(f'resend Message to notify about new order started')

    # Convert the order_date_str to a date object
    order_date = datetime.strptime(order_date_str, "%d.%m.%Y").date()
    current_date = now().date()  # get the current date

    # Query the KaspiNewOrder model
    orders = KaspiNewOrder.objects.filter(
        merchant_id=merchant_id,
        order_date__gte=order_date,
        order_date__lte=current_date,
        first_message_delivery_status=first_message_delivery_status
    )

    if len(orders) == 0:
        return

    for order in orders:
        try:
            kaspi_response = get_order_by_code_for_hand_do(order.kaspi_order_code,
                                                           order.merchant.kaspi_token,
                                                           order.merchant.kaspi_shop_uid)
            if kaspi_response == 'ERROR':
                pass

            if kaspi_response['attributes']['status'] == 'ACCEPTED_BY_MERCHANT':
                planned_delivery_data = convert_datetime_from_milliseconds(
                    kaspi_response['attributes']['plannedDeliveryDate']).strftime('%d.%m.%Y')
                notify_about_new_order(order.kaspi_order_code, planned_delivery_data,
                                       kaspi_response['attributes']['customer']['firstName'], True)
                log(f'client notified new order, order_code: {order.kaspi_order_code}')
            elif kaspi_response['attributes']['status'] == 'COMPLETED':
                notify_about_order_review(order.kaspi_order_code)
                log(f'client notified order review, order_code: {order.kaspi_order_code}')
            else:
                continue
        except BaseException as e:
            log(f'error on resending message function get_kaspi_new_orders, error: {e}')
            continue


def resend_second(order_code):
    order = KaspiNewOrder.objects.filter(kaspi_order_code=order_code).first()
    order_storage = Orders()
    phone_number = '7' + order.phone_number

    products = OrderProduct.objects.filter(order=order).all()
    print(products)
    product_links = [
        f'https://kaspi.kz/shop/review/productreview?orderCode={order.kaspi_order_code}&productCode={product.product_mastercode}&rating=5'
        for product in products]
    print(product_links)

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
            log(f"Error formatting message: order code 3 = {order.kaspi_order_code}, error = {e}")
    elif order.merchant.is_template_rus():
        message = f'{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой с магазина {order.merchant.name}!\n' \
                  f'Мы надеемся, что вам все понравилось.\nМожете оставить отзыв здесь *с указанием названия нашего магазина*, для нас это важно:\n' \
                  f'{", ".join(product_links)}\n' \
                  f'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.'
    else:
        message = f'{greeting(False)}, {order.full_name.split(" ")[1]}!\n{order.merchant.name} дүкенінен сатып алуыңызбен құттықтаймыз!\n' \
                  f'Сізге бәрі ұнады деп үміттенеміз.\nМұнда *біздің дүкеннің атауын* көрсете отырып пікір қалдыра аласыз ба, бұл біз үшін маңызды:\n' \
                  f'{", ".join(product_links)}\nСілтеме белсенді болуы үшін жауап ретінде бірдеңе жазыңыз.' \
                  f'\n\n***\n\n{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой с магазина {order.merchant.name}!\n' \
                  f'Мы надеемся, что вам все понравилось.\nМожете оставить отзыв здесь *с указанием названия нашего магазина*, для нас это важно:\n' \
                  f'{", ".join(product_links)}\n' \
                  f'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.'

    message_id = send_message_through_green_api(phone_number, message, order.merchant.green_api_instance_id,
                                                order.merchant.green_api_token)
    if message_id == 'null':
        order.second_message_delivery_status = 'ошибка грин апи'
        order.save()
    else:
        save_notification_status.apply_async(args=[
            phone_number, message_id['idMessage'], order.merchant.green_api_instance_id,
            order.merchant.green_api_token, order.kaspi_order_code, False],
            countdown=2*60)
        order_storage.change_new_order_notification_status(constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT,
                                                           order.kaspi_order_id)
    order.merchant.update_message_count()


def all_resend_second():
    order_storage = Orders()
    orders = order_storage.select_new_orders_for_resend_second()
    log(f'all_resend_second start, len = {len(orders)}')
    for order in orders:
        try:
            resend_second(order.kaspi_order_code)
        except BaseException as e:
            log(f'error on resending message function all_resend_second, error: {e}')


def get_order_by_code_for_hand_do(order_code, kaspi_token, kaspi_shop_uid):
    url = 'https://kaspi.kz/shop/api/v2/orders'
    data = {'filter[orders][code]': order_code}
    headers = get_headers_with_uid(kaspi_token, kaspi_shop_uid) if kaspi_shop_uid else get_headers(kaspi_token)
    response = requests.get(url=url, params=data, headers=headers)
    log(f'KASPI API: get information about order {order_code}, status code: {response.status_code}\n')

    if response.status_code == 200:
        order_status = response.json()['data'][0]
        return order_status
    else:
        return 'ERROR'

def set_all_webhook():
    merchants = Merchant.objects.filter(green_api_review_with_confirm = True)
    print(f'lenght = {len(merchants)}')

    for merchant in merchants:
        print(f'merchant = {merchant.name}')
        url = f"https://sharex.sky-ddns.kz/webhook/{str(merchant.uid)}/"
        merchant.webhook_url = url
        merchant.save()
        set_settings_green_api_util(merchant.green_api_instance_id, merchant.green_api_token, url, os.getenv('GREEN_API_TOKEN'))


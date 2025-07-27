import logging
from datetime import datetime, timedelta, time
from dotenv import load_dotenv
from django.conf import settings

import notifications.kaspi_api.api_requests as kaspi_api
from pktools.helpers import time_it_and_log
from .models import Merchant, OrderProduct

from .order_storage import Orders
from . import constants
from .utils import convert_datetime_to_milliseconds, convert_datetime_from_milliseconds

load_dotenv()

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@time_it_and_log
def gather_new_orders_to_notify_user(date_start, date_end, merchant: Merchant, notification_scheduler: callable):
    metrics_logs_prefix = 'metrics::gather_new_orders_to_notify_user'
    logger.info(f'{metrics_logs_prefix}::get_orders_general_info::started',
                extra={'merchant': merchant.name})
    page_size = 100
    orders_from_date = convert_datetime_to_milliseconds(date_start - timedelta(days=1))
    orders_to_date = convert_datetime_to_milliseconds(date_end + timedelta(days=2))
    orders_statuses_to_filter = ['APPROVED_BY_BANK', 'ACCEPTED_BY_MERCHANT']
    orders_states_to_fetch = ['NEW', 'KASPI_DELIVERY', 'DELIVERY', 'PICKUP', 'SIGN_REQUIRED']
    orders_total = []
    started_at = datetime.now()
    num_orders = 0
    for order_state in orders_states_to_fetch:
        orders_with_state = kaspi_api.get_orders_general_info(page_size, order_state, orders_statuses_to_filter,
                                                              orders_from_date,
                                                              orders_to_date,
                                                              merchant.kaspi_token, merchant.kaspi_shop_uid)
        orders_total.extend(orders_with_state)
    duration = int((datetime.now() - started_at).total_seconds())
    logger.info(f'{metrics_logs_prefix}::get_orders_general_info::completed',
                extra={'merchant': merchant.name, 'duration': duration})

    order_storage = Orders()
    for order in orders_total:
        logger.info(f'{metrics_logs_prefix}::Processing new order::started', extra={'merchant': merchant.name,
                                                                                    'order': order["attributes"]["code"]})
        try:
            creation_date = convert_datetime_from_milliseconds(order['attributes']['creationDate']).date()
            today = datetime.today().date()
            yesterday = today - timedelta(days=1)
            extra = {'creation_date': creation_date,
                     'merchant': merchant.name,
                     'order': order["attributes"]["code"],
                     'order_state': order["attributes"]["state"]}

            if creation_date not in (today, yesterday):
                logger.info(f'{metrics_logs_prefix}::Skipping cause creation date is not today or yesterday', extra=extra)
                continue
            else:
                if not order_storage.get_new_order_by_id(order['id']):
                    started_at = datetime.now()
                    phone_number = order['attributes']['customer']['cellPhone']
                    client_name = order['attributes']['customer']['firstName']
                    client_surname = order['attributes']['customer']['lastName']
                    full_name = f'{client_surname} {client_name}'

                    if 'plannedDeliveryDate' in order['attributes']:
                        planned_delivery_date = convert_datetime_from_milliseconds(
                            order['attributes']['plannedDeliveryDate']).strftime('%d.%m.%Y')
                    else:
                        if (order['attributes']['deliveryMode'] == 'DELIVERY_PICKUP'
                                and order['attributes']['isKaspiDelivery'] is True):
                            planned_delivery_date = 'Postamat'
                        else:
                            planned_delivery_date = 'Самовывоз'
                    order_content = kaspi_api.get_order_content(order['id'], merchant.kaspi_token, merchant.kaspi_shop_uid)
                    if order_content == 'null':
                        logger.info(f'{metrics_logs_prefix}::Order content is null', extra=extra)
                        continue
                    else:
                        logger.info(f'{metrics_logs_prefix}::Notifying user about new order',
                                    extra=extra)

                        notification_status = constants.STATUS_CLIENT_TO_BE_NOTIFIED

                        kaspi_new_order = order_storage.save_new_order_details(order['attributes']['code'], order['id'],
                                                                               creation_date,
                                                                               phone_number, notification_status,
                                                                               full_name,
                                                                               merchant, order["attributes"]["status"],
                                                                               order["attributes"]["state"],
                                                                               planned_delivery_date,
                                                                               merchant.send_first_message)

                        if kaspi_new_order.merchant.send_messages_by_status:
                            logger.info(f'{metrics_logs_prefix}::Message by status started', extra=extra)
                            if (order['attributes']['deliveryMode'] == 'DELIVERY_PICKUP'
                                    and order['attributes']['isKaspiDelivery'] is True):
                                kaspi_new_order.is_delivery_to_postamat = True
                                kaspi_new_order.save()
                                logger.info(f'{metrics_logs_prefix}::Message by status completed', extra=extra)

                        for product in order_content:
                            order_entries_id = product['id']
                            product_info = kaspi_api.get_order_products_info(order_entries_id, merchant.kaspi_token, merchant.kaspi_shop_uid)
                            if product_info == 'null':
                                logger.info(f'{metrics_logs_prefix}::No products info in order', extra=extra)
                                continue
                            else:
                                product_name = product_info['attributes']['name']
                                product_master_code = product_info['attributes']['code']
                                OrderProduct.objects.create(order=kaspi_new_order, name=product_name,
                                                            product_code=product['attributes']['offer']['code'],
                                                            product_mastercode=product_master_code,
                                                            category=product['attributes']['category']['title'],
                                                            quantity=product['attributes']['quantity'],
                                                            price=product['attributes']['basePrice'])
                                logger.info(f'{metrics_logs_prefix}::Products info was saved to db', extra=extra)

                    if merchant.is_auto_accepting_orders() and order["attributes"]["status"] == "APPROVED_BY_BANK":
                        try:
                            logger.info(f'{metrics_logs_prefix}::Trying to confirm order', extra=extra)
                            response_status_code = kaspi_api.confirm_new_order(kaspi_new_order.kaspi_order_id,
                                                                               kaspi_new_order.kaspi_order_code,
                                                                               merchant.kaspi_token)
                            if response_status_code != 400:
                                kaspi_new_order.auto_accepted = True
                                kaspi_new_order.order_status = constants.STATUS_ORDER_WAS_AUTO_ACCEPTED_IN_KASPI
                                kaspi_new_order.save()
                                logger.info(f'{metrics_logs_prefix}::Order was auto confirmed,'
                                            f' response = {response_status_code}', extra=extra)
                            else:
                                kaspi_new_order.auto_accepted = False
                                kaspi_new_order.order_status = constants.STATUS_ORDER_WAS_NOT_AUTO_ACCEPTED_IN_KASPI
                                kaspi_new_order.save()
                                logger.info(f'{metrics_logs_prefix}::Order was not auto confirmed,'
                                            f' response = {response_status_code}', extra=extra)
                        except BaseException as e:
                            logger.error(f'{metrics_logs_prefix}::Order was not auto confirmed,'
                                         f' error = {e}', extra=extra)

                    logger.info(f'{metrics_logs_prefix}::Scheduling sending message', extra=extra)
                    if kaspi_new_order.api_order_state == 'SIGN_REQUIRED':
                        logger.info(f'{metrics_logs_prefix}::Need to sign document', extra=extra)
                        kaspi_new_order.first_message_delivery_status = 'нужно подписать документы'
                        kaspi_new_order.first_message_sending_time = datetime.now()
                        kaspi_new_order.notification_status = constants.STATUS_CLIENT_NOT_TO_BE_NOTIFIED
                        kaspi_new_order.save()
                    else:
                        notification_scheduler.delay(kaspi_new_order.kaspi_order_code, planned_delivery_date, client_name)
                        logger.info(f'{metrics_logs_prefix}::Sending message was scheduled', extra=extra)
                    duration = int((datetime.now() - started_at).total_seconds())
                    logger.info(f'{metrics_logs_prefix}::Processing new order::completed::duration_seconds={duration}',
                                extra=extra)
                    num_orders += 1
        except BaseException as e:
            logger.error(f'{metrics_logs_prefix}::error occurred while processing new order',
                         extra={'merchant': merchant,
                                'order': order['attributes']['code'],
                                'error': e})
    return num_orders


@time_it_and_log
def parse_merchant_new_orders(merchant, notification_scheduler: callable):
    logger.info('parse_merchant_new_orders started')
    midnight = datetime.combine(datetime.today(), time.min)
    yesterday_start = midnight - timedelta(days=1)
    yesterday_end = yesterday_start + timedelta(hours=23, minutes=59, seconds=59)
    num_merchant_orders = gather_new_orders_to_notify_user(yesterday_start, yesterday_end, merchant,
                                                           notification_scheduler)
    logger.info('parse_merchant_new_orders completed',
                extra={'merchant': merchant.name,
                       'num_of_orders': num_merchant_orders})
    return num_merchant_orders


@time_it_and_log
def schedule_merchants_new_orders_parsing(merchant_parse_new_orders_scheduler: callable, track_id: str):
    logger.info('schedule_merchants_new_orders_parsing started')
    merchants = Merchant.objects.filter(enabled=True).all()
    for merchant in merchants:
        merchant_parse_new_orders_scheduler.delay(merchant.id, track_id)
    num_merchants = len(merchants)
    logger.info('schedule_merchants_new_orders_parsing completed', extra={'num_of_merchants': num_merchants})

    return num_merchants


@time_it_and_log
# Scheduled task to send message to user who confirmed new orders and ask to leave comment
def schedule_notifications_to_review_order(review_notification_scheduler: callable):
    logger.info('schedule_notifications_to_review_order started')
    order_storage = Orders()
    orders = order_storage.select_new_orders_to_ask_for_comment()
    num_orders = 0
    for order in orders:
        extra = {'merchant': order.merchant.name,
                 'order': order.kaspi_order_id}
        try:
            logger.info(f'schedule_notifications_to_review_order:: sending review scheduled', extra=extra)
            review_notification_scheduler.delay(order.kaspi_order_code)
            num_orders += 1
        except BaseException as e:
            logger.error(f'schedule_notifications_to_review_order: sending review was not scheduled, error is {e}',
                         extra=extra)
            pass
    logger.info('schedule_notifications_to_review_order completed', extra={'num_of_orders': num_orders})
    return num_orders


@time_it_and_log
# Scheduled task to auto accept orders in kaspi shop if there is no answer from client within 1 hour - only for WhatsApp
def auto_accept_orders_without_answer_from_clients():
    order_storage = Orders()
    orders = order_storage.select_new_orders_to_be_auto_accepted()
    logger.info('auto_accept_orders_without_answer_from_clients started', extra={'num_of_orders': len(orders)})
    for order in orders:
        extra = {'merchant': order.merchant.name, 'order': order.kaspi_order_id}
        try:
            response_status =kaspi_api.confirm_new_order(order.kaspi_order_id, order.kaspi_order_code, order.merchant.kaspi_token)
            if response_status != 400:
                order.auto_accepted = True
                order.order_status = constants.STATUS_ORDER_WAS_AUTO_ACCEPTED_IN_KASPI
                order.save()
                logger.info(f'auto_accept_orders_without_answer_from_clients::order was auto confirmed',
                            extra=extra)
            else:
                logger.info(f'auto_accept_orders_without_answer_from_clients::order was not auto confirmed :: {response_status}',
                            extra=extra)
        except BaseException as e:
            logger.error(
                f'auto_accept_orders_without_answer_from_clients::order was not auto confirmed :: {e}',
                extra=extra)
            pass

    logger.info('auto_accept_orders_without_answer_from_clients completed')

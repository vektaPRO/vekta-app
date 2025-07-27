import pytz
import logging
from typing import List

from notifications.order_storage import Orders
from .celery import app
from datetime import timedelta, datetime

from asgiref.sync import async_to_sync
from django.conf import settings
from django.utils import timezone

from pktools.helpers import get_uniqid, try_acquire_lock, time_it_and_log
from pktools.string import prettify_phone_number, generate_string
from notifications import constants
from notifications.models import Merchant, KaspiNewOrder, OrderProduct
from api.service.green_api_connector import GreenApiConnector
from api.service.kaspi_connector import KaspiConnector
from api.service.kaspi.structs.base import RESTOrder, RESTOrderEntry, RESTOrderEntriesProduct

from kaspi_notifications.additional_tasks import save_notification_status

from notifications.kaspi_orders_gathering import schedule_notifications_to_review_order, \
    auto_accept_orders_without_answer_from_clients
from notifications.green_api import send_info_about_subscription_expired_to_whatsapp
from notifications.notify_users import notify_about_new_order, notify_about_order_review
from notifications.telegram_bot.main import initiate_green_api_authorization

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


# @app.task
# @time_it_and_log
# def task_parse_merchant_mew_orders(merchant_id: int, track_id: str):
#     merchant = Merchant.objects.filter(pk=merchant_id).first()
#     logger.info(f'[{track_id}]:task_parse_merchant_mew_orders: started', extra={'merchant': merchant, 'track_id': track_id})
#     parse_merchant_new_orders(merchant, send_new_order_notification)
#     logger.info(f'[{track_id}]:task_parse_merchant_mew_orders: completed', extra={'merchant': merchant, 'track_id': track_id})


@app.task
@time_it_and_log
def check_green_api_account_status(merchant_id: int) -> None:
    merchant = Merchant.objects.filter(pk=merchant_id).first()
    logger.info('check_green_api_account_status: started', extra={'merchant': merchant})
    async_to_sync(initiate_green_api_authorization)(merchant)
    logger.info('check_green_api_account_status: completed', extra={'merchant': merchant})


@app.task
@time_it_and_log
def send_new_order_notification(order_id: int, planned_delivery_date, client_name) -> None:
    logger.info('send_new_order_notification: started', extra={'client': client_name, 'order': order_id})
    notify_about_new_order(order_id, planned_delivery_date, client_name, False)
    logger.info('send_new_order_notification: completed', extra={'client': client_name, 'order': order_id})


@app.task
@time_it_and_log
def send_review_notification(oder_id: int) -> None:
    logger.info('send_review_notification: started', extra={'order': oder_id})
    notify_about_order_review(oder_id)
    logger.info('send_review_notification completed', extra={'order': oder_id})


# @app.task
# @time_it_and_log
# def task_schedule_merchants_new_orders_parsing():
#     uniquid = get_uniqid()
#     logger.info(f'[{uniquid}] task_schedule_merchants_new_orders_parsing started')
#
#     if not try_acquire_lock('task_schedule_merchants_new_orders_parsing', 25):
#         logger.info(f'[{uniquid}] task_schedule_merchants_new_orders_parsing cannot acquire lock')
#         return
#
#     num_scheduled_merchants = schedule_merchants_new_orders_parsing(task_parse_merchant_mew_orders, uniquid)
#     logger.info(f'[{uniquid}] task_schedule_merchants_new_orders_parsing completed',
#                 extra={'scheduled_merchants_number': num_scheduled_merchants})


@app.task
@time_it_and_log
def notify_client_to_leave_comment():
    uniquid = get_uniqid()
    logger.info(f'[{uniquid}] task notify_client_to_leave_comment started')
    if not try_acquire_lock('notify_client_to_leave_comment', 20):
        logger.info(f'[{uniquid}] task notify_client_to_leave_comment cannot acquire lock')
        return
    num_scheduled_orders = schedule_notifications_to_review_order(send_review_notification)
    logger.info(f'[{uniquid}] task notify_client_to_leave_comment completed',
                extra={'scheduled_orders_number': num_scheduled_orders})


@app.task
@time_it_and_log
def select_orders_to_be_auto_accepted():
    uniquid = get_uniqid()
    logger.info(f'[{uniquid}] task select_orders_to_be_auto_accepted started')
    if not try_acquire_lock('select_orders_to_be_auto_accepted', 18):
        logger.info(f'[{uniquid}] task select_orders_to_be_auto_accepted cannot acquire lock')
        return

    auto_accept_orders_without_answer_from_clients()
    logger.info(f'[{uniquid}] task select_orders_to_be_auto_accepted completed')


@app.task
@time_it_and_log
def task_for_freeze_subscription():
    logger.info('task_for_freeze_subscription started')
    merchants = Merchant.objects.filter(freeze_tariff=True).all()
    for merchant in merchants:
        merchant.subscription_days += 1
        merchant.save()
    logger.info(f'task_for_freeze_subscription completed', extra={'num_of_merchants': len(merchants)})


# @app.task
# @time_it_and_log
# def task_send_message_about_postamat():
#     logger.info('task task_send_message_about_postamat has started')
#     merchants = Merchant.objects.filter(send_messages_by_status=True).all()
#     for merchant in merchants:
#         notify_about_new_postamat_order(merchant)
#
#     logger.info(f'task_send_message_about_postamat completed', extra={'num_of_merchants': len(merchants)})


@app.task
@time_it_and_log
def subscription_expired_to_whatsapp_task():
    logger.info('task subscription_expired_to_whatsapp_task started')
    send_info_about_subscription_expired_to_whatsapp('7700939485', '9c3a7af9ee3c47cf90551a9a576e69bca3e91732b9f4452e83')
    logger.info(f'task subscription_expired_to_whatsapp_task completed')


@app.task
@time_it_and_log
def force_notify_orders_2_review(orders_id: List[int], uid: str = None):
    uid = uid or generate_string()
    orders = KaspiNewOrder.objects.filter(id__in=orders_id)

    for order in orders:
        process_order_review(order, uid)


@app.task
@time_it_and_log
def process_merchant_new_orders(merchant_id: int, start_date: datetime, end_date: datetime, uid: str):

    merchant = Merchant.objects.only(
        'id', 'name', 'kaspi_shop_uid',
        'green_api_message_text_new_order',
        'green_api_instance_id', 'green_api_token'
    ).get(pk=merchant_id)

    gp = GreenApiConnector(merchant=merchant)
    kp = KaspiConnector(merchant=merchant)
    orders = kp.get_orders(
        start_date=start_date,
        finish_date=end_date,
        uid=uid
    )

    logger.info('#kaspi_notifications.tasks.process_merchant_new_orders overall orders count %s', len(orders),
                extra={
                    'uid': uid,
                    'merchant': merchant.name,
                    'merchant_id': merchant_id,
                    'orders_code': [order.attributes.code for order in orders]
                })

    for order in orders:  # type: RESTOrder
        created_date = order.attributes.creationDate
        extra = {
            'uid': uid,
            'created_date': created_date,
            'merchant': merchant.name,
            'merchant_id': merchant.id,
            'kaspi_order_code': order.attributes.code,   # Мысалы 443173507
        }

        logger.info('#kaspi_notifications.tasks.process_merchant_new_orders', extra=extra)

        if KaspiNewOrder.objects.filter(kaspi_order_id=order.id).exists():
            logger.error('#kaspi_notifications.tasks.process_merchant_new_orders order exist in db', extra=extra)
            continue

        logger.info(
            '#kaspi_notifications.tasks.process_merchant_new_orders orders new order received',
            extra=extra
        )

        order_entries = kp.get_order_entries(order.id, uid=uid)
        if not order_entries or order_entries == 'null':
            logger.error('#kaspi_notifications.tasks.process_merchant_new_orders order content is null', extra=extra)
            continue

        phone_number = order.attributes.customer.cellPhone
        client_name = order.attributes.customer.firstName
        client_last_name = order.attributes.customer.lastName
        full_name = '%s %s' % (client_last_name, client_name)

        if getattr(order.attributes, 'plannedDeliveryDate'):
            planned_delivery_date = order.attributes.plannedDeliveryDate.strftime('%d.%m.%Y')
        elif order.attributes.deliveryMode == 'DELIVERY_PICKUP' and order.attributes.isKaspiDelivery:
            planned_delivery_date = 'Postomat'
        else:
            planned_delivery_date = 'Самовызов'

        notification_status = constants.STATUS_CLIENT_TO_BE_NOTIFIED

        extra.update(
            {
                'phone_number': phone_number,
                'client_name': full_name
            }
        )

        logger.info(
            '#kaspi_notifications.tasks.process_merchant_new_orders orders new order saving to db',
            extra=extra
        )

        if merchant.send_first_message:
            new_order = KaspiNewOrder.objects.create(
                kaspi_order_id=order.id,
                kaspi_order_code=order.attributes.code,
                order_date=created_date.date(),
                phone_number=phone_number,
                notification_status=notification_status,
                full_name=full_name,
                merchant=merchant,
                api_order_status=order.attributes.status,
                api_order_state=order.attributes.state,
                planned_delivery_date=planned_delivery_date,
            )
        else:
            new_order = KaspiNewOrder.objects.create(
                kaspi_order_id=order.id,
                kaspi_order_code=order.attributes.code,
                order_date=created_date.date(),
                phone_number=phone_number,
                full_name=full_name,
                merchant=merchant,
                api_order_status=order.attributes.status,
                api_order_state=order.attributes.state,
                planned_delivery_date=planned_delivery_date,
                first_message_delivery_status='Первое сообщение отключено',
                first_message_sending_time=timezone.now().astimezone(pytz.timezone('asia/almaty'))
            )

        if new_order.merchant.send_messages_by_status:
            if order.attributes.deliveryMode == 'DELIVERY_PICKUP' and order.attributes.isKaspiDelivery:
                new_order.is_delivery_to_postamat = True
        new_order.save()

        for order_entry in order_entries:  # type: RESTOrderEntry
            product: RESTOrderEntriesProduct = kp.get_order_entries_product(entry_id=order_entry.id, uid=uid)
            if not product:
                extra.update(
                    {
                        'kaspi_order_entry_id': order_entry.id,
                    }
                )
                logger.error(
                    '#kaspi_notifications.tasks.process_merchant_new_orders no products info in order',
                    extra=extra
                )
                continue
            order_product = OrderProduct.objects.create(
                order=new_order,
                name=product.name,
                product_code=order_entry.offer.code,
                category=order_entry.category.title,
                product_mastercode=product.master_code,
                quantity=order_entry.quantity,
                price=order_entry.basePrice
            )
            extra.update(
                {
                    'order_product_id': order_product.id
                }
            )
            logger.info(
                '#kaspi_notifications.tasks.process_merchant_new_orders products info was saved to db',
                extra=extra)

        # auto confirm of order
        if merchant.is_auto_accepting_orders() and order.attributes.status == KaspiConnector.ORDER_STATUS_APPROVED_BY_BANK:
            confirmed_order: RESTOrder = kp.confirm_new_order(
                order_id=new_order.kaspi_order_id,
                order_code=new_order.kaspi_order_code,
                uid=uid
            )

            if not confirmed_order:
                new_order.auto_accepted = False
                new_order.order_status = constants.STATUS_ORDER_WAS_NOT_AUTO_ACCEPTED_IN_KASPI
                logger.info("#kaspi_notifications.tasks.process_merchant_new_orders order was not auto confirmed", extra=extra)
            else:
                new_order.auto_accepted = True
                new_order.order_status = constants.STATUS_ORDER_WAS_AUTO_ACCEPTED_IN_KASPI
                logger.info("#kaspi_notifications.tasks.process_merchant_new_orders order was auto confirmed", extra=extra)

        if new_order.api_order_state == KaspiConnector.ORDER_STATE_SIGN_REQUIRED:
            new_order.first_message_delivery_status = 'нужно подписать документы'
            new_order.first_message_sending_time = timezone.now().astimezone(pytz.timezone('asia/almaty'))
            new_order.notification_status = constants.STATUS_CLIENT_NOT_TO_BE_NOTIFIED
            new_order.save()
            logger.info("#kaspi_notifications.tasks.process_merchant_new_orders need to sign document", extra=extra)
            continue

        new_order.save()

        logger.info("#kaspi_notifications.tasks.process_merchant_new_orders sending message started", extra=extra)
        if merchant.is_whatsapp_communication():
            notify_about_new_order(
                order_id=new_order.kaspi_order_code,
                planned_delivery_date=planned_delivery_date,
                client_name=client_name,
                is_resend=False
            )
            continue
        message_resp = gp.new_order_notify(new_order=new_order, uid=uid)

        if message_resp is None:
            new_order.first_message_delivery_status = 'ошибка грин апи'
            new_order.first_message_sending_time = timezone.now().astimezone(pytz.timezone('asia/almaty'))
            new_order.save()
            continue

        merchant.update_message_count()

        logger.info("#kaspi_notifications.tasks.process_merchant_new_orders sending message completed", extra=extra)
        save_notification_status.apply_async(
            args=(
                prettify_phone_number(new_order.phone_number),
                message_resp.id,
                merchant.green_api_instance_id,
                merchant.green_api_token,
                new_order.kaspi_order_code,
                True
            ),
            countdown=3 * 60
        )


@time_it_and_log
def process_order_review(order: KaspiNewOrder, uid: str):
    extra_data = {
        'merchant_pk': order.merchant_id,
        'merchant_name': order.merchant.name,
        'order_code': order.kaspi_order_code,
        'uid': uid
    }

    kp = KaspiConnector(merchant=order.merchant)

    kaspi_order = kp.get_order_by_code(order_code=order.kaspi_order_code, uid=uid)

    if kaspi_order is None:
        logger.error("#kaspi_notifications.tasks.process_order_review: order not found in Kaspi", extra=extra_data)
        return

    if kaspi_order.attributes.status == constants.KASPI_ORDER_CANCELLED:
        order.api_order_status = constants.KASPI_ORDER_CANCELLED
        order.notification_status = constants.STATUS_CLIENT_NOT_TO_BE_NOTIFIED
        order.save()
        logger.info("#kaspi_notifications.tasks.process_order_review: order is cancelled", extra=extra_data)
        return

    elif kaspi_order.attributes.status != constants.KASPI_ORDER_COMPLETED:
        if kaspi_order.attributes.status is not None:
            order.api_order_status = kaspi_order.attributes.status
            order.save()

        logger.info("#kaspi_notifications.tasks.process_order_review: order status in Kaspi is not COMPLETED, "
                    "status: %s", kaspi_order.attributes.status, extra=extra_data)
        return

    order.api_order_status = constants.KASPI_ORDER_COMPLETED
    order.save()

    logger.info("#kaspi_notifications.tasks.process_order_review sending message started", extra=extra_data)

    if order.merchant.is_whatsapp_communication():
        notify_about_order_review(order_code=order.kaspi_order_code)
        return

    gc = GreenApiConnector(merchant=order.merchant)

    message_resp = gc.order_review_notify(order)
    order: KaspiNewOrder

    if message_resp is None:
        order.second_message_delivery_status = 'ошибка грин апи'
        order.save()
        return

    logger.info("#kaspi_notifications.tasks.process_order_review sending message completed", extra=extra_data)

    save_notification_status.apply_async(
        args=(
            prettify_phone_number(order.phone_number),
            message_resp.id,
            order.merchant.green_api_instance_id,
            order.merchant.green_api_token,
            order.kaspi_order_code,
            False
        ),
        countdown=3 * 60
    )
    notification_status = constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT
    if order.merchant.green_api_review_with_confirm:
        notification_status = constants.STATUS_CLIENT_NEED_ANSWER
    order.notification_status = notification_status
    order.save()
    order.merchant.update_message_count()


@app.task
@time_it_and_log
def notify_about_new_postamat_order(merchant_id: int, uid: str):
    merchant = Merchant.objects.only('id', 'name').get(pk=merchant_id)
    logger.info(f'notify_about_new_postamat_order:: started', extra={'merchant': merchant.name})

    orders = KaspiNewOrder.objects.filter(merchant_id=merchant_id, is_delivery_to_postamat=True)
    gc = GreenApiConnector(merchant)
    kp = KaspiConnector(merchant=merchant)
    for order in orders:
        extra = {
            'uid': uid,
            'merchant': merchant.name,
            'merchant_id': merchant.pk,
            'orders_code': order.kaspi_order_code,
            'order_state': order.api_order_state,
            'order_status': order.api_order_status,
            'delivery': order.is_delivery_to_postamat
        }

        try:
            order_details: RESTOrder = kp.get_order_by_code(order_code=order.kaspi_order_code, uid=uid)
            courier_transmission_date = order_details.attributes.courierTransmissionDate

            need_to_notify_today = courier_transmission_date is not None and courier_transmission_date == datetime.now().date()
            order_status = order_details.attributes.status
            order_state = order_details.attributes.state

            if (need_to_notify_today and order_status not in ['COMPLETED', 'CANCELLED', 'CANCELLING',
                                                              'KASPI_DELIVERY_RETURN_REQUESTED', 'RETURNED']
                    and order_state == 'KASPI_DELIVERY'
                    and order.is_delivery_to_postamat is True):
                gc.send_notification_about_postomat_order(order)
                logger.info('notify_about_new_postamat_order :: message was sent',
                            extra=extra
                            )
            else:
                logger.info('notify_about_new_postamat_order :: order was skipped',
                            extra=extra)
        except BaseException as e:
            logger.info(f'notify_about_new_postamat_order :: error occurred :: {e}',
                        extra=extra)
            continue


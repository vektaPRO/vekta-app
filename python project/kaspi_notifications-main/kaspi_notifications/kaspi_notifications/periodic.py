import pytz
import logging
import asyncio
from typing import List
from datetime import timedelta, datetime
from django.conf import settings
from django.utils import timezone
from celery import shared_task

from api.service.green_api_connector import GreenApiConnector
from pktools.asyncio import to_thread, chunked_data
from pktools.string import generate_string
from pktools.helpers import lock_and_log
from pktools.models import TaskLocker
from notifications import constants
from notifications.models import Merchant, KaspiNewOrder
from kaspi_notifications.tasks import process_merchant_new_orders, process_order_review, notify_about_new_postamat_order

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@shared_task
@lock_and_log
def send_message_about_postamat():
    merchants = list(Merchant.objects.filter(
        enabled=True,
        execution_type=Merchant.EXECUTION_TYPE_B,
        send_messages_by_status=True
    ).only('id'))
    logger.info("kaspi_notifications.periodic.send_message_about_postamat started",
                extra={
                    'merchants_id': [mer.id for mer in merchants],
                })
    for merchant in merchants:
        uid = generate_string()
        notify_about_new_postamat_order.delay(
            merchant.id,
            uid
        )



@shared_task
@lock_and_log
def check_greenapi_instance_status():
    def process_merchant(merchant: Merchant, uid: str):
        gc = GreenApiConnector()
        should_send = False
        if merchant.green_api_instance_id is None:
            should_send = True
        else:
            extra = {
                'merchant_id': merchant.id,
                'merchant_name': merchant.name,
                'instance_id': merchant.green_api_instance_id,
                'uid': uid
            }
            try:
                logger.info('#kaspi_notifications.periodic.check_greenapi_instance_status started', extra=extra)
                merchant_instance_status = gc.get_instance_status(merchant)
                if merchant_instance_status.instance_status in ['blocked', 'notAuthorized', 'yellowCard']:
                    should_send = True
            except BaseException:
                logger.exception(
                    "#kaspi_notifications.periodic.check_greenapi_instance_status",
                    extra=extra)

        if should_send:
            merchant.enabled = False
            merchant.save()
            gc.send_notification_to_merchant_about_instance_status(merchant)
        else:
            logger.info(f'#kaspi_notifications.periodic.check_greenapi_instance_status :: merchant {merchant.name}'
                        f' does not have problems with GreenApi instance')

    uid = generate_string()

    merchants = Merchant.objects.filter(enabled=True, communication_type='GREEN_API')

    logger.info('#kaspi_notifications.periodic.check_greenapi_instance_status count %s', merchants.count(),
                extra={'uid': uid})

    async def process_merchants_tasks(merchants_to_process, uid: str):
        tasks = [to_thread(process_merchant, merchant, uid) for merchant in merchants_to_process]
        return await asyncio.gather(*tasks)

    for merchants_chunk in chunked_data(merchants):
        asyncio.run(process_merchants_tasks(merchants_chunk, uid=uid))


@shared_task
@lock_and_log
def parse_new_orders(
        new_orders_periodic_minutes: int = settings.NEW_ORDERS_PERIODIC_MINUTES,
        start_date: datetime = None,
        end_date: datetime = None,
):
    """
    1 - message send
    start_date, end_date must be in Almaty Time Zone
    """

    if start_date is None or end_date is None:
        end_date = timezone.now().astimezone(pytz.timezone('asia/almaty'))
        start_date = end_date - timedelta(minutes=new_orders_periodic_minutes)

    merchants = list(Merchant.objects.filter(
        enabled=True,
        execution_type=Merchant.EXECUTION_TYPE_B,
        send_first_message=True
    ).only('id'))
    logger.info("kaspi_notifications.periodic.parse_new_orders started",
                extra={
                    'merchants_id': [mer.id for mer in merchants],
                })
    for merchant in merchants:
        uid = generate_string()
        process_merchant_new_orders.delay(
            merchant.id,
            start_date,
            end_date,
            uid
        )


@shared_task
@lock_and_log
def process_delivered_orders(limit: int = 0):
    """
    2 - message send
    """

    def process_order(kaspi_order: KaspiNewOrder, uid: str):
        extra = {
            'merchant_id': kaspi_order.merchant.id,
            'merchant_name': kaspi_order.merchant.name,
            'order_code': kaspi_order.kaspi_order_code,
            'uid': uid
        }
        try:
            logger.info('#kaspi_notifications.periodic.process_delivered_orders started', extra=extra)
            process_order_review(order=kaspi_order, uid=uid)
            logger.info("#kaspi_notifications.periodic.process_delivered_orders success", extra=extra)
        except BaseException:
            logger.exception(
                "#kaspi_notifications.periodic.process_delivered_orders",
                extra=extra)

    async def process_orders(kaspi_orders: List[KaspiNewOrder], uid: str):
        tasks = [to_thread(process_order, kaspi_order, uid) for kaspi_order in kaspi_orders]
        return await asyncio.gather(*tasks)

    uid = generate_string()

    orders = KaspiNewOrder.objects.filter(
        notification_status=constants.STATUS_CLIENT_TO_BE_NOTIFIED,
        merchant__enabled=True,
        merchant__send_second_message=True
    ).exclude(
        first_message_delivery_status__in=[
            constants.ERROR_WHILE_DELIVERING_MESSAGE,
            constants.CLIENT_WITHOUT_WHATSAPP
        ]
    ).select_related('merchant')

    if limit:
        orders = orders[:limit]

    logger.info('#kaspi_notifications.periodic.process_delivered_orders count %s', orders.count(), extra={'uid': uid})

    for orders_chunk in chunked_data(orders, 1000):
        asyncio.run(process_orders(orders_chunk, uid=uid))


@shared_task
@lock_and_log
def lock_task(full_task_name: str):
    if TaskLocker.lock(full_task_name):
        logger.info('#kaspi_notifications.periodic.lock_task locked success', extra={
            'full_task_name': full_task_name,
            'status': TaskLocker.STATUS_LOCKED
        })
        return
    logger.error('#kaspi_notifications.periodic.lock_task cannot lock', extra={
        'full_task_name': full_task_name,
        'status': TaskLocker.STATUS_UNLOCKED
    })


@shared_task
@lock_and_log
def unlock_task(full_task_name: str):
    if TaskLocker.unlock(full_task_name):
        logger.info('#kaspi_notifications.periodic.unlock_task unlocked success', extra={
            'full_task_name': full_task_name,
            'status': TaskLocker.STATUS_UNLOCKED
        })
        return
    logger.error('#kaspi_notifications.periodic.unlock_task cannot unlock', extra={
        'full_task_name': full_task_name,
        'status': TaskLocker.STATUS_LOCKED
    })

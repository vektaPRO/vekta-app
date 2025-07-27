from datetime import datetime
import logging
from django.conf import settings

from notifications import constants
from notifications.green_api import save_green_api_message_status
from notifications.models import KaspiNewOrder
from pktools.helpers import time_it_and_log
from .celery import app


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@app.task
@time_it_and_log
def save_notification_status(chat_id, message_id, instance_id, api_token, order_id, check_message_type) -> None:
    extra = {'chat_id': chat_id,
             'message_id': message_id,
             'instance_id': instance_id,
             'order_id': order_id}
    logger.info('additional_tasks::send_message_for_second_message: started', extra=extra)
    if len(chat_id) == 10: chat_id = '7' + chat_id
    message_status = save_green_api_message_status(chat_id, message_id, instance_id, api_token)

    status_map = {
        'sent': constants.MESSAGE_IS_SENT,
        'delivered': constants.MESSAGE_IS_DELIVERED,
        'read': constants.MESSAGE_IS_READ,
        'no_whatsapp': constants.CLIENT_WITHOUT_WHATSAPP
    }

    kaspi_new_order = KaspiNewOrder.objects.filter(kaspi_order_code=order_id).first()

    if not message_status.startswith('err0r:'):
        message_status = status_map.get(message_status, constants.MESSAGE_IS_NOT_DELIVERED)
    else:
        if message_status.startswith("err0r: Message not found by id") or message_status.startswith('err0r: "Message not found by id'):
            message_status = "ошибка грин апи"

    if check_message_type:
        kaspi_new_order.first_message_delivery_status = message_status
        kaspi_new_order.first_message_sending_time = datetime.now()
    else:
        kaspi_new_order.second_message_delivery_status = message_status

    kaspi_new_order.save()
    extra = {
        'chat_id': chat_id,
        'message_id': message_id,
        'instance_id': instance_id,
        'order_id': order_id,
        'first_message_delivery_status': kaspi_new_order.first_message_delivery_status,
        'first_message_sending_time': kaspi_new_order.first_message_sending_time,
        'second_message_delivery_status': kaspi_new_order.second_message_delivery_status
    }

    logger.info('additional_tasks::save_notification_status completed', extra=extra)

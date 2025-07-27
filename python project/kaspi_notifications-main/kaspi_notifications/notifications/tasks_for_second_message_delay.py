import json
import logging

import requests

from kaspi_notifications.celery import app
from notifications import constants
from notifications.models import KaspiNewOrder
from django.conf import settings

from pktools.helpers import time_it_and_log

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@app.task
@time_it_and_log
def send_message_for_second_message(chat_id, message, instance_id, api_token, order_code):
    extra = {'chat_id': chat_id, 'instance_id': instance_id}
    logger.info('tasks_for_second_message_delay::send_message_for_second_message: started', extra=extra)
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/sendMessage/{api_token}'

    payload = json.dumps({
        'chatId': f'{chat_id}@c.us',
        'message': message
    })
    headers = {
        'Content-Type': 'application/json'
    }
    response = requests.request('POST', url, headers=headers, data=payload)

    message_id = response.json()['idMessage']
    save_notification_status_second.apply_async(args=(chat_id, message_id, instance_id, api_token, order_code), countdown=60)
    logger.info(f'tasks_for_second_message_delay::send_message_for_second_message: completed',
                extra={'chat_id': chat_id, 'instance_id': instance_id, 'message_id': message_id, 'response_status': response.status_code})


@app.task
@time_it_and_log
def save_notification_status_second(chat_id, message_id, instance_id, api_token, order_code) -> None:
    extra = {'chat_id': chat_id, 'instance_id': instance_id, 'message_id': message_id, 'order': order_code}
    logger.info(f'tasks_for_second_message_delay::save_notification_status_second:: started', extra=extra)
    if len(chat_id) == 10: chat_id = '7' + chat_id
    message_status = save_green_api_message_status_second(
        chat_id, message_id, instance_id, api_token)

    status_map = {
        'sent': constants.MESSAGE_IS_SENT,
        'delivered': constants.MESSAGE_IS_DELIVERED,
        'read': constants.MESSAGE_IS_READ,
        'no_whatsapp': constants.CLIENT_WITHOUT_WHATSAPP
    }

    kaspi_new_order = KaspiNewOrder.objects.filter(kaspi_order_code=order_code).first()
    message_status = status_map.get(message_status, constants.MESSAGE_IS_NOT_DELIVERED)
    kaspi_new_order.second_message_delivery_status = message_status
    kaspi_new_order.notification_status = constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT
    kaspi_new_order.save()
    extra = {'chat_id': chat_id, 'instance_id': instance_id,
             'message_id': message_id, 'order': order_code,
             'message_status': message_status}
    logger.info(f'tasks_for_second_message_delay::save_notification_status_second:: completed', extra=extra)


def save_green_api_message_status_second(chat_id, message_id, instance_id, api_token):
    extra = {'chat_id': chat_id, 'instance_id': instance_id, 'message_id': message_id}
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/getMessage/{api_token}'

    payload = json.dumps({
        'chatId': f'{chat_id}@c.us',
        'idMessage': message_id
    })
    headers = {
        'Content-Type': 'application/json'
    }
    response = requests.request('POST', url, headers=headers, data=payload)

    json_data = response.json()
    if isinstance(json_data, dict) and 'chatId' not in json_data:
        logger.info(f'save_green_api_message_status_second:: status = "no_whatsapp"', extra=extra)
        return 'no_whatsapp'
    if isinstance(json_data, dict) and 'statusMessage' in json_data:
        logger.info(f'save_green_api_message_status_second:: status ={json_data["statusMessage"]}', extra=extra)
        return json_data['statusMessage']

    logger.info(f'save_green_api_message_status_second:: status = "not_send"', extra=extra)

    return 'not_send'

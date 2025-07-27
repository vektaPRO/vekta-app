import json
import os
import requests
import logging
from django.conf import settings

from pktools.helpers import time_it_and_log
from kaspi_notifications.celery import app


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@app.task
@time_it_and_log
def send_message_through_green_api_auto_fill(chat_id, message, instance_id, api_token):
    extra = {'chat_id': chat_id, 'instance_id': instance_id}
    logger.info('green_api_instance_functions::send_message_through_green_api_auto_fill: started', extra=extra)
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/sendMessage/{api_token}'

    payload = json.dumps({
        'chatId': f'{chat_id}@c.us',
        'message': message
    })
    headers = {
        'Content-Type': 'application/json'
    }

    response = requests.request('POST', url, headers=headers, data=payload)

    logger.info(f'green_api_instance_functions::send_message_through_green_api_auto_fill: completed, response :: {response.json()}',
                extra=extra)

    return response.json()


def create_new_green_api_instance_green_api():
    url = f'https://7700.api.greenapi.com/partner/createInstance/{os.getenv("GREEN_API_PARTNER_TOKEN")}'
    headers = {
        'Content-Type': 'application/json'
    }
    response = requests.request('POST', url, headers=headers)

    logger.info(f'create_new_green_api_instance_green_api:: response={response.status_code}, {response.json()}')

    return response.json()


def retrieve_qr_code_for_instance_authorization_green_api(instance_id, instance_token):
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/qr/{instance_token}'
    payload = {}
    headers = {}

    response = requests.request("GET", url, headers=headers, data=payload)
    if response.status_code != 200:
        return None

    logger.info(f'retrieve_qr_code_for_instance_authorization_green_api:: response={response.status_code}, {response.json()}',
                extra={'instance_id': instance_id})

    return response.json()['message']


def delete_green_api_instance(instance_id):
    url = f'https://7700.api.greenapi.com/partner/deleteInstanceAccount/{os.getenv("GREEN_API_PARTNER_TOKEN")}'
    headers = {
        'Content-Type': 'application/json'
    }
    payload = json.dumps({
        'idInstance': f'{instance_id}'
    })
    response = requests.request('POST', url, headers=headers, data=payload)

    logger.info(
        f'delete_green_api_instance:: response={response.status_code}, {response.json()}',
        extra={'instance_id': instance_id})

    return response.json()

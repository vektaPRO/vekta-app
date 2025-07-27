import json
from datetime import datetime
import os
import re
import sys
import traceback
import time as tm
import secrets
import requests
import logging
from django.conf import settings


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


def log(message, e=None):
    print(message)
    with open(os.getcwd() + '/../logs.txt', mode='a') as f:
        f.write(f'{datetime.now()} - {message}\n')
        if e:
            f.write(f'{datetime.now()} - {format_exception(e)}\n')


def format_exception(e) -> str:
    return ''.join(
        traceback.format_exception(*(sys.exc_info()))) + '\n' + f'{e.__class__}\n' + f'{e.__str__()}\n' + f'{e}\n'


def convert_datetime_to_milliseconds(date_time):
    """ Method to convert datetime object to milliseconds """

    return int(tm.mktime(date_time.timetuple()) * 1000)


def convert_datetime_from_milliseconds(milliseconds):
    """ Method to convert milliseconds to datetime object """

    return datetime.fromtimestamp(milliseconds / 1000.0)


def greeting(language_rus: bool):
    current_time = datetime.now().time()
    hour = current_time.hour

    if 5 <= hour < 10:
        return "Доброе утро" if language_rus else "Қайырлы таң"
    elif 10 <= hour < 18:
        return "Добрый день" if language_rus else "Қайырлы күн"
    elif 18 <= hour < 21:
        return "Добрый вечер" if language_rus else "Қайырлы кеш"
    else:
        return "Доброй ночи" if language_rus else "Қайырлы түн"


def format_phone_number(phone):

    digits = re.sub(r'\D', '', phone)

    if digits.startswith('8'):
        digits = '7' + digits[1:]
    elif digits.startswith('7'):
        pass
    else:
        return '77477174422'

    if len(digits) == 10:
        return '7'+digits
    if len(digits) == 11:
        return digits
    else:
        return '77477174422'


def validate_message_of_client(message):
    positive_responses = [
        "1", "да", "да, всё хорошо", "да, все хорошо", "да все хорошо",
        "всё хорошо", "все хорошо", "хорошо", "отлично", "замечательно",
        "здорово", "прекрасно", "устраивает", "да, меня устраивает",
        "да, все устраивает", "да, устраивает", "всё устраивает",
        "все устраивает", "всё отлично", "все отлично",
        "всё замечательно", "все замечательно", "да, нормально",
        "нормально", "да, спасибо", "спасибо", "спасибо, все хорошо",
        "спасибо, да", "спасибо, все устраивает", "да, здраствуйте",
        "здраствуйте, да", "добрый день, да", "здраствуйте, 1"
    ]
    negative_responses = [
        "2", "нет", "нет, мне не понравилось", "мне не понравилось",
        "не понравилось", "ужасно", "плохо", "совсем плохо",
        "ничего не понравилось", "не устраивает", "не подходит",
        "нет, спасибо", "нет, не нужно", "нет, не устраивает",
        "нет, это не то", "совсем не то", "ужас", "ужасно все",
        "очень плохо", "очень не понравилось", "разочарован",
        "не доволен", "не устраивает меня", "нет, здраствуйте",
        "здраствуйте, нет", "добрый день, нет"
    ]

    response_normalized = message.strip().lower()

    if response_normalized in positive_responses:
        return '1'
    elif response_normalized in negative_responses:
        return '2'
    else:
        return '0'


def get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    logger.info(f"get_client_ip::HTTP_X_FORWARDED_FOR = {x_forwarded_for}")
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')

    logger.info(f"get_client_ip::Final IP: {ip}")

    return ip


def set_settings_green_api_util(instance_id, api_token, webhook_url, green_api_token):
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/setSettings/{api_token}'

    payload = json.dumps({
        'webhookUrl': webhook_url,
        'webhookUrlToken': green_api_token,
        'stateWebhook': f'yes',
        'incomingWebhook': f'yes',
        'outgoingWebhook': f'yes',
        'outgoingMessageWebhook': f'yes',
        'outgoingAPIMessageWebhook': f'yes',
        'delaySendMessagesMilliseconds': 5000
    })
    headers = {
        'Content-Type': 'application/json'
    }

    response = requests.request('POST', url, headers=headers, data=payload)
    logger.info(f'set_settings_green_api_util::Green Api Settings2 = {instance_id}: {response.status_code}')

    if response.status_code != 200:
        return False

    return response.json()['saveSettings']


def generate_bearer_token(length=64):
    return secrets.token_urlsafe(length)[:length]

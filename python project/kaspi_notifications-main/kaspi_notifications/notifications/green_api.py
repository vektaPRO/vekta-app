import json
import logging
import os
import datetime
from typing import Union
from django.conf import settings

import requests
import base64

from notifications.models import Merchant
from notifications.utils import format_phone_number
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


def send_message_through_green_api(chat_id, message, instance_id, api_token):
    extra = {
        'chat_id': chat_id,
        'instance_id': instance_id
    }
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/sendMessage/{api_token}'

    payload = json.dumps({
        'chatId': f'{chat_id}@c.us',
        'message': message
    })
    headers = {
        'Content-Type': 'application/json'
    }

    try:
        response = requests.request('POST', url, headers=headers, data=payload)
        response.raise_for_status()  # Raises a HTTPError if the status is 4xx, 5xx

        try:
            json_response = response.json()
            logger.info(f"green_api::send_message_through_green_api :: {response.status_code} = {json_response}",
                                  extra=extra)
            return json_response
        except json.JSONDecodeError:
            logger.error(f"green_api::send_message_through_green_api :: JSON error - {response.status_code} = {response.text}",
                                  extra=extra)
            return 'null'

    except requests.exceptions.HTTPError as http_err:
        logger.error(
            f"green_api::send_message_through_green_api :: HTTPError - = {http_err}",
            extra=extra)
    except requests.exceptions.ConnectionError as conn_err:
        logger.error(
            f"green_api::send_message_through_green_api :: ConnectionError - = {conn_err}",
            extra=extra)
    except requests.exceptions.Timeout as timeout_err:
        logger.error(
            f"green_api::send_message_through_green_api :: Timeout Error - = {timeout_err}",
            extra=extra)
    except requests.exceptions.RequestException as req_err:
        logger.error(
            f"green_api::send_message_through_green_api :: RequestException - = {req_err}",
            extra=extra)

    return 'null'


def send_message_through_green_api_image(chat_id, message, img_url, instance_id, api_token):
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/sendFileByUrl/{api_token}'

    payload = json.dumps({
        "chatId": f"{chat_id}@c.us",
        "urlFile": f"{img_url}",
        "fileName": "horse.png",
        "caption": f"{message}"
    })
    headers = {
        'Content-Type': 'application/json'
    }

    extra = {
        'chat_id': chat_id,
        'instance_id': instance_id,
        'image_url': img_url
    }

    response = requests.request('POST', url, headers=headers, data=payload)

    logger.info(f"green_api::send_message_through_green_api_image :: {response.status_code} = {response.json()}",
                          extra=extra)

    return response.json()


def save_green_api_message_status(chat_id, message_id, instance_id, api_token):
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/getMessage/{api_token}'

    payload = json.dumps({
        'chatId': f'{chat_id}@c.us',
        'idMessage': message_id
    })
    headers = {
        'Content-Type': 'application/json'
    }

    extra = {
        'chat_id': chat_id,
        'instance_id': instance_id
    }

    response = requests.request('POST', url, headers=headers, data=payload)

    try:
        response_content = response.json()
    except json.JSONDecodeError:
        response_content = response.text

    logger.info(
        f"green_api::save_green_api_message_status :: {response.status_code} = {response_content}",
        extra=extra)

    if response.status_code == 504 or response.status_code == 502:
        logger.error(
            f"green_api::save_green_api_message_status :: Green Api 500 Error = {response.json()}",
            extra=extra)
        return 'sent'

    try:
        json_data = response.json()
    except json.JSONDecodeError:
        json_data = response.text

    if response.status_code == 200:
        if isinstance(json_data, dict) and 'statusMessage' in json_data:
            logger.info(
                f"green_api::save_green_api_message_status :: message status successfully retrieved",
                extra={
                    'chat_id': chat_id,
                    'instance_id': instance_id,
                    'message_status': json_data['statusMessage']
                })
            return json_data['statusMessage']
        if isinstance(json_data, dict) and 'chatId' not in json_data:
            logger.error(
                f"green_api::save_green_api_message_status :: does not have whatsapp",
                extra=extra)
            return 'no_whatsapp'
        return 'not_send'

    logger.error(f'Green Api Error  = {json_data}', extra=extra)

    if isinstance(json_data, dict) and 'message' in json_data:
        logger.error(
            f"green_api::save_green_api_message_status :: error, {json_data}",
            extra=extra)
        return f"err0r: {json_data['message']}"

    return f'err0r: {json_data}'


def create_new_green_api_instance():
    url = f'https://7700.api.greenapi.com/partner/createInstance/{os.getenv("GREEN_API_PARTNER_TOKEN")}'
    headers = {
        'Content-Type': 'application/json'
    }
    response = requests.request('POST', url, headers=headers)

    logger.info(f'green_api::create_new_green_api_instance :: {response.status_code} :: {response.json()}')

    return response.json()


def retrieve_qr_code_for_instance_authorization(instance_id, instance_token):
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/qr/{instance_token}'
    payload = {}
    headers = {}

    response = requests.request("GET", url, headers=headers, data=payload)
    if response.status_code != 200:
        return None

    logger.info(f'green_api::retrieve_qr_code_for_instance_authorization :: {response.status_code} :: {response.json()}',
                          extra={
                              'instance-id': instance_id
                          })

    return response.json()


def get_account_status(instance_id: str, instance_token: str) -> Union[str, None]:
    url = f'https://7700.api.greenapi.com/waInstance{instance_id}/getStateInstance/{instance_token}'
    payload = {}
    headers = {}

    response = requests.request("GET", url, headers=headers, data=payload)

    if response.status_code != 200:
        return None

    status = response.json()['stateInstance'] if 'stateInstance' in response.json() else None

    logger.info(
        f'green_api::get_account_status :: {response.status_code} :: {response.json()}',
        extra={
            'instance-id': instance_id,
            'status': status
        })

    return status


def generate_qr_code_to_send_to_user(instance_id, instance_token):
    response = retrieve_qr_code_for_instance_authorization(instance_id, instance_token)
    greenapi_qr_link = response['message']
    file = base64.decodebytes(greenapi_qr_link.encode('utf-8'))

    logger.info(
        f'green_api::generate_qr_code_to_send_to_user :: {response.status_code} :: {response.json()}',
        extra={
            'instance-id': instance_id,
        })

    return file


def send_info_about_subscription_expired_to_whatsapp(instance_id, instance_token):
    merchants = Merchant.objects.all()
    logger.info(
        f'green_api::send_info_about_subscription_expired_to_whatsapp :: started',
        extra={
            'number_of_merchants': len(merchants),
        })

    for merchant in merchants:
        try:

            if not merchant.subscription_date_end:
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: skipping merchant'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id
                    })
                merchant.enabled = False
                merchant.save()
                continue

            days_until_expiration = (merchant.subscription_date_end - datetime.datetime.now().date()).days
            if days_until_expiration <= -1:
                if merchant.enabled:
                    merchant.enabled = False
                    merchant.save()
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: already deactivated, skipping'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration
                    })
                continue

            if not merchant.contact_number:
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: has no contact number, skipping'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration
                    })
                if days_until_expiration == 0:
                    merchant.enabled = False
                    merchant.save()
                    logger.info(
                        f'green_api::send_info_about_subscription_expired_to_whatsapp :: merchant was deactivated'
                        f' no subscription end date',
                        extra={
                            'merchant': merchant.name,
                            'instance-id': instance_id,
                            'days_until_expiration': days_until_expiration
                        })
                continue

            phone_number = format_phone_number(merchant.contact_number)
            logger.info(
                f'green_api::send_info_about_subscription_expired_to_whatsapp ::'
                f' no subscription end date',
                extra={
                    'merchant': merchant.name,
                    'instance-id': instance_id,
                    'days_until_expiration': days_until_expiration
                })

            if not merchant.get_subscription_type():
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: no subscription type, skipping'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration
                    })
                if days_until_expiration == 0:
                    merchant.enabled = False
                    merchant.save()
                    logger.info(
                        f'green_api::send_info_about_subscription_expired_to_whatsapp :: merchant was deactivated'
                        f' no subscription end date',
                        extra={
                            'merchant': merchant.name,
                            'instance-id': instance_id,
                            'days_until_expiration': days_until_expiration
                        })
                continue

            if days_until_expiration not in [1, 0]:
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: skipping merchant, end of subscription date not expired'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration
                    })
                continue

            if phone_number == '77477174422':
                message = (
                    f'На магазин {merchant.name} не отправлено сообщения об окончании подписки. \n\nУ этого магазина подписка заканчивается ({merchant.subscription_date_end.strftime("%d.%m.%Y")}). '
                    '\n\nПричина: не правильный номер для связи'
                )
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: skipping merchant, phone is wrong'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration
                    })
                send_message_through_green_api(phone_number, message, instance_id, instance_token)
                continue

            if days_until_expiration == 1:
                if merchant.get_subscription_type() == 'demo':
                    message_demo = (
                        'Сәлеметсіз бе!'
                        f'\nҚұрметті клиент {merchant.name}, сіздің IRocket сервисімізді  тексеруге арналған мерзіміңіз *ертең ({merchant.subscription_date_end.strftime("%d.%m.%Y")}) аяқталады.*'
                        '\n\nҚызметтерімізді пайдалануды жалғастырасызба?.\nТариф жайлы ақпарат жіберейін бе?\n\n*****\n\n'
                        f'Уважаемый клиент {merchant.name}, ваш пробный период заканчивается *завтра ({merchant.subscription_date_end.strftime("%d.%m.%Y")}).*'
                        '\n\nПожалуйста, оформите подписку, чтобы продолжить пользоваться нашими услугами. \nВы хотите получить информацию о наших тарифах?')
                    send_message_through_green_api(phone_number, message_demo, instance_id, instance_token)
                    logger.info(
                        f'green_api::send_info_about_subscription_expired_to_whatsapp :: subscription expires tomorrow'
                        f' no subscription end date',
                        extra={
                            'merchant': merchant.name,
                            'instance-id': instance_id,
                            'days_until_expiration': days_until_expiration
                        })
                else:
                    message_standart = (
                        'Сәлеметсіз бе!'
                        f'\nҚұрметті клиент {merchant.name}, сіздің жазылым мерзіміңіз *ертең ({merchant.subscription_date_end.strftime("%d.%m.%Y")}) аяқталады.*'
                        '\n\nҚызметтерімізді пайдалануды жалғастыру үшін жазылымды рәсімдеңіз.\n\n*****\n\n'
                        f'Уважаемый клиент {merchant.name}, ваша подписка заканчивается *завтра ({merchant.subscription_date_end.strftime("%d.%m.%Y")}).*'
                        '\n\nПожалуйста, продлите вашу подписку, чтобы продолжить пользоваться нашими услугами.')
                    send_message_through_green_api(phone_number, message_standart, instance_id, instance_token)
                    logger.info(
                        f'green_api::send_info_about_subscription_expired_to_whatsapp :: subscription expires tomorrow'
                        f' no subscription end date',
                        extra={
                            'merchant': merchant.name,
                            'instance-id': instance_id,
                            'days_until_expiration': days_until_expiration
                        })
            elif days_until_expiration == 0:
                if merchant.get_subscription_type() == 'demo':
                    message_demo = (
                        'Сәлеметсіз бе!'
                        f'\nҚұрметті клиент {merchant.name}, сіздің IRocket сервисімізді  тексеруге арналған мерзіміңіз *бүгін ({merchant.subscription_date_end.strftime("%d.%m.%Y")}) аяқталды.*'
                        '\nБіз IRocket жазылымына төлем алған жоқпыз.'
                        '\nСұрақтарыңыз бар ма немесе бір нәрсеге көңіліңіз толмай ма?'
                        '\nБіз сізге көмектесу үшін бізбен хабарласыңыз.\n\n*****\n\n'
                        f'Уважаемый клиент {merchant.name}, ваш пробный период *закончился сегодня ({merchant.subscription_date_end.strftime("%d.%m.%Y")})*. '
                        '\nМы не получили оплату за подписку на IRocket.'
                        '\nВозможно, у вас есть вопросы или вы чем-то недовольны? '
                        '\nПожалуйста, свяжитесь с нами, чтобы мы могли помочь вам.')
                    send_message_through_green_api(phone_number, message_demo, instance_id, instance_token)
                    logger.info(
                        f'green_api::send_info_about_subscription_expired_to_whatsapp :: subscription has ended'
                        f' no subscription end date',
                        extra={
                            'merchant': merchant.name,
                            'instance-id': instance_id,
                            'days_until_expiration': days_until_expiration
                        })
                else:
                    message_standart = (
                        f'Құрметті клиент {merchant.name}, сіздің жазылымыңыз *бүгін ({merchant.subscription_date_end.strftime("%d.%m.%Y")}) аяқталды.*'
                        '\nБіз IRocket жазылымына төлем алған жоқпыз.'
                        '\nСұрақтарыңыз бар ма немесе бір нәрсеге көңіліңіз толмай ма?'
                        '\nБіз сізге көмектесу үшін бізбен хабарласыңыз.\n\n*****\n\n'
                        f'Уважаемый клиент {merchant.name}, ваша подписка *закончилась сегодня ({merchant.subscription_date_end.strftime("%d.%m.%Y")}).* '
                        '\nМы не получили оплату за следующий месяц на IRocket.'
                        '\nВозможно, у вас есть вопросы или вы чем-то недовольны? '
                        '\nПожалуйста, свяжитесь с нами, чтобы мы могли помочь вам.')
                    send_message_through_green_api(phone_number, message_standart, instance_id, instance_token)
                    logger.info(
                        f'green_api::send_info_about_subscription_expired_to_whatsapp :: subscription has ended'
                        f' no subscription end date',
                        extra={
                            'merchant': merchant.name,
                            'instance-id': instance_id,
                            'days_until_expiration': days_until_expiration
                        })
                merchant.enabled = False
                merchant.save()
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: merchant was notified about subscription ending'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration,
                        'phone_number': phone_number
                    })
            else:
                logger.info(
                    f'green_api::send_info_about_subscription_expired_to_whatsapp :: error on subscription expiration, skipping'
                    f' no subscription end date',
                    extra={
                        'merchant': merchant.name,
                        'instance-id': instance_id,
                        'days_until_expiration': days_until_expiration
                    })
        except BaseException as e:
            logger.info(
                f'green_api::send_info_about_subscription_expired_to_whatsapp :: Exception raised while processing'
                f' no subscription end date',
                extra={
                    'merchant': merchant.name,
                    'instance-id': instance_id,
                    'error': e
                })
            continue

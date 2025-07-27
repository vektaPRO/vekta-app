import datetime
import json
import os

import requests

from parser_kaspi_data.models import Merchant
from parser_kaspi_data.service import project_logger

API_TOKEN = os.getenv('GREEN_API_TOKEN')
INSTANCE_ID = os.getenv('GREEN_API_INSTANCE')
logger = project_logger.get_logger(__name__)


def make_correct_format_of_phone_number(phone_number: str) -> str:
    if phone_number.startswith('8'):
        phone_number = '7' + phone_number[1:]
    elif phone_number.startswith('7'):
        phone_number = phone_number

    if len(phone_number) == 10:
        return '7' + phone_number
    if len(phone_number) == 11:
        return phone_number


def send_message_through_green_api(merchant: Merchant):
    date_time = datetime.datetime.now().strftime('%d.%m.%Y %H:%M')
    if not merchant.user.phone_number:
        merchant_user_number = None
        message_for_manager = f'{date_time} :: У клиента {merchant.name} возможно изменились логин или пароль от каспи кабинета.\n' \
                              f'Демпинг невозможен, номера телефона у клиента нет'
        logger.info(f'Client {merchant.name} doesn"t have phone number')
    else:
        merchant_user_number = make_correct_format_of_phone_number(merchant.user.phone_number)
        message_for_manager = f'{date_time} :: У клиента {merchant.name} возможно изменились логин или пароль от каспи кабинета.\n' \
                              f'Демпинг невозможен, необходимо немедленно связаться с клиентом по телефону https://wa.me/{merchant_user_number} для выяснения деталей.'
    message_for_client = f'Добрый день, уважаемый клиент!\nС вами на связи команда iRocket.kz\nВозможно, что у вас изменились логин или пароль от каспи кабинета.\n' \
                              f'Демпинг невозможен, необходимо немедленно связаться с менеджером по телефону https://wa.me/{os.getenv("MANAGER_PHONE")} для выяснения деталей.'

    if merchant_user_number is None or merchant.user.informed_about_login_problems is True:
        recipients = {os.getenv('IROCKET_TEAM_GROUP_ID'): {'message': message_for_manager, 'prefix': 'g'}
                      }
    else:
        recipients = {merchant_user_number: {'message': message_for_client, 'prefix': 'c'},
                      os.getenv('IROCKET_TEAM_GROUP_ID'): {'message': message_for_manager, 'prefix': 'g'}
                      }
        merchant.user.informed_about_login_problems = True
        merchant.user.save()
    for recipient_number, recipient_data in recipients.items():
        url = f'https://api.green-api.com/waInstance{INSTANCE_ID}/sendMessage/{API_TOKEN}'

        payload = json.dumps({
            'chatId': f'{recipient_number}@{recipient_data["prefix"]}.us',
            'message': recipient_data["message"]
        })
        headers = {
            'Content-Type': 'application/json'
        }

        try:
            response = requests.request('POST', url, headers=headers, data=payload)

            if response.status_code == 200:
                logger.info(f'Message to inform about incorrect login is sent\n'
                            f' merchant {merchant.name} :: phone number {merchant_user_number}:{response.status_code} = {response.json()}')
        except BaseException as e:
            logger.info(f'Some error occurred while sending message about incorrect login\n'
                        f' merchant {merchant.name} :: phone number {merchant_user_number}:{e}')

    return

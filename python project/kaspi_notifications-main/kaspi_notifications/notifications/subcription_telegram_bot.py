import asyncio
import datetime
import os
import telegram
import logging
from django.conf import settings


from notifications.models import Merchant

bot = telegram.Bot(token=os.getenv('TG_BOT_TOKEN'))
logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


def send_message_to_tg_channel(chat_id, message):
    asyncio.run(bot.sendMessage(chat_id=chat_id, text=message))


def send_info_about_subscription_expired_to_tg_channel():
    merchants = Merchant.objects.all()
    logger.info(f'send_info_about_subscription_expired_to_tg_channel:: started - {datetime.now()}\n,'
                f'number of merchants = {len(merchants)}')
    message_text = 'Добрый день, уведомляю Вас, что по данным клиентам истекает или уже истек срок подписки:\n'
    for merchant in merchants:
        if merchant.subscription_date_end - datetime.timedelta(days=3) > datetime.datetime.now().date():
            logger.info(f'send_info_about_subscription_expired_to_tg_channel:: skipping merchant {merchant}\n because '
                        f'subscription ends more than in 3 days, date end = {merchant.subscription_date_end}')
            continue
        subscription_expiration_date = merchant.subscription_date_end.strftime('%d.%m.%Y')
        message = f'Клиент {merchant.name}: дата окончания подписки: {subscription_expiration_date}\n'
        message_text += message
        logger.info(f'send_info_about_subscription_expired_to_tg_channel::  merchant {merchant}\n was notified about'
                    f' subscription day end, date end = {merchant.subscription_date_end}')
    send_message_to_tg_channel(os.getenv('CHAT_ID'), message_text)
    logger.info(f'send_info_about_subscription_expired_to_tg_channel:: ended - {datetime.now()}\n')

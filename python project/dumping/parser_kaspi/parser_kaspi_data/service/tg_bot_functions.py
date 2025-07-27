import os

from aiogram import Router, Dispatcher, Bot
from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.proxy_manager import check_asocks_proxy_balance

logger = project_logger.get_logger(__name__)

API_TOKEN = os.getenv('API_TOKEN')

router = Router()
dp = Dispatcher()
bot = Bot(token=API_TOKEN)


async def send_notification_about_asocks_balance():
    balance = check_asocks_proxy_balance()
    if balance is not None:
        if balance < 10:
            await send_kaspi_client_data_to_tg(f'Баланс asocks прокси = {balance}, необходимо срочно пополнить',
                                               chat_id=os.getenv('CHAT_ID'))


async def send_kaspi_client_data_to_tg(message, chat_id):
    try:
        await bot.send_message(chat_id=chat_id, text=message)
        logger.info(f'Sending kaspi client data for {chat_id}...')
    except Exception as e:
        logger.error(f"Failed to send kaspi client data to chat ID {chat_id}: {e}")

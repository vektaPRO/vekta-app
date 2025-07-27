import json
import os
from time import sleep
from typing import Union

from dotenv import load_dotenv
from telegram import Update, Bot, KeyboardButton, ReplyKeyboardRemove, ReplyKeyboardMarkup, InlineKeyboardButton, \
    InlineKeyboardMarkup, Message, ReactionTypeEmoji, LabeledPrice, PreCheckoutQuery, SuccessfulPayment
from telegram.error import BadRequest
from telegram.ext import ApplicationBuilder, Application, CommandHandler, MessageHandler, PreCheckoutQueryHandler, \
    filters, ContextTypes

from notifications.models import Invoice
from notifications.telegram_bot import users
from notifications.utils import log

load_dotenv()

telegram_bot_token = os.getenv('SIGN_UP_TG_TOKEN')
robokassa_payment_token = os.getenv('ROBOKASSA_PAYMENT_TOKEN')


def _update_middleware(update: Update) -> Union[Message, PreCheckoutQuery, SuccessfulPayment]:
    print(update)
    return update.message if update.message else update.pre_checkout_query


def _handler_wrapper(bot, handler: callable):
    return lambda update, _: handler(
        bot,
        _update_middleware(update)
    )


async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
    log('Exception while handling an update', context.error)


class TelegramBot:
    def __init__(self):
        self.app: Application = ApplicationBuilder().token(telegram_bot_token).build()
        self.app.add_error_handler(error_handler)

    def with_command_handler(self, command: str, handler: callable):
        self.app.add_handler(CommandHandler(command, _handler_wrapper(self, handler)))
        return self

    def with_message_handler(self, handler: callable):
        message_filter = filters.TEXT & (~filters.COMMAND) & (~filters.SUCCESSFUL_PAYMENT)
        self.app.add_handler(MessageHandler(message_filter, _handler_wrapper(self, handler)))
        return self

    def with_pre_checkout_handler(self, handler: callable):
        self.app.add_handler(PreCheckoutQueryHandler(_handler_wrapper(self, handler)))
        return self

    def with_successful_payment_handler(self, handler: callable):
        self.app.add_handler(MessageHandler(filters.SUCCESSFUL_PAYMENT, _handler_wrapper(self, handler)))
        return self

    def start(self):
        self.app.run_polling(allowed_updates=['message', 'pre_checkout_query'])

    @staticmethod
    async def send_document(user: users.TelegramUser, file, filename: str):
        bot: Bot = Bot(telegram_bot_token)
        await bot.send_document(chat_id=user.chat_id, document=file, filename=filename)

    @staticmethod
    async def send_photo(user: users.TelegramUser, file, caption: str):
        bot: Bot = Bot(telegram_bot_token)
        await bot.send_photo(chat_id=user.chat_id, photo=file, caption=caption)

    @staticmethod
    async def react(user: users.TelegramUser, message_id: int, reaction: str) -> None:
        bot: Bot = Bot(telegram_bot_token)
        await bot.setMessageReaction(
            chat_id=user.chat_id,
            message_id=message_id,
            reaction=ReactionTypeEmoji(emoji=reaction)
        )

    @staticmethod
    async def send_message(
            user: users.TelegramUser,
            text: str,
            buttons: Union[list, None],
            inline_buttons: Union[list, None] = None
    ):
        bot: Bot = Bot(telegram_bot_token)
        if buttons:
            buttons_layout = []
            for buttons_row in buttons:
                row = []
                for button in buttons_row:
                    row.append(KeyboardButton(text=button))
                buttons_layout.append(row)
            keyboard = ReplyKeyboardMarkup(buttons_layout, is_persistent=True, resize_keyboard=True)
        else:
            keyboard = ReplyKeyboardRemove() if buttons == [] else None

        if inline_buttons:
            buttons_layout = []
            for inline_row in inline_buttons:
                row = []
                for button_text, url in inline_row.items():
                    row.append(InlineKeyboardButton(text=button_text, url=url))
                buttons_layout.append(row)
            keyboard = InlineKeyboardMarkup(buttons_layout)

        max_attempts = 5
        attempt_number = 1

        while attempt_number <= max_attempts:
            try:
                message = await bot.send_message(
                    chat_id=user.chat_id,
                    text=text,
                    reply_markup=keyboard,
                    parse_mode='markdown'
                )
                return message
            except BadRequest as e:
                print(f'Unrecoverable send message exception (bad request):', e)
                return
            except BaseException as e:
                print(f'Unable to send message (attempt #{attempt_number})', e.__class__, e)
                sleep_seconds = attempt_number * attempt_number
                sleep(sleep_seconds)
                attempt_number += 1

        print(f'Unable to send message within {attempt_number} attempt(s). Giving up, sorry')

    @staticmethod
    async def send_invoice(user: users.TelegramUser, invoice: Invoice) -> None:
        bot: Bot = Bot(telegram_bot_token)
        price_cents = invoice.amount
        price_tenge = int(price_cents / 100)
        payload = {
            'invoice_id': invoice.id,
            'user_id': user.chat_id,
            'type': invoice.type
        }

        await bot.sendInvoice(
            chat_id=user.chat_id,
            title='Пожалуйста, оплатите',
            description='Первичный платеж за подписку',
            payload=json.dumps(payload),
            provider_token=robokassa_payment_token,
            currency=invoice.currency,
            prices=[
                LabeledPrice(
                    label=f'Подписка',
                    amount=price_cents
                )
            ],
            provider_data={
                "InvoiceId": invoice.id,
                "Receipt": {
                    # "sno": "osn",
                    "items": [
                        {
                            "name": "Kaspi Bot join membership",
                            "quantity": 1,
                            "amount": price_tenge,
                            "tax": "none",
                            "payment_method": "full_payment",
                            "payment_object": "commodity"
                        },
                    ],
                    "sum": price_tenge,
                    "quantity": 1,
                    "name": "Kaspi Bot join membership"
                }
            },
        )

    @staticmethod
    async def send_pre_checkout_answer(query_id: str, is_ok: bool, message: Union[str, None] = None):
        bot: Bot = Bot(telegram_bot_token)
        await bot.answer_pre_checkout_query(pre_checkout_query_id=query_id, ok=is_ok, error_message=message)

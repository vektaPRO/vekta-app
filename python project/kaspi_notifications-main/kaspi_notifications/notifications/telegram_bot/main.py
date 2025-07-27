import datetime
import json
from typing import Union

from telegram import Message, PreCheckoutQuery
from asgiref.sync import sync_to_async

from kaspi_notifications.celery import app
from notifications.billing.invoicing import create_registration_invoice
from notifications.constants import INVOICE_TYPE_REGISTRATION, INVOICE_STATUS_PAID, TELEGRAM_MODE_COMPLETE_REGISTRATION, \
    TELEGRAM_MODE_CREATE_GREEN_API_INSTANCE, GREEN_API_STATUS_STARTING, GREEN_API_STATUS_NOT_AUTHORIZED, \
    COMMUNICATION_TYPE_GREEN_API, MEMBERSHIP_STATUS_DRAFT, MEMBERSHIP_STATUS_INITIAL_INVOICE_PAID, \
    TELEGRAM_MODE_GREEN_API_INSTANCE_CREATED
from notifications.green_api import create_new_green_api_instance, generate_qr_code_to_send_to_user, get_account_status
from notifications.kaspi_api.api_requests import is_token_valid
from notifications.models import Merchant, Invoice
from notifications.telegram_bot.buttons import BUTTON_HELP, BUTTON_REGISTER, BUTTON_KASPI, BUTTON_ROBOKASSA, \
    BUTTON_QR_CODE_IS_SCANNED
from notifications.telegram_bot.long_text_messages import INSTRUCTION
from notifications.telegram_bot.telegram_bot import TelegramBot
from notifications.telegram_bot.users import TelegramUser
from notifications.utils import log


async def start_handler(bot: TelegramBot, message: Message) -> None:
    telegram_user = TelegramUser(chat_id=message.chat_id)
    await bot.send_message(telegram_user, "Добрый день.\nЯ бот, который поможет вам зарегистрироваться в iRocket.\n"
                                          "Пожалуйста,нажмите на нужную кнопку", [[BUTTON_HELP, BUTTON_REGISTER]])


async def help_handler(bot: TelegramBot, message: Message) -> None:
    log('help_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    await bot.send_message(telegram_user, INSTRUCTION, [[BUTTON_REGISTER]],
                           inline_buttons=[{'Техподдержка': 'https://wa.me/77762216363'}])


async def register_handler(bot: TelegramBot, message: Message) -> None:
    log('register_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    await bot.send_message(telegram_user, "Пожалуйста, выберите способ оплаты (нажмите на нужную кнопку)",
                           [[BUTTON_KASPI, BUTTON_ROBOKASSA]])


async def robokassa_handler(bot: TelegramBot, message: Message) -> None:
    log('robokassa_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    merchant: Union[Merchant, None] = await sync_to_async(
        Merchant.objects.filter(chat_id=telegram_user.chat_id).first)()
    if not merchant:
        merchant = await sync_to_async(Merchant.objects.create)(chat_id=telegram_user.chat_id,
                                                                membership_status=MEMBERSHIP_STATUS_DRAFT
                                                                )
    if merchant.membership_status != 'draft':
        return await bot.send_message(telegram_user, 'Already joined', [])
    invoice: Union[Invoice, None] = await sync_to_async(
        Invoice.objects.filter(merchant=merchant, type=INVOICE_TYPE_REGISTRATION).first)()
    if not invoice:
        invoice = await sync_to_async(create_registration_invoice)(merchant)

    if invoice.is_paid():
        return await bot.send_message(telegram_user, 'Already joined', [])

    await bot.send_invoice(telegram_user, invoice)


async def kaspi_payment_handler(bot: TelegramBot, message: Message) -> None:
    log('kaspi_payment_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    await bot.send_message(telegram_user,
                           'Пожалуйста, напишите нашему менеджеру в WhatsApp (кнопка "Написать в WhatsApp"), '
                           'и он поможет вам с подключением.', [],
                           inline_buttons=[{'Написать в WhatsApp': 'https://wa.me/77766176300'}])


async def initiate_green_api_authorization(merchant: Merchant) -> None:
    log('initiate_green_api_authorization')
    telegram_user = TelegramUser(chat_id=int(merchant.chat_id))
    green_api_account_status = get_account_status(merchant.green_api_instance_id, merchant.green_api_token)
    if green_api_account_status is None or green_api_account_status == GREEN_API_STATUS_STARTING:
        log('Scheduling initiate_green_api_authorization with delay')
        app.signature('kaspi_notifications.tasks.check_green_api_account_status').apply_async((merchant.id,),
                                                                                              countdown=5)
        return

    if green_api_account_status == GREEN_API_STATUS_NOT_AUTHORIZED:
        file = generate_qr_code_to_send_to_user(merchant.green_api_instance_id, merchant.green_api_token)
        await TelegramBot.send_photo(telegram_user, file, 'Отсканируйте код')
        return await TelegramBot.send_message(telegram_user,
                                              'Пожалуйста, отсканируйте QR-код через ваш аккаунт в WhatsApp для авторизации вашего аккаунта в iRocket,'
                                              'а затем нажмите кнопку "Готово" и мы проверим статус вашего аккаунта',
                                              [[BUTTON_QR_CODE_IS_SCANNED]])

    return await TelegramBot.send_message(telegram_user,
                                          'Не получилось инициализировать iRocket. Пожалуйста, обратитесь к администратору',
                                          [])


async def complete_registration_handler(bot: TelegramBot, message: Message) -> None:
    log('complete_registration_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    merchant = await sync_to_async(Merchant.objects.filter(chat_id=telegram_user.chat_id).first)()
    if merchant.name is None:
        merchant.name = message.text.strip()
        await sync_to_async(merchant.save)()
        return await bot.send_message(telegram_user, "Пожалуйста, отправьте ваш токен от Kaspi API", [])

    if merchant.kaspi_token is None:
        if not is_token_valid(merchant.name, message.text.strip()):
            return await bot.send_message(telegram_user,
                                          "Ваш токен невалидный, пожалуйста, проверьте токен и отправьте еще раз", [])
        merchant.kaspi_token = message.text.strip()
        await bot.send_message(telegram_user, 'Создаем аккаунт в iRocket.\n'
                                              'По окончанию процесса мы вышлем вам QR-код для авторизации.\n'
                                              'Процесс может занять до 5 минут, пожалуйста, дождитесь QR-кода.', [])
        merchant.telegram_mode = TELEGRAM_MODE_CREATE_GREEN_API_INSTANCE
        green_api_instance_data = create_new_green_api_instance()
        merchant.green_api_instance_id = green_api_instance_data['idInstance']
        merchant.green_api_token = green_api_instance_data['apiTokenInstance']
        merchant.communication_type = COMMUNICATION_TYPE_GREEN_API
        await sync_to_async(merchant.save)()
        await initiate_green_api_authorization(merchant)


async def check_green_api_account_status(bot: TelegramBot, message: Message) -> None:
    log('check_green_api_account_status')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    merchant = await sync_to_async(Merchant.objects.filter(chat_id=telegram_user.chat_id).first)()
    green_api_account_status = get_account_status(merchant.green_api_instance_id, merchant.green_api_token)
    if green_api_account_status == GREEN_API_STATUS_NOT_AUTHORIZED:
        file = generate_qr_code_to_send_to_user(merchant.green_api_instance_id, merchant.green_api_token)
        await bot.send_photo(telegram_user, file, 'Отсканируйте код')
        return await bot.send_message(telegram_user,
                                      'Пожалуйста, отсканируйте новый QR-код, а затем нажмите кнопку "Готово", '
                                      'и мы проверим статус вашего аккаунта',
                                      [[BUTTON_QR_CODE_IS_SCANNED]])
    merchant.enabled = True
    merchant.subscription_date_start = datetime.datetime.today().date()
    merchant.subscription_days = 30
    merchant.telegram_mode = TELEGRAM_MODE_GREEN_API_INSTANCE_CREATED
    await sync_to_async(merchant.save)()
    return await bot.send_message(telegram_user, "Поздравляю с успешной регистрацией в iRocket.\n"
                                                 "Теперь вы можете отправлять сообщения своим клиентам.", [])


async def common_message_handler(bot: TelegramBot, message: Message) -> None:
    log('common_message_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    merchant = await sync_to_async(Merchant.objects.filter(chat_id=telegram_user.chat_id).first)()
    try:
        if merchant:
            if merchant.telegram_mode == TELEGRAM_MODE_COMPLETE_REGISTRATION:
                return await complete_registration_handler(bot, message)
            if merchant.telegram_mode == TELEGRAM_MODE_CREATE_GREEN_API_INSTANCE:
                return await check_green_api_account_status(bot, message)
        if message.text == BUTTON_HELP:
            return await help_handler(bot, message)
        if message.text == BUTTON_REGISTER:
            return await register_handler(bot, message)
        if message.text == BUTTON_KASPI:
            return await kaspi_payment_handler(bot, message)
        if message.text == BUTTON_ROBOKASSA:
            return await robokassa_handler(bot, message)
        return await start_handler(bot, message)
    except BaseException as e:
        log(e)


async def successful_payment_handler(bot: TelegramBot, message: Message) -> None:
    log('successful_payment_handler')
    telegram_user = TelegramUser(chat_id=message.chat_id)
    merchant = await sync_to_async(Merchant.objects.filter(chat_id=telegram_user.chat_id).first)()
    merchant.membership_status = MEMBERSHIP_STATUS_INITIAL_INVOICE_PAID
    merchant.telegram_mode = TELEGRAM_MODE_COMPLETE_REGISTRATION
    await sync_to_async(merchant.save)()
    invoice = await sync_to_async(Invoice.objects.filter(merchant=merchant, type=INVOICE_TYPE_REGISTRATION).first)()
    invoice.status = INVOICE_STATUS_PAID
    await sync_to_async(invoice.save)()
    await bot.send_message(telegram_user, 'Ваш платеж прошел успешно! Пожалуйста, напишите название вашего магазина.',
                           [])


async def pre_checkout_handler(bot: TelegramBot, pre_checkout_query: PreCheckoutQuery) -> None:
    log('pre_checkout_handler')
    currency = pre_checkout_query.currency
    invoice_payload = json.loads(pre_checkout_query.invoice_payload)
    user_id = invoice_payload['user_id']
    invoice_id = invoice_payload['invoice_id']
    total_amount = pre_checkout_query.total_amount
    merchant = await sync_to_async(Merchant.objects.filter(chat_id=user_id).first)()
    invoice: Union[Invoice, None] = await sync_to_async(Invoice.objects.filter(pk=invoice_id).prefetch_related('merchant').first)()
    if not merchant:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Unregistered merchant payment attempt')
    if not invoice:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Invoice not found in system')
    if not invoice.is_draft():
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Invoice is already paid')
    if invoice.merchant != merchant:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Unexpected merchant')
    if merchant.membership_status != 'draft':
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Merchant is already joined')
    if currency != invoice.currency:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Invoice currency mismatch')
    if user_id != pre_checkout_query.from_user.id:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Invoice user mismatch')
    if invoice.type != INVOICE_TYPE_REGISTRATION:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Invoice type mismatch')
    if total_amount != invoice.amount:
        return await bot.send_pre_checkout_answer(pre_checkout_query.id, False, 'Invoice amount mismatch')

    await bot.send_pre_checkout_answer(pre_checkout_query.id, True)


def run_bot_dispatcher():
    log('Bot started')
    bot: TelegramBot = TelegramBot()
    bot = bot.with_message_handler(common_message_handler)
    bot = bot.with_pre_checkout_handler(pre_checkout_handler)
    bot = bot.with_successful_payment_handler(successful_payment_handler)
    bot = bot.with_command_handler('start', start_handler)
    bot.start()

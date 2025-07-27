import json
import os
import logging
from typing import Union
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from dotenv import load_dotenv

from pktools.helpers import time_it_and_log
from . import constants
from .green_api import send_message_through_green_api
from .hand_do_functions import get_kaspi_new_orders
from .kaspi_api.api_requests import confirm_new_order
from .models import KaspiNewOrder, Merchant, OrderProduct
from .order_storage import Orders
from .greenapi_instance_functions import retrieve_qr_code_for_instance_authorization_green_api
from .utils import get_client_ip, validate_message_of_client, greeting
from .whatsapp_functions import parse_whatsapp_data, send_message


load_dotenv()
logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


@csrf_exempt
@time_it_and_log
def reply(request):
    if (request.method == 'GET' and request.GET.get('hub.mode') == 'subscribe'
            and request.GET.get('hub.verify_token') == 'SHAREX07678'):
        return HttpResponse(request.GET['hub.challenge'])
    try:
        number, text, interactive_reply, whatsapp_phone_id = parse_whatsapp_data(request)
        extra = {'number': number, 'interactive_reply': interactive_reply, 'phone_id': whatsapp_phone_id,
                 'text': text}

        logger.info('whatsapp_functions.reply:started', extra=extra)
    except KeyError as e:
        logger.error(f'whatsapp_functions.reply:some KeyError occurred = {str(e)}')
        return HttpResponse('OK')

    order_storage = Orders()

    merchant = Merchant.objects.filter(whatsapp_id=whatsapp_phone_id).first()

    if not text and not interactive_reply:
        send_message(f'Уважаемый клиент!\nДанный чат предназначен для информирования о статусе заказа.\n'
                     f'Написать менеджеру – https://wa.me/{merchant.manager_whatsapp_number}', number,
                     merchant.whatsapp_id,
                     merchant.whatsapp_token)
        logger.info(f'whatsapp_functions.reply:not text or not interactive reply, merchant :: {merchant.name}', extra=extra)
        return HttpResponse('OK')

    if not interactive_reply:
        send_message(f'Уважаемый клиент!\nДанный чат предназначен для информирования о статусе заказа.\n'
                     f'Написать менеджеру – https://wa.me/{merchant.manager_whatsapp_number}', number,
                     merchant.whatsapp_id,
                     merchant.whatsapp_token)
        logger.info(f'whatsapp_functions.reply:not interactive reply, merchant :: {merchant.name}',
                    extra=extra)
        return HttpResponse('OK')

    if interactive_reply:
        order_id = interactive_reply['id'].split('_')[-1]
        order: Union[KaspiNewOrder, None] = order_storage.get_new_order_by_id(order_id)
        if not order:
            logger.error('whatsapp_functions.reply:no order found', extra={'number': number, 'phone_id': whatsapp_phone_id,
                                                                    'merchant': merchant.name})
            return HttpResponse()

        logger.error('whatsapp_functions.reply:message is being processed', extra={'number': number, 'phone_id': whatsapp_phone_id,
                                                                       'merchant': merchant.name, 'order': order_id})
        whatsapp_token = order.merchant.whatsapp_token
        whatsapp_id = order.merchant.whatsapp_id

        if 'not' in interactive_reply['id']:
            if order.order_status == constants.STATUS_ORDER_WAS_AUTO_ACCEPTED_IN_KASPI:
                send_message('К сожалению, мы не дождались от вас ответа и приняли товар.\n'
                             'Если вы всё также хотите отменить заказ - вы можете позвонить нам, либо сделать это '
                             'самостоятельно в приложении Kaspi.kz', number, whatsapp_id,
                             whatsapp_token)
            else:
                send_message('Спасибо за ответ, c вами свяжется наш менеджер для уточнения вашего запроса',
                             number, whatsapp_id, whatsapp_token)

                order_storage.change_new_order_status(constants.STATUS_WAS_CANCELLED, order_id)
                order_storage.save_new_order_client_answer('Заказ отменен', order_id)

        else:
            send_message('Спасибо за ответ, ваш заказ был подтвержден', number, whatsapp_id,
                         whatsapp_token)

            confirm_new_order(order_id, order.kaspi_order_code, order.merchant.kaspi_token)
            order_storage.change_new_order_status(constants.STATUS_ORDER_WAS_CONFIRMED, order_id)
            order_storage.save_new_order_client_answer('Заказ подтвержден', order_id)

    logger.info('whatsapp_functions.reply:finished', extra={'number': number, 'phone_id': whatsapp_phone_id,
                 'merchant': merchant.name})
    return HttpResponse('OK')


def get_qr_code_green_api_html_render(request, uid):
    merchant = Merchant.objects.filter(uid=uid).first()
    extra = {'merchant': merchant.name, 'instance_id': merchant.green_api_instance_id}
    if merchant:
        message = retrieve_qr_code_for_instance_authorization_green_api(merchant.green_api_instance_id,
                                                                        merchant.green_api_token)
        logger.info(f'get_qr_code_green_api_html_render::message of  base64 name = {message[:5]}',
                              extra=extra)
    else:
        message = "error"
        logger.error('get_qr_code_green_api_html_render:: merchant is not found', extra=extra)
    return render(request, 'qr_code_template.html', {'message': message})


@csrf_exempt
@login_required
def get_kaspi_new_orders_view(request):
    if request.method == 'POST':
        merchant_id = request.POST.get('merchant_id')
        order_date_str = request.POST.get('order_date_str')
        first_message_delivery_status = request.POST.get('first_message_delivery_status')

        # Call the function to process orders
        get_kaspi_new_orders(merchant_id, order_date_str, first_message_delivery_status)

        # Prepare a message to pass to the template
        completion_message = "Processing of new orders completed."

        # Return the completion message along with the template
        return render(request, 'resend_message.html', {'completion_message': completion_message})
    else:
        return render(request, 'resend_message.html')


@csrf_exempt
@require_http_methods(["GET", "POST"])
@time_it_and_log
def webhook(request, uid):
    auth_token = os.getenv("GREEN_API_TOKEN")
    auth_header = request.headers.get('Authorization')
    if auth_header != f'Bearer {auth_token}':
        logger.error(f"webhook::Unauthorized request from {get_client_ip(request)}")
        return HttpResponse('Forbidden', status=403)

    merchant = Merchant.objects.get(uid=uid)
    order_storage = Orders()
    if not merchant:
        logger.error(f"webhook::Merchant not found", extra={'uid': uid})
        return HttpResponse('Merchant not found', status=200)

    extra = {'merchant': merchant.name, 'creation_date': merchant.creation_date, 'instance_id': merchant.green_api_instance_id}
    if request.method == 'GET':
        logger.error("GET method not allowed", extra=extra)
        return HttpResponse('GET method not allowed', status=400)

    try:
        data = json.loads(request.body)
        if data.get('typeWebhook', '') != 'incomingMessageReceived':
            logger.error(f'webhook::No incoming message, type = {data.get("typeWebhook")}', extra=extra)
            return JsonResponse({"status": "error", "message": "No incoming message"}, status=200)
        if data.get('messageData', {}).get('typeMessage') in ['extendedTextMessage', 'textMessage']:
            phone_number = data['senderData']['sender'].split('@')[0]
            message_response = data.get('messageData', '').get('textMessageData', {}).get('textMessage', '')
            if not message_response:
                message_response = data.get('messageData', '').get('extendedTextMessageData', {}).get('text', '')

            if not message_response:
                logger.error(f'No message response, type = {data.get("messageData", {}).get("typeMessage")}',
                                       extra=extra)
                return JsonResponse({"status": "error", "message": "No message response"}, status=200)
            order = KaspiNewOrder.objects.filter(merchant=merchant, phone_number=phone_number[1:],
                                                 notification_status='need_client_to_answer').last()
            logger.info(f'webhook:: processing client message', extra={'merchant': merchant.name,
                                                                                 'phone_number': phone_number,
                                                                                 'message_response': message_response,
                                                                                 'order': order})
            if not order:
                logger.error(f'webhook:: processing client message - no order code',
                                       extra={'merchant': merchant.name,
                                              'phone_number': phone_number,
                                              'message_response': message_response})

                return JsonResponse({"status": "error", "message": "No order code"}, status=200)

            validated_message = validate_message_of_client(message_response)

            extra.update(
                {
                    'order_code': order.kaspi_order_code,
                }
            )
            if validated_message == '0':
                logger.error(f'webhook:: processing client message - Green Api Review answer is not digit',
                                       extra={'merchant': merchant.name,
                                              'phone_number': phone_number,
                                              'message_response': message_response})
                message = "Өтініш тек 1 немесе 2 санын жіберіңіз. \n\n🔸🔸🔸\n\n Пожалуйста, отправьте только цифру 1 или 2."
                order.notification_status = constants.STATUS_CLIENT_NEED_ANSWER
            elif validated_message == '2':
                message = (f'Кешіріңіз, {order.full_name.split(" ")[1]}!\n'
                           f'Сізге ұнамағанына өкінеміз.\n'
                           f'Бізге не ұнамағанын жазсаңыз, біз оны түзетуге тырысамыз.\n'
                           f'Сіздің пікіріңіз біз үшін маңызды. \n\n🔸🔸🔸\n\n'
                           f'Извините, {order.full_name.split(" ")[1]}!\n'
                           f'Нам жаль, что вам не понравилось.\n'
                           f'Пожалуйста, сообщите нам, что именно не так, чтобы мы могли это исправить.\n'
                           f'Ваше мнение очень важно для нас.')

                template = order.merchant.green_api_message_text_for_negative_review
                if template:
                    try:
                        format_dict = {
                            "client_name": {order.full_name.split(" ")[1]},
                            "kaspi_order_code": order.kaspi_order_code,
                        }

                        if "{hello_rus}" in template:
                            format_dict["hello_rus"] = greeting(True)
                        if "{hello_kaz}" in template:
                            format_dict["hello_kaz"] = greeting(False)
                        message = template.format(**format_dict)
                        message = message.replace("\\n", "\n")

                    except KeyError:
                        logger.exception(f"webhook::Error formatting message for negative review", extra=extra)

                order.notification_status = constants.STATUS_CLIENT_NOT_TO_BE_NOTIFIED
                logger.info(f'webhook:: processing client message - Green Api Review answer is negative',
                                       extra={'merchant': merchant.name,
                                              'phone_number': phone_number,
                                              'message_response': message_response})
            else:
                products = OrderProduct.objects.filter(order=order).all()
                product_links = [
                    f'https://kaspi.kz/shop/review/productreview?orderCode={order.kaspi_order_code}&productCode={product.product_mastercode}&rating=5'
                    for product in products]

                if order.merchant.green_api_message_text_for_review:
                    template = order.merchant.green_api_message_text_for_review
                    try:
                        format_dict = {
                            "client_name": order.full_name.split(" ")[1],
                            "products_urls": ", ".join(product_links)
                        }

                        if "{hello_rus}" in template:
                            format_dict["hello_rus"] = greeting(True)
                        if "{hello_kaz}" in template:
                            format_dict["hello_kaz"] = greeting(False)

                        message = template.format(**format_dict)
                        message = message.replace("\\n", "\n")
                    except KeyError as e:
                        message = f'{greeting(True)}, {order.full_name.split(" ")[1]}!\nПоздравляем с покупкой с магазина {order.merchant.name}!\n' \
                                  f'Мы надеемся, что вам все понравилось.\nЕсли вам не сложно, пожалуйста оставьте отзыв *с указанием названия нашего магазина* перейдя по ссылке⤵️:\n' \
                                  f'{", ".join(product_links)}\n' \
                                  f'Чтобы ссылка стала активной, напишите пожалуйста что-нибудь в ответ.'
                        logger.error(f"webhook::Error formatting message: order code 2 = {order.kaspi_order_code}, error = {e}")
                else:
                    message = (
                        f'Барлығы ұнағанына қуаныштымыз.\n'
                        f'Егер қиын болмаса, осында пікір қалдырыңыз:\n'
                        f'{", ".join(product_links)}'
                        f'\nСізге жақсы күн тілейміз! \n\n🔸🔸🔸\n\n'
                        f'Мы рады, что вам всё понравилось.\n'
                        f'Если вам не сложно, то оставьте отзыв здесь:\n'
                        f'{", ".join(product_links)}'
                        f'\nЖелаем вам хорошего дня!')
                order.notification_status = constants.STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT

            order.save()
            send_message_through_green_api(phone_number, message,
                                           order.merchant.green_api_instance_id,
                                           order.merchant.green_api_token)
            order_storage.change_order_review_delivery_status(constants.MESSAGE_IS_DELIVERED,
                                                              order.kaspi_order_id)
            logger.info(f'webhook:message received',
                                  extra={'merchant': merchant.name,
                                         'phone_number': phone_number,
                                         'message_response': message_response,
                                         'order': order})

            return JsonResponse({"status": "done"}, status=200)
        else:
            logger.error(f'webhook::No text message, type = {data.get("messageData", {}).get("typeMessage")}',
                                   extra={'merchant': merchant.name})
            return JsonResponse({"status": "error", "message": "No text message"}, status=200)
    except json.JSONDecodeError as e:
        logger.error(f"webhook::Invalid JSON, error = {e}", extra={'merchant': merchant.name})
        return JsonResponse({"status": "error", "message": "Invalid JSON"}, status=200)

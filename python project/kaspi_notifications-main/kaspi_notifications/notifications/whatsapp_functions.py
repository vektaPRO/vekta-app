import requests
import json
import logging
from django.conf import settings

from . import constants


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


def send_template_message_about_new_order(phone_number, client_name, product_name, order_code, button_name_yes, button_name_no,
                          order_id, planned_delivery_date, whatsapp_id, whatsapp_token, template_name=None):
    extra = {'phone_number': phone_number, 'order': order_code, 'whatsapp_id': whatsapp_id}
    from_number_id = whatsapp_id
    token = whatsapp_token
    url = f'https://graph.facebook.com/v18.0/{from_number_id}/messages'
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

    body = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": phone_number,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {
                "code": "ru"
            },
            "components": [
                {
                    "type": "header",
                    "parameters": [
                        {
                            "type": "text",
                            "text": client_name
                        }
                    ]
                },
                {
                    "type": "body",
                    "parameters": [
                        {
                            "type": "text",
                            "text": product_name
                        },
                        {
                            "type": "text",
                            "text": order_code
                        },
                        {
                            "type": "text",
                            "text": planned_delivery_date
                        }
                    ]
                },
                {
                    "type": "button",
                    "sub_type": "quick_reply",
                    "index": "0",
                    "parameters": [
                        {
                            "type": "payload",
                            "payload": button_name_yes + order_id
                        }
                    ]
                },
                {
                    "type": "button",
                    "sub_type": "quick_reply",
                    "index": "1",
                    "parameters": [
                        {
                            "type": "payload",
                            "payload": button_name_no + order_id
                        }
                    ]
                },
            ]
        }
    }
    response = requests.post(url=url, data=json.dumps(body), headers=headers)

    if 'error' in response.json():
        if response.json()['error']['code'] == 131026:
            message_status = constants.CLIENT_WITHOUT_WHATSAPP
            logger.error(f'send_template_message_about_new_order:: client does not have whatsapp, response={response.json()}',
                         extra=extra)
        else:
            message_status = constants.ERROR_WHILE_DELIVERING_MESSAGE
            logger.error(
                f'send_template_message_about_new_order:: error while delivering message, response={response.json()}',
                extra=extra)
    else:
        message_status = constants.MESSAGE_IS_DELIVERED
        # message_status = constants.MESSAGE_IS_DELIVERED if response.json()['messages'][0][
        #                                                        'message_status'] == 'accepted' else constants.MESSAGE_IS_NOT_DELIVERED
        logger.info(
            f'send_template_message_about_new_order:: message delivered through WhatsApp, response={response.json()}',
            extra=extra)

    return message_status


def send_template_message_about_new_order_without_buttons(phone_number, client_name, product_name, order_code,
                                                          planned_delivery_date, whatsapp_id, whatsapp_token,
                                                          template_name=None):
    extra = {'phone_number': phone_number, 'order': order_code, 'whatsapp_id': whatsapp_id}
    from_number_id = whatsapp_id
    token = whatsapp_token
    url = f'https://graph.facebook.com/v18.0/{from_number_id}/messages'
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

    body = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": phone_number,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {
                "code": "ru"
            },
            "components": [
                {
                    "type": "header",
                    "parameters": [
                        {
                            "type": "text",
                            "text": client_name
                        }
                    ]
                },
                {
                    "type": "body",
                    "parameters": [
                        {
                            "type": "text",
                            "text": product_name
                        },
                        {
                            "type": "text",
                            "text": order_code
                        },
                        {
                            "type": "text",
                            "text": planned_delivery_date
                        }
                    ]
                }
            ]
        }
    }
    response = requests.post(url=url, data=json.dumps(body), headers=headers)

    if 'error' in response.json():
        if response.json()['error']['code'] == 131026:
            message_status = constants.CLIENT_WITHOUT_WHATSAPP
            logger.error(
                f'send_template_message_about_new_order_without_buttons:: client does not have whatsapp, response={response.json()}',
                extra=extra)
        else:
            message_status = constants.ERROR_WHILE_DELIVERING_MESSAGE
            logger.error(
                f'send_template_message_about_new_order_without_buttons:: error while delivering message, response={response.json()}',
                extra=extra)
    else:
        message_status = constants.MESSAGE_IS_DELIVERED
        # message_status = constants.MESSAGE_IS_DELIVERED if response.json()['messages'][0]['message_status'] == 'accepted' else constants.MESSAGE_IS_NOT_DELIVERED
        logger.info(
            f'send_template_message_about_new_order_without_buttons:: message delivered through WhatsApp, response={response.json()}',
            extra=extra)

    return message_status


def send_template_message_for_reviews(phone_number, client_name, product_link, whatsapp_id, whatsapp_token, template_name=None):
    extra = {'phone_number': phone_number, 'whatsapp_id': whatsapp_id}
    from_number_id = whatsapp_id
    token = whatsapp_token
    url = f'https://graph.facebook.com/v18.0/{from_number_id}/messages'
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

    body = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": phone_number,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {
                "code": "ru"
            },
            "components": [
                {
                    "type": "header",
                    "parameters": [
                        {
                            "type": "text",
                            "text": client_name
                        }
                    ]
                },
                {
                    "type": "body",
                    "parameters": [
                        {
                            "type": "text",
                            "text": product_link
                        },
                    ]
                }
            ]
        }
    }
    response = requests.post(url=url, data=json.dumps(body), headers=headers)

    if 'error' in response.json():
        if response.json()['error']['code'] == 131026:
            message_status = constants.CLIENT_WITHOUT_WHATSAPP
            logger.error(
                f'send_template_message_for_reviews:: client does not have whatsapp, response={response.json()}',
                extra=extra)
        else:
            message_status = constants.ERROR_WHILE_DELIVERING_MESSAGE
            logger.error(
                f'send_template_message_for_reviews:: error while delivering message, response={response.json()}',
                extra=extra)
    else:
        message_status = constants.MESSAGE_IS_DELIVERED
        # message_status = constants.MESSAGE_IS_DELIVERED if response.json()['messages'][0]['message_status'] == 'accepted' else constants.MESSAGE_IS_NOT_DELIVERED
        logger.info(
            f'send_template_message_for_reviews:: message delivered through WhatsApp, response={response.json()}',
            extra=extra)

    return message_status


def parse_whatsapp_data(request):
    request_data = json.loads(request.body.decode('utf-8'))
    whatsapp_phone_id = request_data['entry'][0]['changes'][0]['value']['metadata']['phone_number_id']
    reply_message = request_data['entry'][0]['changes'][0]['value']['messages'][0]
    number = reply_message['from']
    text = None
    interactive_reply = None

    extra = {'phone_number': number, 'whatsapp_id': whatsapp_phone_id, 'reply_message': reply_message}

    try:
        reply_type = reply_message['interactive']['type']
        interactive_reply = reply_message['interactive'][reply_type]
    except KeyError as e:
        logger.error(
            f'parse_whatsapp_data:: KeyError while parsing message, error={e}',
            extra=extra)

    try:
        interactive_reply = {'id': reply_message['button']['payload']}
    except KeyError as e:
        logger.error(
            f'parse_whatsapp_data:: KeyError while parsing message, error={e}',
            extra=extra)

    try:
        text = reply_message['text']['body']
    except KeyError as e:
        logger.error(
            f'parse_whatsapp_data:: KeyError while parsing message, error={e}',
            extra=extra)

    logger.info(
        'parse_whatsapp_data:: message was parsed',
        extra=extra)

    return number, text, interactive_reply, whatsapp_phone_id


def send_message(message, number, whatsapp_id, whatsapp_token):
    extra = {'phone_number': number, 'whatsapp_id': whatsapp_id, 'message': message}
    logger.info('send_message::sending message started', extra=extra)
    from_number_id = whatsapp_id
    token = whatsapp_token
    url = f'https://graph.facebook.com/v17.0/{from_number_id}/messages'
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    body = message if type(message) is dict else {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": number,
        "type": "text",
        "text": {
            "preview_url": False,
            "body": message
        }}
    response = requests.post(url=url, data=json.dumps(body), headers=headers)
    logger.info(f'send_message::sending message finished, Whatsapp Api response = {response.json()}', extra=extra)

    return response.json()

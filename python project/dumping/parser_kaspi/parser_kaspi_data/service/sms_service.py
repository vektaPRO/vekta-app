import requests
from django.conf import settings

from parser_kaspi_data.service import project_logger

logger = project_logger.get_logger(__name__)

# Define WhatsApp service API endpoint URLs from settings
WHATSAPP_CREATE_URL = settings.WHATSAPP_CREATE_URL
WHATSAPP_VERIFY_URL = settings.WHATSAPP_VERIFY_URL
WHATSAPP_AUTH_TOKEN = settings.WHATSAPP_AUTH_TOKEN


def send_verification_code(phone_number):
    try:
        payload = {
            'phone_number': phone_number,
        }

        headers = {
            'Authorization': 'Bearer ' + WHATSAPP_AUTH_TOKEN,
            'Content-Type': 'application/json',
        }

        response = requests.post(WHATSAPP_CREATE_URL, json=payload, headers=headers)
        response.raise_for_status()

        logger.info(f"Verification code  sent successfully to {phone_number}")
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send verification code to {phone_number}: {project_logger.format_exception(e)}")
        return {'error': 'Failed to send verification code'}


def verify_code(uid, code):
    try:
        payload = {
            'uid': uid,
            'code': code,
        }
        headers = {
            'Authorization': 'Bearer ' + WHATSAPP_AUTH_TOKEN,
            'Content-Type': 'application/json',
        }

        response = requests.post(WHATSAPP_VERIFY_URL, json=payload, headers=headers)
        response.raise_for_status()
        logger.info(f"WhatsApp code verified successfully for UID {uid}")
        return response
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to verify WhatsApp code for UID {uid}: {project_logger.format_exception(e)}")
        return {'error': 'Failed to verify WhatsApp code'}
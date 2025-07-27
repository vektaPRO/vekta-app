import logging
import re
import httpx
import requests

from django.conf import settings
from parser_kaspi_data.project_decorators import http_retry_decorator
from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.project_exceptions import RetryableHttpClientException, KaspiCabinetSmsSendingException, \
    SmsVerificationFailedException, KaspiUserCreationFailedException
from parser_kaspi_data.service.project_logger import log_traffic
from parser_kaspi_data.service.proxy_manager import ProxyProvider

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)

HEADERS = {
    'Accept': 'application/json, text/*',
    'User-Agent': ('Mozilla/5.0 (iPhone; CPU iPhone OS 15_3 '
                   'like Mac OS X) AppleWebKit/605.1.15 '
                   '(KHTML, like Gecko) CriOS/98.0.4758.85 '
                   'Mobile/15E148 Safari/604.1'),
    'Content-Type': 'application/json; charset=UTF-8',
    'Cookie': 'ks.tg=105;',
    'Origin': 'https://kaspi.kz',
    'Referer': "https://kaspi.kz/shop/p/"
}

COMMON_HEADERS = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Encoding": "gzip, deflate, br",
    "Accept-Language": "en-GB,en;q=0.9,ru-KZ;q=0.8,ru;q=0.7,de-DE;q=0.6,de;q=0.5,ru-RU;q=0.4,en-US;q=0.3",
    "Connection": "keep-alive",
    "Content-Type": "application/x-www-form-urlencoded",
    "Host": "kaspi.kz",
    "Origin": "https://kaspi.kz",
    "Referer": "https://kaspi.kz/mc/",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-origin",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "X-Src": "desk",
    "sec-ch-ua": '"Not.A/Brand";v="8", "Chromium";v="114", "Google Chrome";v="114"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "Linux",
}


@http_retry_decorator(retries=3)
async def get_competitors_data(sku: int, city, proxy_provider: ProxyProvider, uid: str):
    async with httpx.AsyncClient(proxy=proxy_provider.get_proxy(), headers=HEADERS, timeout=httpx.Timeout(8.0, read=None),
                                 verify=False, cookies={'is_mobile_app': 'true'}) as client:
        try:
            """ Method to retrieve competitors prices """
            data = {"cityId": city, "limit": 3, "sort": "true", "installationId": "-1"}
            logger.info(f'Parsing sku {sku} offers', extra={'uid': uid})
            offers_response = await client.post(f'https://kaspi.kz/yml/offer-view/offers/{sku}', json=data)
            offers_response.raise_for_status()
            offers = offers_response.json().get("offers", [])

            log_traffic('get_competitors_data', offers_response, uid=uid)

        except httpx.HTTPStatusError as e:
            if e.response.status_code == 403:
                logger.error(f'Forbidden error for SKU {sku}', extra={'uid': uid})
                raise RetryableHttpClientException
            if e.response.status_code == 405:
                logger.error(f'Method not allowed error for SKU {sku}', extra={'uid': uid})
                raise RetryableHttpClientException
            logger.error(f'HTTPStatusError for SKU {sku}: {e}', extra={'uid': uid})
            logger.error(project_logger.format_exception(e))
            raise e

        except httpx.TimeoutException as e:
            logger.error(f'TimeoutException for SKU {sku}', extra={'uid': uid})
            logger.error(project_logger.format_exception(e))
            raise RetryableHttpClientException

        except httpx.ProxyError as e:
            logger.error(f'ProxyError for SKU {sku}', extra={'uid': uid})
            logger.error(project_logger.format_exception(e))
            raise RetryableHttpClientException

        except httpx.RequestError as e:
            logger.exception(f'Error during request for SKU {sku}', extra={'uid': uid})
            logger.error(project_logger.format_exception(e))
            raise RetryableHttpClientException

        except httpx.RemoteProtocolError as e:
            logger.exception(f'Error during request for SKU {sku}', extra={'uid': uid})
            logger.error(project_logger.format_exception(e))
            raise RetryableHttpClientException

    return {'offers': offers}


def get_session_id(response):
    regex = r"X-Mc-Api-Session-Id=([^;]*);"
    session_id = re.findall(regex, response.headers['Set-Cookie'], re.MULTILINE)[0]
    return session_id


def get_ngs(response):
    regex = r"ks.ngs.m=([^;]*);"
    ngs = re.findall(regex, response.headers['Set-Cookie'], re.MULTILINE)[0]
    return ngs


def request_sms_verification_code_to_login_in_kaspi(phone_number):
    """ Method to send sms verification from kaspi cabinet to a client to initialize login in kaspi cabinet"""
    response = requests.post('https://kaspi.kz/mc/api/sendLoginSecurityCode',
                             data={'phone': phone_number},
                             headers=COMMON_HEADERS)
    if response.status_code != 200:
        logger.info(f'Some errors occurred while sending sms to a client for verification, '
                    f'status_code :: {response.status_code}'
                    f'text :: {response.text}'
                    )
        raise KaspiCabinetSmsSendingException

    session_id = get_session_id(response)
    ngs = get_ngs(response)

    return session_id, ngs


def verify_kaspi_cabinet_login_security_code(security_code, session_id, ngs):
    """ Method to verify security code sent to a client number from kaspi cabinet """
    headers = {
        'Cookie': f'X-Mc-Api-Session-Id={session_id};ks.ngs.m={ngs}',
        'Accept': '*/*',
        'User-Agent': 'PostmanRuntime/7.32.3'
    }
    response = requests.post('https://kaspi.kz/mc/api/loginSecurityCode',
                             data={'securityCode': security_code},
                             headers=headers)
    try:
        response_data = response.json()
    except:
        response_data = []

    if response.status_code != 200 or 'errorCode' in response_data:
        logger.info(f'Some errors occurred while verifying sms security code,'
                    f'status_code :: {response.status_code}, response :: {response_data}'
                    )
        raise SmsVerificationFailedException

    return get_session_id(response)


def create_new_user_and_send_password_to_email(session_id, email, user_name, phone,  kaspi_merchant_id):
    """ Method to create new user from kaspi cabinet with email and send password to this email """
    url = 'https://mc.shop.kaspi.kz/user-assignments/api/v1/mc/users/add-email'
    headers = {
        'Cookie': f'X-Mc-Api-Session-Id={session_id};',
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
    }

    data = {"name": user_name, "email": email, "cityId": None,
            "roles": ["ACCEPT_ORDER_PICKUP", "COMPLETE_ORDER_PICKUP", "ACCEPT_ORDER_DELIVERY",
                      "COMPLETE_ORDER_DELIVERY",
                      "ACCEPT_KASPI_DELIVERY_ORDER", "RETURN_ORDER", "KASPI_DELIVERY_RETURN", "MANAGE_OFFERS",
                      "MANAGE_QUALITY_CONTROL", "DOWNLOAD_ACTIVE_ARCHIVE_ORDERS", "KASPI_MARKETING"], "pointName": None,
            "contactPhone": str(phone), "merchantUid": str(kaspi_merchant_id)}

    response = requests.post(url=url, json=data, headers=headers)

    logger.info(f'create_new_user_and_send_password_to_email response :: {response}')

    try:
        response_data = response.json()
    except:
        response_data = []

    if response.status_code != 200 or 'errorCode' in response_data:
        logger.info(f'Some errors occurred while creating new user with email from kaspi cabinet,'
                    f'status_code :: {response.status_code}, response :: {response_data}'
                    )
        raise KaspiUserCreationFailedException

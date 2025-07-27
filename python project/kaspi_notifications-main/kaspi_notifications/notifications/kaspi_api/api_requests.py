import datetime
import json
import logging
from django.conf import settings

from dotenv import load_dotenv
import requests
from requests.exceptions import Timeout, RequestException
import time
from ..utils import convert_datetime_to_milliseconds

load_dotenv()

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


def get_headers(kaspi_token):
    return {
        'Accept': 'application/vnd.api+json',
        'X-Auth-Token': kaspi_token,  # os.getenv('KASPI_TOKEN'),
        'User-Agent': 'KaspiBot'
    }


def get_headers_with_uid(kaspi_token, kaspi_shop_uid):
    return {
        'Accept': 'application/vnd.api+json',
        'X-Auth-Token': kaspi_token,
        'X-Merchant-Uid': kaspi_shop_uid,
        'User-Agent': 'KaspiBot'
    }


def is_token_valid(merchant_name: str, kaspi_token: str, kaspi_shop_uid:str) -> bool:
    orders_from_date = convert_datetime_to_milliseconds(datetime.datetime.now() - datetime.timedelta(days=1))
    orders_to_date = convert_datetime_to_milliseconds(datetime.datetime.now())
    headers = get_headers_with_uid(kaspi_token, kaspi_shop_uid) if kaspi_shop_uid else get_headers(kaspi_token)

    data = {
        'page[number]': 1,
        'page[size]': 1,
        'filter[orders][state]': 'DELIVERY',
        'filter[orders][status]': 'ACCEPTED_BY_MERCHANT',
        'filter[orders][creationDate][$ge]': orders_from_date,
        'filter[orders][creationDate][$le]': orders_to_date,
    }
    url = 'https://kaspi.kz/shop/api/v2/orders'
    response = requests.get(url=url, params=data, headers=headers)

    logger.info('kaspi_api_requests::is_token_valid - validating token',
                        extra={
                            'merchant': merchant_name,
                            'kaspi_token': kaspi_token[:5],
                            'response_status_code': response.status_code
                        }
                        )

    return response.status_code == 200


def get_orders_general_info(page_size, order_state, order_status, date_start, date_finish, kaspi_token, kaspi_shop_uid,
                            max_retries=5, timeout=20, backoff_factor=0.5):
    """ Method to get information of all orders in section "order_state" between "date_start" and "date_finish" """

    response_info = []
    page = 0

    extra = {
        'kaspi_shop': kaspi_shop_uid,
        'order_state': order_state,
        'order_status': order_status,
        'date_start': date_start,
        'date_end': date_finish
    }

    for attempt in range(max_retries):
        try:
            while True:
                data = {
                    'page[number]': page,
                    'page[size]': page_size,
                    'filter[orders][state]': order_state,
                    'filter[orders][status]': order_status,
                    'filter[orders][creationDate][$ge]': date_start,
                    'filter[orders][creationDate][$le]': date_finish,
                }
                url = 'https://kaspi.kz/shop/api/v2/orders'
                headers = get_headers_with_uid(kaspi_token, kaspi_shop_uid) if kaspi_shop_uid else get_headers(
                    kaspi_token)
                response = requests.get(url=url, params=data, headers=headers, timeout=timeout)
                response.raise_for_status()
                response_json = response.json()
                response_info += response_json['data']
                if response_json['meta']['pageCount'] <= page + 1:
                    break
                page += 1
                logger.info('kaspi_api_requests::get_orders_general_info',
                                    extra=extra
                                    )
            return response_info
        except Timeout:
            logger.error(f"kaspi_api_requests::get_orders_general_info :: Timeout occurred while getting "
                                 f"orders general info. Attempt {attempt + 1} of {max_retries}",
                                 extra=extra
                                 )
        except RequestException as e:
            logger.error(f"kaspi_api_requests::get_orders_general_info :: Request exception occurred while "
                                 f"getting orders general info: {str(e)}",
                                 extra=extra
                                 )
        except json.JSONDecodeError as e:
            logger.error(
                f"kaspi_api_requests::get_orders_general_info :: JSON decoding error occurred: {str(e)}",
                extra=extra
                )
        except KeyError as e:
            logger.error(f"kaspi_api_requests::get_orders_general_info :: Unexpected response format: {str(e)}",
                                 extra=extra
                                 )

        if attempt == max_retries - 1:
            logger.error("kaspi_api_requests::get_orders_general_info :: All retry attempts failed",
                                 extra=extra
                                 )
            return []  # or you could return an empty list, depending on your needs

        # Exponential backoff
        sleep_time = backoff_factor * (2 ** attempt)
        logger.info(f"kaspi_api_requests::get_orders_general_info :: Retrying in {sleep_time} seconds...",
                            extra=extra)
        time.sleep(sleep_time)

    return []


def get_order_by_code(order_code, kaspi_token, kaspi_shop_uid, max_retries=4, timeout=2, backoff_factor=0.5):
    """ Method to get information about an exact order (by order_code)
        Order_code is possible to get from the response of get_orders_general_info method"""

    url = 'https://kaspi.kz/shop/api/v2/orders'
    data = {'filter[orders][code]': order_code}
    headers = get_headers_with_uid(kaspi_token, kaspi_shop_uid) if kaspi_shop_uid else get_headers(kaspi_token)

    extra = {
        'order': order_code,
        'kaspi_shop': kaspi_shop_uid
    }

    for attempt in range(max_retries):
        try:
            response = requests.get(url=url, params=data, headers=headers, timeout=timeout)
            logger.info(f'kaspi_api_requests::get_order_by_code :: status code: {response.status_code}\n',
                                extra=extra)

            if response.status_code == 200:
                order_data = response.json().get('data', [])
                if order_data:
                    order_status = order_data[0]['attributes']['status']
                    return order_status
                else:
                    logger.info(f"kaspi_api_requests::get_order_by_code :: Order not found in response data, "
                                         f"status code: {response.status_code}",
                                         extra=extra)
                    return 'not_need_message'
            elif 400 <= response.status_code < 500:
                logger.error(f"kaspi_api_requests::get_order_by_code :: client error, not retrying"
                                     f"status code: {response.status_code}",
                                     extra=extra)
            else:
                logger.error(f"kaspi_api_requests::get_order_by_code :: server error, retrying"
                                     f"status code: {response.status_code}",
                                     extra=extra)

        except Timeout:
            logger.error(f"kaspi_api_requests::get_order_by_code :: timeout error, attempt {attempt + 1} of {max_retries}",
                                 extra=extra)
        except RequestException as e:
            logger.error(
                f"kaspi_api_requests::get_order_by_code :: request exception error, error ::  {str(e)}",
                extra=extra)

        # Exponential backoff
        sleep_time = backoff_factor * (2 ** attempt)
        logger.info(f"kaspi_api_requests::get_order_by_code :: Retrying in {sleep_time} seconds...",
                            extra=extra)
        time.sleep(sleep_time)

    logger.error("kaspi_api_requests::get_order_by_code :: All retry attempts failed",
                         extra=extra
                         )
    return 'ERROR'


def get_order_content(order_id, kaspi_token, kaspi_shop_uid, max_retries=3, timeout=2, backoff_factor=0.5):
    """ Method to get the content of an exact order (by order_id)
    Order_id is possible to get from the response of get_orders_general_info method"""

    url = f'https://kaspi.kz/shop/api/v2/orders/{order_id}/entries'
    headers = get_headers_with_uid(kaspi_token, kaspi_shop_uid) if kaspi_shop_uid else get_headers(kaspi_token)

    extra = {
        'order': order_id,
        'kaspi_shop': kaspi_shop_uid
    }

    for attempt in range(max_retries):
        try:
            response = requests.get(url=url, headers=headers, timeout=timeout)
            response.raise_for_status()
            data = response.json()['data']
            logger.info(f'kaspi_api_requests::get_order_content :: status code: {response.status_code}\n',
                                extra=extra)
            return data
        except Timeout:
            logger.error(
                f"kaspi_api_requests::get_order_content :: timeout error, attempt {attempt + 1} of {max_retries}",
                extra=extra)
        except RequestException as e:
            logger.error(
                f"kaspi_api_requests::get_order_content :: request exception error, error ::  {str(e)}",
                extra=extra)
        except json.JSONDecodeError as e:
            logger.error(
                f"kaspi_api_requests::get_order_content :: JSON decoding error, error ::  {str(e)}",
                extra=extra)
        except KeyError as e:
            logger.error(
                f"kaspi_api_requests::get_order_content :: KeyError, error ::  {str(e)}",
                extra=extra)

        if attempt == max_retries - 1:
            logger.error("kaspi_api_requests::get_order_content :: All retry attempts failed",
                                 extra=extra
                                 )
            return 'null'  # or you could return an empty list, depending on your needs

        # Exponential backoff
        sleep_time = backoff_factor * (2 ** attempt)
        logger.info(f"kaspi_api_requests::get_order_content :: Retrying in {sleep_time} seconds...",
                            extra=extra)
        time.sleep(sleep_time)

    return 'null'


def get_order_products_info(order_content_id, kaspi_token, kaspi_shop_uid, max_retries=3, timeout=2,
                            backoff_factor=0.5):
    """ Method to get the content of an exact order (by order_id)
    Order_id is possible to get from the response of get_orders_general_info method"""

    url = f'https://kaspi.kz/shop/api/v2/orderentries/{order_content_id}/product'
    headers = get_headers_with_uid(kaspi_token, kaspi_shop_uid) if kaspi_shop_uid else get_headers(kaspi_token)

    extra = {
        'order': order_content_id,
        'kaspi_shop': kaspi_shop_uid
    }

    for attempt in range(max_retries):
        try:
            response = requests.get(url=url, headers=headers, timeout=timeout)
            response.raise_for_status()  # Raises an HTTPError for bad responses
            data = response.json()['data']
            logger.info(f'kaspi_api_requests::get_order_products_info :: status code: {response.status_code}\n',
                                extra=extra)
            return data
        except Timeout:
            logger.error(
                f"kaspi_api_requests::get_order_products_info :: timeout error, attempt {attempt + 1} of {max_retries}",
                extra=extra)
        except RequestException as e:
            logger.error(
                f"kaspi_api_requests::get_order_products_info :: request exception error, error ::  {str(e)}",
                extra=extra)
        except json.JSONDecodeError as e:
            logger.error(
                f"kaspi_api_requests::get_order_products_info :: JSON decoding error, error ::  {str(e)}",
                extra=extra)
        except KeyError as e:
            logger.error(
                f"kaspi_api_requests::get_order_products_info :: KeyError, error ::  {str(e)}",
                extra=extra)

        if attempt == max_retries - 1:
            logger.error("kaspi_api_requests::get_order_products_info :: All retry attempts failed",
                                 extra=extra
                                 )
            return 'null'  # or you could return an empty dict, depending on your needs

        # Exponential backoff
        sleep_time = backoff_factor * (2 ** attempt)
        logger.info(f"kaspi_api_requests::get_order_products_info :: Retrying in {sleep_time} seconds...",
                            extra=extra)
        time.sleep(sleep_time)

    return 'null'


def confirm_new_order(order_id, order_code, kaspi_token):
    url = 'https://kaspi.kz/shop/api/v2/orders'
    data = {
        "data": {
            "type": "orders",
            "id": order_id,
            "attributes": {
                "code": order_code,
                "status": "ACCEPTED_BY_MERCHANT"
            }
        }
    }
    response = requests.post(url=url, headers=get_headers(kaspi_token), json=data)
    logger.info(f'kaspi_api_requests::confirm_new_order :: {response.status_code}, {response.json()}',
                        extra={'order_code': order_code, 'order_id': order_id})

    return response.status_code

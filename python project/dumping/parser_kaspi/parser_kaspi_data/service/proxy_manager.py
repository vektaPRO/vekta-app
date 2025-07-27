import asyncio
import json
import logging
import httpx
import random
import time
import os
import requests

from dotenv import load_dotenv
from django.conf import settings
from parser_kaspi_data.service.project_exceptions import ProxyProviderException

PROXIES_VALIDATION_DELAY_SECONDS = 5

logger = logging.getLogger(settings.PROXY_LOGGER_NAME)

load_dotenv()

API_KEY = os.getenv('ASOCKS_API_KEY')


class ProxyProvider:

    prevent_proxy = settings.RASPBERRY_ON_PROD and settings.HORIZONTAL_SCALING

    def __init__(self, proxies):
        if not isinstance(proxies, dict):
            logger.error('Proxies argument is not a dict')
            raise ProxyProviderException
        if len(proxies.values()) == 0 and not self.prevent_proxy:
            logger.error('Proxies list is empty')
            raise ProxyProviderException

        self._proxies = proxies
        self._ids = list(proxies.keys())
        random.shuffle(self._ids)
        self._next_proxy_index = 0
        logger.info(f'Proxy provider initialized with {self.num_proxies()} proxies')

    def get_proxy(self):
        if self.prevent_proxy:
            return None

        proxy = self._proxies[self._ids[self._next_proxy_index]]
        self._next_proxy_index += 1
        if self._next_proxy_index >= self.num_proxies():
            self._next_proxy_index = 0

        return proxy

    def num_proxies(self) -> int:
        return len(self._ids)


async def get_proxy_provider() -> ProxyProvider:
    if os.getenv('RASPBERRY_ON_PROD') == 'true' and os.getenv('HORIZONTAL_SCALING') == 'true':
        proxies = {}
    elif os.getenv('PROVIDER_ON') == 'asocks':
        proxies = await get_valid_asocks_proxies()
    elif os.getenv('PROVIDER_ON') == 'dataimpulse':
        proxies = get_valid_dataimpulse_proxies()
    elif os.getenv('PROVIDER_ON') == 'proxyrack':
        proxies = await get_valid_proxyrack_proxies()
    else:
        proxies = get_valid_froxy_proxies()
    return ProxyProvider(proxies)


def get_valid_froxy_proxies():
    headers = {
        "User-Agent": "PostmanRuntime/7.32.3",
        "Accept": "*/*",
    }

    params = {
        "template": '{login}:{pass}@{server}:{port}',
        "format": "txt",
        "range": '{"min":9000,"max":9199}',
        "filters[]": '{"login":"zmQAqmD9gblNNIPm","password":"wifi;;;;","server":"proxy.froxy.com"}'
    }
    response = requests.get(
        'https://froxy.com/api/subscription/169xkVUEFjdAjPzH/export', headers=headers,
        params=params)

    logger.info(f'Froxy proxy provider response status code = {response.status_code}')
    proxies_list = response.text.split('\n')

    proxies = ["http://" + proxy for proxy in proxies_list if proxy != '']

    return proxies


def get_valid_dataimpulse_proxies():
    session = requests.Session()
    session.auth = (os.getenv('DATAIMPULSE_LOGIN'), os.getenv('DATAIMPULSE_PASSWORD'))

    response = session.get(f'https://gw.dataimpulse.com:777/api/list?quantity={os.getenv("PROXIES_QUANTITY")}&countries={os.getenv("PROXIES_COUNTRIES")}')
    logger.info(f'Dataimpulse proxy provider response status code = {response.status_code}')
    proxies_list = response.text.split('\n')

    return ["https://" + proxy for proxy in proxies_list if proxy != '']


async def get_valid_proxyrack_proxies():
    proxyrack_login = os.getenv('PROXYRACK_LOGIN')
    proxyrack_password = os.getenv('PROXYRACK_PASSWORD')
    proxies = {
        10000: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10000',
        10001: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10001',
        10002: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10002',
        10003: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10003',
        10004: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10004',
        10006: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10006',
        10007: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10007',
        10008: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10008',
        10009: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10009',
        10010: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10010',
        10011: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10011',
        10012: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10012',
        10013: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10013',
        10014: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10014',
        10015: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10015',
        10016: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10016',
        10017: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10017',
        10018: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10018',
        10019: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10019',
        10020: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10020',
        10021: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10021',
        10022: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10022',
        10023: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10023',
        10024: f'https://{proxyrack_login}:{proxyrack_password}@private.residential.proxyrack.net:10024',
    }

    return await get_filtered_working_proxies(proxies)


async def get_valid_asocks_proxies():
    proxy_urls_by_id = get_proxies()
    refresh_proxies(proxy_ids=proxy_urls_by_id.keys())
    time.sleep(PROXIES_VALIDATION_DELAY_SECONDS)
    return await get_filtered_working_proxies(proxy_urls_by_id)


def get_proxies():
    result = {}
    page = 1
    while True:
        url = f'https://api.asocks.com/v2/proxy/ports?apiKey={API_KEY}&page={page}'
        timeout = httpx.Timeout(15.0, read=None)
        response = httpx.get(url, timeout=timeout).json()
        proxies = response['message']['proxies']
        for proxy in proxies:
            result[proxy['id']] = proxy['template']
        if response['message']['pagination']['pageCount'] <= page:
            break
        page += 1

    return result


def refresh_proxies(proxy_ids=None) -> None:
    logger.info("Обновляем IP адреса прокси...")
    for proxy_id in proxy_ids:
        refresh_proxy(proxy_id)


def refresh_proxy(proxy_id: int):
    refresh_url = f'https://api.asocks.com/v2/proxy/refresh/{proxy_id}?apikey={API_KEY}'
    response = httpx.get(refresh_url)
    # if response.status_code == 429:
    #     retry_after = response.headers.get('retry-after')
    #     logger.warning(f'Too many requests, going to wait {retry_after} seconds and retry')
    #     if retry_after:
    #         sleep(int(retry_after) + 1)
    #         response = httpx.get(refresh_url)

    if response.status_code == 200:
        pass
    else:
        logger.info(f'Refresh proxy {proxy_id} response code={response.status_code}:' + response.text)
        logger.info(json.dumps(response.headers.multi_items()).replace('\n', '\t').replace('\r', ''))


async def proxy_fetcher(proxy_url, proxy_id: int, attempt_number=0):
    url = 'https://kaspi.kz/yml/offer-view/offers'
    skus = [{'sku': '1005119'}, {'sku': '106363345'}, {'sku': '106363335'},
            {'sku': '106363312'}, {'sku': '106363327'}, {'sku': '102298145'},
            {'sku': '106363270'}, {'sku': '106363281'}, {'sku': '106363322'},
            {'sku': '106363344'}, {'sku': '106363274'}, {'sku': '106363297'},
            {'sku': '106363307'}, {'sku': '106363295'}]

    random_skus = [random.choice(skus) for _ in range(5)]
    data = {'options': ['PRICE'], 'cityId': '750000000', 'entries': random_skus}

    not_working_proxy_log_message = f'Proxy [{proxy_id}]({proxy_url}) does not work.'

    async with httpx.AsyncClient(proxies=proxy_url) as client:
        try:
            response = await client.post(url, json=data, headers=headers(), timeout=30)
            if response.status_code == 200:
                return proxy_id, proxy_url

            logger.warning(f'Response status not successful: {response.status_code}. {not_working_proxy_log_message}')
            #
            # if attempt_number == 0:
            #     logger.warning(f'{not_working_proxy_log_message}. Trying to refresh and repeat again')
            #     refresh_proxy(proxy_id)
            #     return await proxy_fetcher(proxy_url, proxy_id, attempt_number=attempt_number + 1)

        except httpx.TimeoutException:
            logger.warning(f'The request timed out. {not_working_proxy_log_message}')
        except Exception as error:
            logger.warning(f'Error during proxy validation - {error}. {not_working_proxy_log_message}')

        logger.warning(f'{not_working_proxy_log_message}. No more retries')

        return None, None


async def get_filtered_working_proxies(proxy_urls_by_id):
    logger.info("Отбираем валидные прокси")
    tasks = [proxy_fetcher(proxy_url, proxy_id) for proxy_id, proxy_url in proxy_urls_by_id.items()]
    valid_proxy_urls_by_id = {}
    for proxy_id, proxy_url in await asyncio.gather(*tasks):
        if not proxy_url:
            continue
        valid_proxy_urls_by_id[proxy_id] = proxy_url

    logger.info(f"Кол-во прокси: {len(proxy_urls_by_id.values())}, валидных: {len(valid_proxy_urls_by_id.values())}")
    return valid_proxy_urls_by_id


def check_asocks_proxy_balance():
    url = f'https://api.asocks.com/v2/user/balance?apiKey={API_KEY}'
    balance = None
    try:
        response = requests.get(url)
        if response.status_code == 200:
            balance = response.json()['balance']
            logger.info(f'Asocks proxies balance is equal to {balance}')
        else:
            logger.info(f'Response status code is not equal to 200, impossible to retrieve information about proxies balance')
    except BaseException as e:
        logger.info(f'Error during checking ASOCKS proxies balance :: {e}')

    return balance


def headers() -> dict:
    return {
        'accept': 'application/json, text/*',
        'User-Agent': ('Mozilla/5.0 (iPhone; CPU iPhone OS 15_3 '
                       'like Mac OS X) AppleWebKit/605.1.15 '
                       '(KHTML, like Gecko) CriOS/98.0.4758.85 '
                       'Mobile/15E148 Safari/604.1'),
        'Content-Type': 'application/json; charset=UTF-8',
        'Cookie': 'ks.tg=105;',
        'Referer': "https://kaspi.kz/shop/p/"
    }

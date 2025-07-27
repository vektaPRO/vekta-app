import re
import httpx
import aiohttp
import asyncio
import logging
import requests
from aiohttp import client_exceptions
from dotenv import load_dotenv
from django.conf import settings
from django.core.cache import cache
from parser_kaspi_data.project_additional_models.data_models import CityPrices
from parser_kaspi_data.project_decorators import http_retry_decorator
from parser_kaspi_data.service import project_logger, project_exceptions
from parser_kaspi_data.service.project_exceptions import IncorrectLoginException, MerchantSettingsRetrieveException, \
    RetryableHttpClientException
from parser_kaspi_data.service.project_logger import log_traffic
from parser_kaspi_data.service.proxy_manager import ProxyProvider

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)

load_dotenv()


class KaspiMerchantCabinetMethods(object):

    CABINET_PRODUCTS_URL = 'https://mc.shop.kaspi.kz/bff/offer-view/list?m=%s&p=%s&l=10&a=%s&t=&c='
    CABINET_PRODUCT_DETAIL_URL = 'https://mc.shop.kaspi.kz/bff/offer-view/details?m=%s&s=%s'

    def __init__(self, login=None, password=None, session_id=None):
        self.login = login
        self.password = password
        if session_id is not None:
            self.session_id = session_id
        else:
            self.session_id = cache.get(self.login, None)
            if self.session_id is None:
                self.session_id = self._log_in()
                cache.set(self.login, self.session_id, timeout=0.25 * 60 * 60)

    def _cabinet_products_url(self, merchant_id: int, active: str = 'true', page_num: int = 0):
        return self.CABINET_PRODUCTS_URL % (merchant_id, page_num, active)

    def _cabinet_product_detail_url(self, merchant_id: str, product_id: str):
        return self.CABINET_PRODUCT_DETAIL_URL % (merchant_id, product_id)

    @property
    def _common_headers(self):
        return {
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


    @property
    def mastersku_headers(self):
        return {
            'Content-Type': 'application/json',
            'Cookie': f'X-Mc-Api-Session-Id={self.session_id}',
            'Accept': '*/*',
            'User-Agent': 'PostmanRuntime/7.32.3'
        }

    @property
    def upload_xml_file_headers(self):
        return {
            'Content-Encoding': 'gzip',
            'Cookie': f'X-Mc-Api-Session-Id={self.session_id}',
            'Accept': '*/*',
            'User-Agent': 'PostmanRuntime/7.32.3'
        }

    def _log_in(self):
        """ Method to log in as a merchant into Kaspi cabinet.
        This method is needed to proceed all other methods from Kaspi cabinet"""
        response = requests.post('https://kaspi.kz/mc/api/login',
                                 data={'username': self.login, 'password': self.password},
                                 headers=self._common_headers)
        if response.status_code != 200:
            raise IncorrectLoginException
        regex = r"X-Mc-Api-Session-Id=([^;]*);"
        self.session_id = re.findall(regex, response.headers['Set-Cookie'], re.MULTILINE)[0]

        logger.info(f'Login to kaspi cabinet was made, status_code :: {response.status_code}')

        return self.session_id

    def get_merchant_settings(self):
        response = requests.get('https://kaspi.kz/merchantcabinet/api/merchant/appData',
                                headers=self.mastersku_headers)
        if response.status_code != 200:
            logger.info(f'While merchant settings retrieving some errors occurred,  status_code :: {response.status_code},'
                        f'response :: {response.json()}')
            raise MerchantSettingsRetrieveException

        response_data = response.json()['merchant']
        logger.info(f'Merchant settings were retrieved,  status_code :: {response.status_code}')

        return {'merchant_id': response_data['hybrisUid'], 'merchant_name': response_data['name']}

    def upload_xml_file_with_prices(self, kaspi_merchant_id, filename):
        files = {'file': ('prices.xml', open(filename, 'rb'), 'text/xml')}
        data = {"merchantUid": kaspi_merchant_id}
        url = 'https://mc.shop.kaspi.kz/pricefeed/upload/merchant/upload'
        response = requests.post(url, headers=self.upload_xml_file_headers, files=files, data=data)
        logger.info(f'XML_file uploading,  status_code :: {response.status_code}')

    @http_retry_decorator(retries=3)
    async def get_merchant_products_info(self, merchant, active, proxy_provider: ProxyProvider, uid: str):
        """ Method to parse information of all products - both from Published and Archived sections
        if active argument == 'true' - this is Published section
        if active argument == 'false' - this is Archived section
        """
        async with httpx.AsyncClient(proxy=proxy_provider.get_proxy(), headers=self.mastersku_headers, timeout=None,
                                     verify=False) as client:
            try:
                page_number = 0
                response_data = []

                while True:
                    page_url = f'https://mc.shop.kaspi.kz/bff/offer-view/list?m={merchant}&p={page_number}&l=10&a={active}&t=&c='
                    response = await client.get(url=page_url)
                    logger.info(f'Response for url {page_url} = {response}', extra={'uid': uid})
                    if response.status_code == 429 or response.status_code == 405:
                        raise RetryableHttpClientException
                    response_json = response.json()
                    response_data.extend(response_json['data'])
                    total_items = response_json['total']
                    if len(response_data) >= total_items:
                        break
                    page_number += 1

                log_traffic('get_merchant_products_info', response, uid=uid)

            except httpx.ProxyError as e:
                logger.error(f'ProxyError while get_merchant_products_info for merchant {merchant}', extra={'uid': uid})
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            except httpx.TimeoutException as e:
                logger.error(f'TimeoutException while get_merchant_products_info for merchant {merchant}', extra={'uid': uid})
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            except httpx.RequestError as e:
                logger.exception(f'RequestError while get_merchant_products_info for merchant {merchant}', extra={'uid': uid})
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            except httpx.RemoteProtocolError as e:
                logger.exception(f'RemoteProtocolError while get_merchant_products_info for merchant {merchant}', extra={'uid': uid})
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            return response_data

    @http_retry_decorator(retries=3)
    async def get_product_details(self,  merchant, sku, proxy_provider: ProxyProvider):
        """ Method to retrieve availabilities and city_prices for each product
        This method is to gain all necessary data for POST requests"""
        async with httpx.AsyncClient(proxy=proxy_provider.get_proxy(), headers=self.mastersku_headers, timeout=None,
                                     verify=False) as client:
            try:
                response = await client.get(url=f'https://mc.shop.kaspi.kz/bff/offer-view/details?m={merchant}&s={sku}')

                if response.status_code == 429 or response.status_code == 405:
                    raise RetryableHttpClientException

                availabilities = []
                city_prices = []

                for city in response.json()['cityInfo']:
                    for point in city['pickupPoints']:
                        if point["available"] is False:
                            continue
                        availabilities.append({'available': 'yes', 'storeId': point['name']})
                        city_prices.append({'value': int(city['price']), 'cityId': city['id']})

                log_traffic('get_product_details', response)

            except httpx.ProxyError as e:
                logger.error(f'ProxyError for SKU {sku} while get_product_details')
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            except httpx.TimeoutException as e:
                logger.error(f'TimeoutException for SKU {sku} while get_product_details')
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            except httpx.RequestError as e:
                logger.exception(f'RequestError during request for SKU {sku} while get_product_details')
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            except httpx.RemoteProtocolError as e:
                logger.exception(f'RemoteProtocolError during request for SKU {sku} while get_product_details')
                logger.error(project_logger.format_exception(e))
                raise RetryableHttpClientException

            return CityPrices(availabilities=availabilities, city_prices=city_prices)

    async def change_price(self, merchant, sku_merch, title, availabilities, cityPrices, new_price, proxy_provider: ProxyProvider):
        """ Method to change data of determined product by determined value """
        async with httpx.AsyncClient(proxy=proxy_provider.get_proxy(), headers=self.mastersku_headers, timeout=None,
                                     verify=False) as client:

            for city in cityPrices:
                city['value'] = new_price

            data = {"merchantUid": merchant,
                    "sku": sku_merch,
                    "model": title,
                    "price": new_price,
                    "availabilities": availabilities,
                    "cityPrices": cityPrices
                    }

            response = await client.post(url='https://mc.shop.kaspi.kz/pricefeed/upload/merchant/process', json=data)

            log_traffic('change_price', response)

            logger.info(data)
            logger.info(response.json())

            logger.info(f'Changing price for product {sku_merch}  with new price {new_price} ---- > {response.status_code}')

            return response.status_code == 200

    async def make_product_unavailable(self, merchant, sku, title, proxy_provider: ProxyProvider):
        """ Method to make a product unavailable and send it to Archived section """
        async with httpx.AsyncClient(proxy=proxy_provider.get_proxy(), headers=self.mastersku_headers, timeout=None,
                                     verify=False) as client:
            data = [{"merchantUid": merchant,
                    "sku": sku,
                    "model": title
                    }]

            response = await client.post(url='https://mc.shop.kaspi.kz/pricefeed/upload/merchant/process/process/batch', json=data)

            if response.status_code == 200:
                logger.info(f'Product {sku} was made unavailable, status_code :: {response.status_code}')
            else:
                logger.info(f'Response status_code while making product {sku} unavailable :: {response.status_code},'
                            f'response data :: {response.json()}')

            log_traffic('make_product_unavailable', response)

            return response.status_code

    async def make_product_available(self, merchant, sku, title, price, proxy_provider: ProxyProvider):
        async with httpx.AsyncClient(proxy=proxy_provider.get_proxy(), headers=self.mastersku_headers, timeout=None,
                                     verify=False) as client:
            """ Method to make a product available and send it from Archived section to Published section """
            product_details = await self.get_product_details(merchant, sku, proxy_provider)

            data = [{"merchantUid": merchant,
                    "sku": sku,
                    "model": title,
                    "price": price,
                    "availabilities": product_details['availabilities'],
                    "cityPrices": product_details['city_prices']
                    }]

            response = await client.post(url='https://mc.shop.kaspi.kz/pricefeed/upload/merchant/process/process/batch',
                                         json=data)

            if response.status_code == 200:
                logger.info(f'Product {sku} was made available, status_code :: {response.status_code}')
            else:
                logger.info(f'Response status_code while making product {sku} available :: {response.status_code},'
                            f'response data :: {response.json()}')

            log_traffic('make_product_available', response)

            return response.status_code

    @http_retry_decorator(retries=3)
    async def _cabinet_request(self, session: aiohttp.ClientSession, url, method, headers, proxy, payload=None):

        try:
            async with session.request(
                    proxy=proxy.get_proxy(),
                    headers=headers,
                    data=payload,
                    method=method,
                    url=url,
            ) as response:
                if response.status != 200:
                    return {}
                content = await response.json()
                return content
        except (
                client_exceptions.ClientConnectorError,
                client_exceptions.ServerDisconnectedError,
                client_exceptions.ClientPayloadError,
                client_exceptions.ClientHttpProxyError
        ):
            raise project_exceptions.RetryableHttpClientException

    async def _get_merchant_cabinet_page_num(
            self, session: aiohttp.ClientSession,
            proxy_provider: ProxyProvider,
            merchant_id: int
    ):
        response_content: dict = await self._cabinet_request(
            headers=self.mastersku_headers,
            url=self._cabinet_products_url(merchant_id, page_num=0),
            proxy=proxy_provider,
            session=session,
            method='GET',
        )

        return response_content.get('total', 0) // 10 + 1

    async def get_merchant_products(self, merchant_id, proxy_provider: ProxyProvider, active: str, uid: str):
        """ Method to parse information of all products - both from Published and Archived sections
        if active argument == 'true' - this is Published section
        if active argument == 'false' - this is Archived section
        """

        setattr(asyncio.sslproto._SSLProtocolTransport, "_start_tls_compatible", True)
        async with aiohttp.ClientSession() as session:
            total_page_cnt = await self._get_merchant_cabinet_page_num(
                session=session,
                proxy_provider=proxy_provider,
                merchant_id=merchant_id
            )

            logger.info('#Get_merchant_products page count is %s, uid %s', total_page_cnt, uid)

            tasks = []
            for page_num in range(total_page_cnt + 1):
                tasks.append(
                    self._cabinet_request(
                        url=self._cabinet_products_url(merchant_id=merchant_id, active=active, page_num=page_num),
                        headers=self.mastersku_headers,
                        proxy=proxy_provider,
                        session=session,
                        method='GET',
                    )
                )

            process_results = await asyncio.gather(*tasks)
            result = []

            for res in process_results:
                result.extend(res['data'])

            logger.info('#Get_merchant_products parsed products count %s, uid %s', result.__len__(), uid)

            return result

    async def get_actual_product_price(
            self,
            merchant_id: str,
            product_id: str,
            city_id: str,
            proxy_proxider: ProxyProvider,
            uid: str) -> int:
        setattr(asyncio.sslproto._SSLProtocolTransport, "_start_tls_compatible", True)
        async with aiohttp.ClientSession() as session:
            product_detail_response = await self._cabinet_request(
                session=session,
                url=self._cabinet_product_detail_url(merchant_id=merchant_id, product_id=product_id),
                proxy=proxy_proxider,
                method='GET',
                headers=self.mastersku_headers
            )

        cities_data = product_detail_response.get('cityInfo', [])
        for city_data in cities_data:
            if city_data.get('id') == city_id:
                return city_data.get('price')
        return 9999999

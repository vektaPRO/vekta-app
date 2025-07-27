import time
import asyncio
import logging
from typing import List
from django.conf import settings
from django.core.cache import cache
from pktools.string import generate_string
from parser_kaspi_data.models import Merchant, KaspiProduct, ProductPrice
from parser_kaspi_data.service.kaspi.client import Client
from parser_kaspi_data.service.proxy_manager import ProxyProvider


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


class KaspiConnector:
    REQUESTS_RETRY_TIMEOUT_SECONDS = 2
    FETCH_PRODUCTS_LIMIT = 100
    CITY_ID_ALMATY = '750000000'
    CITY_ID_ASTANA = '710000000'

    def __init__(self, merchant: Merchant, proxy: ProxyProvider = None):
        self.client = Client(merchant.login, merchant.password)
        self.merchant_id = merchant.id
        self.cabinet_id = merchant.merchant_id
        self.merchant_login = merchant.login
        self.proxy = proxy
        self.get_session()

    def get_session(self, uid: str = None):
        """
        Fetch session if it exists in cache, otherwise request for session
        """
        uid = uid or generate_string()
        # TODO: check if session valid
        stored_session = cache.get(self.merchant_login)
        if stored_session is None:
            stored_session = self.client.get_session(uid)
            cache.set(self.merchant_login, stored_session, timeout=15 * 60)
        self.client.session_id = stored_session
        return stored_session

    async def get_products_async(self, uid: str, active: bool, product_count: int):
        tasks = list()
        page_count = product_count // KaspiConnector.FETCH_PRODUCTS_LIMIT + 1

        for page in range(0, page_count + 1):
            tasks.append(
                asyncio.to_thread(
                    self.client.get_products,
                    self.cabinet_id, active,
                    limit=KaspiConnector.FETCH_PRODUCTS_LIMIT,
                    page=page,
                    proxy_provider=self.proxy,
                    uid=uid
                )
            )
        return await asyncio.gather(*tasks)

    def get_products(self, active: bool = True, uid: str = None):
        uid = uid or generate_string()
        self.get_session(uid)
        product_count = self.client.get_products(self.cabinet_id, active, proxy_provider=self.proxy, uid=uid).total

        data = asyncio.run(self.get_products_async(uid, active, product_count))
        result = data[0]

        for products_info in data[1:]:
            result.data += products_info.data

        return result

    def get_product_detail(self, kaspi_product: KaspiProduct, uid: str = None):
        uid = uid or generate_string()
        self.get_session(uid)
        product = self.client.get_product(
            cabinet_id=self.cabinet_id,
            master_sku=kaspi_product.master_sku,
            uid=uid
        )

        return product

    def get_product_actual_price(self, kaspi_product: KaspiProduct, uid: str = None,
                                 city_id: str = CITY_ID_ALMATY):
        uid = uid or generate_string()
        self.get_session(uid)
        product = self.client.get_product(
            cabinet_id=self.cabinet_id,
            proxy_provider=self.proxy,
            master_sku=kaspi_product.master_sku,
            uid=uid,
        )

        for city in product.cityInfo:
            if city.id == city_id:
                return city.price

    def get_product_competitors(self, code: str, uid: str = None, city_id: str = CITY_ID_ALMATY):
        # does not need session
        uid = uid or generate_string()
        offers = self.client.get_product_competitors(
            code=code, city_id=city_id, uid=uid,
            proxy_provider=self.proxy,
        )

        return offers

    def _beatify_merchant_store_id(self, store_id: str):
        if not store_id.startswith('PP'):
            return store_id
        return '%s_%s' % (self.cabinet_id, store_id)

    def __update_product(self, kaspi_product: KaspiProduct, price: int,
                         uid: str, city_ids: List[str], available_store_ids: List[str]):
        self.get_session(uid)

        cities = []
        for city_id in city_ids:
            cities.append(
                {
                    'value': price,
                    'cityId': city_id,
                }
            )

        availabilities = []
        for available_store_id in available_store_ids:
            availabilities.append(
                {
                    'storeId': available_store_id,
                    'available': 'yes'
                }
            )

        offer_id = self.client.update_product(
            master_sku=kaspi_product.master_sku,
            availabilities=availabilities,
            cabinet_id=self.cabinet_id,
            title=kaspi_product.title,
            city_prices=cities,
            price=price,
            uid=uid
        )

        return offer_id

    def update_product_and_mark(self, kaspi_product: KaspiProduct, price: int,
                                uid: str = None, city_ids: List[str] = None,
                                available_store_ids: List[str] = None) -> ProductPrice | None:
        uid = uid or generate_string()
        city_ids = city_ids or [KaspiConnector.CITY_ID_ALMATY]
        available_store_ids = available_store_ids or [
            self._beatify_merchant_store_id(store['storeId']) for store in kaspi_product.availabilities
            if store['available'] == 'yes'
        ]

        extra_data = {
            'kaspi_product_id': kaspi_product.id,
            'kaspi_product_code': kaspi_product.code,
            'merchant': '%s, %s' % (kaspi_product.merchant_name, kaspi_product.merchant_id),
            'current_price': kaspi_product.price,
            'target_price': price
        }

        product_price = ProductPrice(product=kaspi_product)

        try:
            self.__update_product(
                available_store_ids=available_store_ids,
                kaspi_product=kaspi_product,
                city_ids=city_ids,
                price=price,
                uid=uid
            )
            product_price.changed_price = price
            return product_price
        except BaseException as err:
            logger.error('#KaspiConnector.update_product_and_mark'
                         'request error %s, uid %s', err, uid, extra=extra_data)
            for _ in range(3):
                try:
                    time.sleep(KaspiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                    self.__update_product(
                        available_store_ids=available_store_ids,
                        kaspi_product=kaspi_product,
                        city_ids=city_ids,
                        price=price,
                        uid=uid
                    )
                    product_price.changed_price = price
                    return product_price
                except BaseException as exc:
                    logger.error('#KaspiConnector.update_product_and_mark'
                                 'request retry error %s, uid %s', exc, uid, extra=extra_data)

from typing import List
import logging
from django.conf import settings
from pktools.string import generate_string
from parser_kaspi_data.service.proxy_manager import ProxyProvider
from .structs.base import RESTProductDetail, RESTProductList, RESTOffersList
from .rest_requests import (CabinetGetSessionRequest, CabinetProductListRequest, CabinetProductDetailRequest,
                            ProductCompetitorsListRequest, CabinetProductUpdateRequest)


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class Client(object):
    request_url = None
    login = None
    password = None
    parent_method = None
    session_id = None

    def __init__(self, login, password, parent_method=None, session_id=None):
        self.request_url = settings.MERCHANT_CABINET_API_BASE_URL
        self.login = login
        self.password = password
        self.parent_method = parent_method
        self.session_id = session_id

    def get_session(self, uid: str):
        logger.info('#kaspi.client.authorization: uid %s, obtaining new session started', uid)

        payload = {
            'username': self.login,
            'password': self.password
        }

        session_request = CabinetGetSessionRequest(
            request_url=settings.MERCHANT_CABINET_BASE_URL,
            uid=uid,
            data=payload,
            parent_method=self.parent_method
        )

        session_response = session_request.run()

        return session_response.session_id

    def get_products(self, merchant_id: str, active: bool, uid: str, limit: int = 1, page: int = 0,
                     proxy_provider: ProxyProvider = None) -> RESTProductList:
        logger.info("#kaspi.client.get_products: uid %s, obtaining products of merchant %s", uid, merchant_id)
        params = {
            'm': merchant_id,
            'p': page,
            'l': limit,
            'a': active,
            't': '',
            'c': ''
        }

        # get total products count
        request = CabinetProductListRequest(
            parent_method=self.parent_method,
            merchant_reference=merchant_id,
            request_url=self.request_url,
            auth_token=self.session_id,
            proxy=proxy_provider,
            params=params,
            uid=uid,
        )
        response = request.run()
        return response

    def get_product(self, cabinet_id: str, master_sku: str, uid: str,
                    proxy_provider: ProxyProvider = None) -> RESTProductDetail:
        logger.info("#kaspi.client.get_product: uid %s, obtaining products of merchant %s", uid, cabinet_id)
        params = {
            'm': cabinet_id,
            's': master_sku
        }

        request = CabinetProductDetailRequest(
            parent_method=self.parent_method,
            merchant_reference=cabinet_id,
            request_url=self.request_url,
            auth_token=self.session_id,
            proxy=proxy_provider,
            params=params,
            uid=uid
        )

        response = request.run()

        return response

    def get_product_competitors(self, code: str, city_id: str, uid: str,
                                proxy_provider: ProxyProvider = None) -> RESTOffersList:
        logger.info('#kaspi.client.get_product_competitors: code %s, city %s, uid %s', code, city_id, uid)
        ids = (code,)
        payload = dict(
            installationId="-1",
            cityId=city_id,
            sort=True,
            limit=3
        )

        request = ProductCompetitorsListRequest(
            parent_method=self.parent_method,
            request_url=settings.MERCHANT_CABINET_BASE_URL,
            data=payload,
            ids=ids,
            uid=uid
        )

        response = request.run()

        return response

    def update_product(self,
                       uid: str,
                       title: str,
                       price: int,
                       cabinet_id: str,
                       master_sku: str,
                       city_prices: List[dict],
                       availabilities: List[dict],
                       proxy_provider: ProxyProvider = None):

        payload = {
            'merchantUid': cabinet_id,
            'sku': master_sku,
            'model': title,
            'price': price,
            'availabilities': availabilities,
            'cityPrices': city_prices
        }

        update_product_request = CabinetProductUpdateRequest(
            parent_method=self.parent_method,
            request_url=self.request_url,
            auth_token=self.session_id,
            proxy=proxy_provider,
            data=payload,
            uid=uid
        )

        update_product_offer_id = update_product_request.run()
        return update_product_offer_id

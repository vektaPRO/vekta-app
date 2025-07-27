import json
import logging
import requests
from os import path
from jinja2 import Environment, FileSystemLoader
from django.conf import settings
from logger.utils import CabinetLogger
from pktools.http import get_url, RequestMethod
from pktools.string import generate_string
from parser_kaspi_data.service.proxy_manager import ProxyProvider
from .exceptions import RequestError
from .rest_responses import (
    BaseResponse, MerchantCabinetGetSessionResponse,
    CabinetProductListResponse, CabinetProductDetailResponse,
    ProductCompetitorsListResponse, CabinetProductUpdateResponse
)


loader = FileSystemLoader(path.join(path.dirname(__file__), 'Cabinet_JSON'))
env = Environment(loader=loader, trim_blocks=True, lstrip_blocks=True)
logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


class BaseRequest(object):
    _response_class = BaseResponse
    _type = RequestMethod.GET
    _path = '/'
    _use_proxy = False
    headers_template = None
    is_json = False
    method = '-'
    merchant_reference = None

    def __init__(self,
                 uid: str,
                 request_url: str,
                 ids: tuple = None,
                 data: dict = None,
                 params: dict = None,
                 auth_token: str = None,
                 parent_method: str = None,
                 proxy: ProxyProvider = None,
                 merchant_reference: str = None):
        super().__init__()
        self.uid = uid
        self.auth_token = auth_token or ''
        self.parent_method = parent_method if parent_method else '-'
        self.request_url = request_url
        self.data = data or {}
        self.ids = ids or []
        self.params = params or {}
        self.merchant_reference = merchant_reference
        self.headers = self._headers()
        self.proxy = None if not self._use_proxy else proxy.get_proxy()

    def _headers(self):
        template = env.get_template(self.headers_template)
        return json.loads(template.render())

    def _log_db(self, message: str, conversation_id: str, response_code: any, url: str, cookie: str, is_error: bool):
        log_msg_data = dict(
            uid=self.uid,
            conversation_id=conversation_id,
            method=f'(Cabinet) [{self.parent_method}] {self.method}',
            merchant_reference=self.merchant_reference or '',
            response_code=response_code,
            cabinet_cookie=cookie,
            url=url
        )

        if is_error:
            CabinetLogger.error(message, **log_msg_data)
        else:
            CabinetLogger.info(message, **log_msg_data)

    def _request(self, is_json_serializable):
        request_kwargs = {
            'url': get_url(
                self.request_url,
                self._path,
                *self.ids,
                **self.params
            ),
            'method': self._type,
            'headers': self.headers,
            'proxies': self.proxy,
            'json': self.data if self.is_json else None,
            'data': self.data if not self.is_json else None
        }

        if self.auth_token:
            request_kwargs['headers']['Cookie'] += 'X-Mc-Api-Session-Id=%s;' % self.auth_token
        conversation_id = generate_string()

        self._log_db(
            message=json.dumps(self.data, indent=4, default=lambda o: o.__dict__), cookie=request_kwargs['headers']['Cookie'],
            conversation_id=conversation_id, response_code=None, is_error=False, url=request_kwargs['url'],
        )
        try:
            response = requests.request(**request_kwargs)
        except Exception as err:
            error_message = f'{err}'
            self._log_db(
                message=error_message, conversation_id=conversation_id, response_code=None, is_error=True,
                cookie=request_kwargs['headers']['Cookie'], url=request_kwargs['url'],
            )
            logger.error('#kaspi request error: %s', err)
            raise RequestError(error_message)

        if not response.ok:
            self._log_db(
                message=response.text, conversation_id=conversation_id, url=request_kwargs['url'],
                response_code=response.status_code, is_error=True, cookie=request_kwargs['headers']['Cookie']
            )
            logger.error('#kaspi response error: %s', response.status_code)
            raise RequestError(response.text)

        self._log_db(
            message=response.text, conversation_id=conversation_id, url=request_kwargs['url'],
            response_code=response.status_code, is_error=False, cookie=request_kwargs['headers']['Cookie']
        )

        return response

    def run(self, is_json_serializable=True):
        response = self._request(is_json_serializable)
        raw_response = json.loads(response.text or 'null')
        return self._response_class(
            data=raw_response,
            code=response.status_code,
            headers=response.headers
        ).parse()


class CabinetGetSessionRequest(BaseRequest):
    _path = '/mc/api/login'
    _type = RequestMethod.POST
    _response_class = MerchantCabinetGetSessionResponse
    is_json = False
    method = 'get_session'
    headers_template = 'common_headers.json'


class CabinetProductListRequest(BaseRequest):
    _path = 'bff/offer-view/list'
    _type = RequestMethod.GET
    _response_class = CabinetProductListResponse
    is_json = True
    method = 'list_products'
    headers_template = 'mastersku_headers.json'


class CabinetProductDetailRequest(BaseRequest):
    _path = 'bff/offer-view/details'
    _type = RequestMethod.GET
    _response_class = CabinetProductDetailResponse
    is_json = True
    method = 'detail_product'
    headers_template = 'mastersku_headers.json'


class CabinetProductUpdateRequest(BaseRequest):
    _path = 'pricefeed/upload/merchant/process'
    _type = RequestMethod.POST
    _response_class = CabinetProductUpdateResponse
    is_json = True
    method = 'update_product'
    headers_template = 'mastersku_headers.json'


class ProductCompetitorsListRequest(BaseRequest):
    _path = 'yml/offer-view/offers/%s'
    _type = RequestMethod.POST
    _response_class = ProductCompetitorsListResponse
    is_json = True
    method = 'competitors_data'
    headers_template = 'public_headers.json'

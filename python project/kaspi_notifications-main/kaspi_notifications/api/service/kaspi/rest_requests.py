import json
from os import path

import requests
from httpx import RequestError
from jinja2 import FileSystemLoader, Environment
from rest_framework.exceptions import AuthenticationFailed, ParseError

from pktools.http import RequestMethod, get_url
from api.service.kaspi.rest_responses import BaseResponse, OrderListResponse, \
    OrderEntriesResponse, OrderEntriesProductResponse, ConfirmNewOrderResponse

loader = FileSystemLoader(path.join(path.dirname(__file__), 'Cabinet_JSON'))
env = Environment(loader=loader, trim_blocks=True, lstrip_blocks=True)


class BaseRequest(object):
    _response_class = BaseResponse
    _type = RequestMethod.GET
    _path = '/'
    headers_template = None
    method = '-'
    is_json = False

    def __init__(self,
                 request_url: str,
                 ids: tuple = None,
                 data: dict = None,
                 params: dict = None,
                 parent_method: str = None,
                 headers: dict = None,
                 ):
        super().__init__()
        self.request_url = request_url
        self.ids = ids
        self.data = data
        self.params = params
        self.parent_method = parent_method
        self.headers = headers

    def _headers(self):
        template = env.get_template(self.headers_template)
        kaspi_token = self.headers.get("kaspi_token", "")
        kaspi_shop_uid = self.headers.get("kaspi_shop_uid", "")
        return json.loads(template.render(kaspi_token=kaspi_token, kaspi_shop_uid=kaspi_shop_uid))

    def _request(self):
        request_kwargs = {
            'url': get_url(
                self.request_url,
                self._path,
                *self.ids if self.ids else [],
            ),
            'params': self.params,
            'method': self._type,
            'headers': self._headers(),
            'json': self.data if self.is_json else None,
            'data': self.data if not self.is_json else None
        }

        try:
            response = requests.request(**request_kwargs)
        except Exception as err:
            error_message = f'{err}'
            raise RequestError(error_message)
        if response.status_code == 400:
            raise ParseError(response.text)
        if response.status_code == 401:
            raise AuthenticationFailed(response.text)
        if not response.ok:
            raise RequestError(response.text)

        return response

    def run(self):
        response = self._request()
        raw_response = json.loads(response.text or 'null')
        return self._response_class(
            data=raw_response,
            code=response.status_code,
            headers=response.headers,
        ).parse()


class OrderListRequest(BaseRequest):
    _path = '/shop/api/v2/orders'
    _type = RequestMethod.GET
    _response_class = OrderListResponse
    is_json = True
    method = 'list_orders'
    headers_template = 'common_headers.json'


class OrderEntriesRequest(BaseRequest):
    _path = '/shop/api/v2/orders/%s/entries'
    _type = RequestMethod.GET
    _response_class = OrderEntriesResponse
    is_json = True
    method = 'list_entries'
    headers_template = 'common_headers.json'


class OrderEntriesProductRequest(BaseRequest):
    _path = '/shop/api/v2/orderentries/%s/product'
    _type = RequestMethod.GET
    _response_class = OrderEntriesProductResponse
    is_json = True
    method = 'entries_product'
    headers_template = 'common_headers.json'


class ConfirmNewOrderRequest(BaseRequest):
    _path = '/shop/api/v2/orders'
    _type = RequestMethod.POST
    _response_class = ConfirmNewOrderResponse
    is_json = True
    method = 'confirm_new_order'
    headers_template = 'common_headers.json'

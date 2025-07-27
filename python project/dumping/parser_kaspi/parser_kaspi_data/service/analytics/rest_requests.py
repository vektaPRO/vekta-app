import json

import requests

from parser_kaspi_data.service.analytics.rest_responses import AnalyticsUserRegistrationResponse
from parser_kaspi_data.service.kaspi.rest_responses import BaseResponse
from pktools.http import RequestMethod, get_url


class BaseRequest(dict):
    _response_class = BaseResponse
    _type = RequestMethod.GET
    _path = '/'
    method = '-'

    def __init__(self, **kwargs):
        self.request_url = kwargs.get('request_url')
        self.ids = kwargs.get('ids', list())
        self.payload = kwargs.get('payload', dict())
        self.headers = kwargs.get('headers', dict()) if kwargs.get('headers') else dict()
        self.params = kwargs.get('params', dict())
        super().__init__(**kwargs)

    def _request(self, is_json_serializable):
        request_kwargs = dict(
            url=get_url(
                self.request_url,
                self._path,
                *self.ids,
                **self.params
            ),
            method=self._type,
            headers=self.headers,
            json=self.payload
        )

        try:
            response = requests.request(**request_kwargs)
        except Exception as err:
            raise Exception('Request error: %s' % err)

        if not response.ok:
            raise Exception('Analytics Response  Error: %s' % response.status_code)

        return response

    def run(self, is_json_serializable=True):
        response = self._request(is_json_serializable)
        raw_response = json.loads(response.text or 'null')
        return self._response_class(
            data=raw_response,
            code=response.status_code,
            headers=response.headers
        ).parse()


class AnalyticsUserRegistrationRequest(BaseRequest):
    _path = '/api/user/'
    _response_class = AnalyticsUserRegistrationResponse
    is_json = True
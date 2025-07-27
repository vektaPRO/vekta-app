import json
from os import path
import logging
from django.conf import settings
import requests
from httpx import RequestError
from jinja2 import FileSystemLoader, Environment

from api.service.green_api.rest_responses import CreateInstanceResponse, SendMessageResponse, \
    DeleteInstanceResponse, GetMessageResponse, GetInstanceSettingsResponse, SetInstanceSettingsResponse, \
    GenerateQRCodeResponse, GetAuthorizationCodeResponse, LogoutResponse, GetInstanceStatusResponse
from api.service.kaspi.exceptions import RateLimitExceeded
from logger.utils import CabinetLogger
from pktools.http import RequestMethod, get_url
from api.service.green_api.rest_responses import BaseResponse
from pktools.string import generate_string

loader = FileSystemLoader(path.join(path.dirname(__file__), 'Cabinet_JSON'))
env = Environment(loader=loader, trim_blocks=True, lstrip_blocks=True)
logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


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

    def _request(self):
        request_kwargs = {
            'url': get_url(self.request_url,
                           self._path,
                           *self.ids if self.ids else [],
                           ),
            'params': self.params,
            'method': self._type,
            'headers': self._headers(),
            'json': self.data if self.is_json else None,
            'data': self.data if not self.is_json else None,

        }

        # conversation_id = generate_string()

        # self._log_db(
        #     message=json.dumps(self.data, indent=4, default=lambda o: o.__dict__),
        #     cookie=request_kwargs['headers']['Cookie'],
        #     conversation_id=conversation_id, response_code=None, is_error=False, url=request_kwargs['url'],
        # )
        try:
            response = requests.request(**request_kwargs)
        except Exception as err:
            error_message = f'{err}'
            # self._log_db(
            #     message=error_message, conversation_id=conversation_id, response_code=None, is_error=True,
            #     cookie=request_kwargs['headers']['Cookie'], url=request_kwargs['url'],
            # )
            logger.error('#kaspi request error: %s', err)
            raise RequestError(error_message)
        if response.status_code == 429:
            raise RateLimitExceeded('#kaspi response error: %s', str(response.text))
        if not response.ok:
            # self._log_db(
            #     message=response.text, conversation_id=conversation_id, url=request_kwargs['url'],
            #     response_code=response.status_code, is_error=True, cookie=request_kwargs['headers']['Cookie']
            # )
            logger.error('#kaspi response error: %s', response.status_code)
            raise RequestError(response.text)

        # self._log_db(
        #     message=response.text, conversation_id=conversation_id, url=request_kwargs['url'],
        #     response_code=response.status_code, is_error=False, cookie=request_kwargs['headers']['Cookie']
        # )

        return response

    def run(self):
        response = self._request()
        raw_response = json.loads(response.text or 'null')
        return self._response_class(
            data=raw_response,
            code=response.status_code,
            headers=response.headers,
        ).parse()


class CreateInstanceRequest(BaseRequest):
    _path = '/partner/createInstance/%s'
    _type = RequestMethod.POST
    _response_class = CreateInstanceResponse
    is_json = True
    method = 'create_instance'
    headers_template = 'common_headers.json'


class SendMessageRequest(BaseRequest):
    _path = '/waInstance%s/sendMessage/%s'
    _type = RequestMethod.POST
    _response_class = SendMessageResponse
    is_json = True
    method = 'send_message'
    headers_template = 'common_headers.json'


class DeleteInstanceAccount(BaseRequest):
    _path = '/partner/deleteInstanceAccount/%s'
    _type = RequestMethod.POST
    _response_class = DeleteInstanceResponse
    is_json = True
    method = 'delete_instance_account'
    headers_template = 'common_headers.json'


class GetMessageRequest(BaseRequest):
    _path = '/waInstance%s/getMessage/%s'
    _type = RequestMethod.POST
    _response_class = GetMessageResponse
    is_json = True
    method = 'get_message'
    headers_template = 'common_headers.json'


class GetInstanceSettingsRequest(BaseRequest):
    _path = '/waInstance%s/getSettings/%s'
    _type = RequestMethod.GET
    _response_class = GetInstanceSettingsResponse
    is_json = True
    method = 'get_instance_settings'
    headers_template = 'common_headers.json'


class GetInstanceStatusRequest(BaseRequest):
    _path = '/waInstance%s/getStateInstance/%s'
    _type = RequestMethod.GET
    _response_class = GetInstanceStatusResponse
    is_json = True
    method = 'get_instance_status'
    headers_template = 'common_headers.json'


class SetInstanceSettingsRequest(BaseRequest):
    _path = '/waInstance%s/setSettings/%s'
    _type = RequestMethod.POST
    _response_class = SetInstanceSettingsResponse
    is_json = True
    method = 'set_instance_settings'
    headers_template = 'common_headers.json'


class GenerateQRCodeRequest(BaseRequest):
    _path = '/waInstance%s/qr/%s'
    _type = RequestMethod.GET
    _response_class = GenerateQRCodeResponse
    is_json = True
    method = 'generate_qr_code'
    headers_template = 'common_headers.json'


class GetAuthorizationCodeRequest(BaseRequest):
    _path = '/waInstance%s/getAuthorizationCode/%s'
    _type = RequestMethod.POST
    _response_class = GetAuthorizationCodeResponse
    is_json = True
    method = 'get_authorization_code'
    headers_template = 'common_headers.json'


class LogoutRequest(BaseRequest):
    _path = '/waInstance%s/logout/%s'
    _type = RequestMethod.GET
    _response_class = LogoutResponse
    is_json = True
    method = 'logout'
    headers_template = 'common_headers.json'

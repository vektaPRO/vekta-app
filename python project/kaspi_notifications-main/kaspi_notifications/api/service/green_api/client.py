from django.conf import settings

from api.service.green_api.rest_requests import CreateInstanceRequest, SendMessageRequest, \
    DeleteInstanceAccount, GetMessageRequest, GetInstanceSettingsRequest, SetInstanceSettingsRequest, \
    GenerateQRCodeRequest, GetAuthorizationCodeRequest, LogoutRequest, GetInstanceStatusRequest
from api.service.green_api.structs.base import RESTQRCode, RESTAuthorizationCode, RESTLogout, RESTCreateInstance, \
    RESTDeleteInstance, RESTSendMessage, RESTGetMessage, RESTGetInstanceSettings, RESTSetInstanceSettings, \
    RESTGetInstanceStatus


class Client(object):
    request_url = None

    def __init__(self):
        self.request_url = settings.GREEN_API_BASE_URL

    def create_instance(self, name: str = None) -> RESTCreateInstance:
        data = {
            "name": name
        }
        ids = (settings.GREEN_API_PARTNER_TOKEN,)

        instance_request = CreateInstanceRequest(
            request_url=self.request_url,
            ids=ids,
            data=data,
        )
        instance_response = instance_request.run()

        return instance_response

    def delete_instance(self, instance_id: str) -> RESTDeleteInstance:
        data = {
            "idInstance": instance_id,
        }
        ids = (settings.GREEN_API_PARTNER_TOKEN,)
        delete_instance_request = DeleteInstanceAccount(
            request_url=self.request_url,
            ids=ids,
            data=data,
        )

        delete_instance_response = delete_instance_request.run()
        return delete_instance_response

    def send_message(self, instance_id: int,
                     api_token: str,
                     chat_id: str,
                     text: str) -> RESTSendMessage:
        data = {
            'chatId': f'{chat_id}@c.us',
            'message': text
        }
        ids = (instance_id, api_token)

        send_message_request = SendMessageRequest(request_url=self.request_url,
                                                  ids=ids,
                                                  data=data)
        send_message_response = send_message_request.run()

        return send_message_response

    def get_message(self, instance_id: int,
                    api_token: str,
                    chat_id: str,
                    message_id: str) -> RESTGetMessage:
        data = {
            'chatId': f'{chat_id}@c.us',
            'idMessage': message_id,
        }
        ids = (instance_id, api_token)
        get_message_request = GetMessageRequest(request_url=self.request_url,
                                                ids=ids,
                                                data=data)

        get_message_response = get_message_request.run()

        return get_message_response

    def get_instance_settings(self, instance_id: int,
                              api_token: str) -> RESTGetInstanceSettings:
        ids = (instance_id, api_token)
        settings_request = GetInstanceSettingsRequest(request_url=self.request_url,
                                                      ids=ids)

        settings_response = settings_request.run()

        return settings_response

    def get_instance_status(self, instance_id: int,
                            api_token: str) -> RESTGetInstanceStatus:
        ids = (instance_id, api_token)
        status_request = GetInstanceStatusRequest(request_url=self.request_url,
                                                  ids=ids)

        status_response = status_request.run()

        return status_response

    def set_instance_settings(self, instance_id: int,  api_token: str, outgoing_webhook: str = None,
                              outgoing_message_api_webhook: str = None, incoming_webhook: str = None, webhook_url: str = None,
                              webhook_token: str = None, delay_send_messages_milliseconds: int = 0) -> RESTSetInstanceSettings:

        ids = (instance_id, api_token)
        data = {
            "outgoingWebhook": outgoing_webhook,
            "outgoingAPIMessageWebhook": outgoing_message_api_webhook,
            "incomingWebhook": incoming_webhook,
            "webhookUrl": webhook_url,
            "webhookUrlToken": webhook_token,
            "delaySendMessagesMilliseconds": delay_send_messages_milliseconds
        }

        settings_request = SetInstanceSettingsRequest(request_url=self.request_url,
                                                      ids=ids,
                                                      data=data)

        settings_response = settings_request.run()

        return settings_response

    def generate_qr_code(self, instance_id: int, api_token: str) -> RESTQRCode:
        ids = (instance_id, api_token)

        qr_code_request = GenerateQRCodeRequest(request_url=self.request_url,
                                                ids=ids)

        qr_code_response = qr_code_request.run()

        return qr_code_response

    def get_authorization_code(self, instance_id: int, api_token: str, phone_number: int) -> RESTAuthorizationCode:
        ids = (instance_id, api_token)
        data = {
            "phoneNumber": phone_number
        }
        authorization_code_request = GetAuthorizationCodeRequest(request_url=self.request_url,
                                                                 ids=ids,
                                                                 data=data)

        authorization_code_response = authorization_code_request.run()

        return authorization_code_response

    def logout(self, instance_id: int, api_token: str) -> RESTLogout:
        ids = (instance_id, api_token)
        logout_request = LogoutRequest(request_url=self.request_url,
                                       ids=ids)

        logout_response = logout_request.run()

        return logout_response

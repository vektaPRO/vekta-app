from urllib3.exceptions import ResponseError

from api.service.green_api.structs.base import RESTQRCode, RESTAuthorizationCode, RESTLogout, \
    RESTCreateInstance, RESTDeleteInstance, RESTSetInstanceSettings, RESTGetInstanceSettings, RESTGetMessage, \
    RESTSendMessage, RESTGetInstanceStatus


class BaseResponse:
    data = None
    code = None

    def __init__(self, data: dict, code: int, headers: dict):
        self.data = data
        self.code = code
        self.headers = headers

    def parse_response(self):
        raise NotImplementedError

    def parse_errors(self):
        if "error" in self.data:
            return ResponseError(self.data["error"])

    def parse(self):
        self.parse_errors()
        response = self.parse_response()
        return response


class CreateInstanceResponse(BaseResponse):
    def parse_response(self) -> RESTCreateInstance:
        instance = RESTCreateInstance(
            id=self.data["idInstance"],
            api_token=self.data["apiTokenInstance"],
            type=self.data["typeInstance"],
        )
        return instance


class DeleteInstanceResponse(BaseResponse):
    def parse_response(self) -> RESTDeleteInstance:
        instance = RESTDeleteInstance(
            delete_instance_account=self.data["deleteInstanceAccount"],
        )

        return instance


class SendMessageResponse(BaseResponse):
    def parse_response(self) -> RESTSendMessage:
        message = RESTSendMessage(
            id=self.data["idMessage"],
        )
        return message


class GetMessageResponse(BaseResponse):
    def parse_response(self) -> RESTGetMessage:
        message = RESTGetMessage(
            id=self.data["idMessage"],
            type=self.data["type"],
            timestamp=self.data["timestamp"],
            chat_id=self.data["chatId"],
            text=self.data["textMessage"],
            status=self.data["statusMessage"],
            send_by_api=self.data["sendByApi"],
        )

        return message


class GetInstanceSettingsResponse(BaseResponse):
    def parse_response(self) -> RESTGetInstanceSettings:
        instance = RESTGetInstanceSettings(
            wid=self.data["wid"],
            webhook_url=self.data["webhookUrl"],
            webhook_url_token=self.data["webhookUrlToken"],
            delay_send_messages_milliseconds=self.data["delaySendMessagesMilliseconds"],
            outgoing_webhook=self.data["outgoingWebhook"],
            outgoing_api_message_webhook=self.data["outgoingAPIMessageWebhook"],
            incoming_webhook=self.data["incomingWebhook"],
            state_webhook=self.data["stateWebhook"],
        )

        return instance


class GetInstanceStatusResponse(BaseResponse):
    def parse_response(self) -> RESTGetInstanceStatus:
        instance_status = RESTGetInstanceStatus(
            instance_status=self.data["stateInstance"],
        )

        return instance_status


class SetInstanceSettingsResponse(BaseResponse):
    def parse_response(self) -> RESTSetInstanceSettings:
        instance = RESTSetInstanceSettings(
            save_settings=self.data['saveSettings']
        )

        return instance


class GenerateQRCodeResponse(BaseResponse):
    def parse_response(self) -> RESTQRCode:
        qr_code = RESTQRCode(
            type=self.data["type"],
            message=self.data["message"],
        )

        return qr_code


class GetAuthorizationCodeResponse(BaseResponse):
    def parse_response(self) -> RESTAuthorizationCode:
        code_object = RESTAuthorizationCode(
            status=self.data["status"],
            code=self.data["code"],
        )

        return code_object


class LogoutResponse(BaseResponse):
    def parse_response(self) -> RESTLogout:
        logout = RESTLogout(
            is_logout=self.data["isLogout"],
        )

        return logout

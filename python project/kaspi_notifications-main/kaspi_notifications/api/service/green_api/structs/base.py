from dataclasses import dataclass
from typing import Optional


@dataclass
class RESTCreateInstance:
    id: int = 0
    api_token: str = None
    type: str = None


@dataclass
class RESTDeleteInstance:
    delete_instance_account: bool = False


@dataclass
class RESTSetInstanceSettings:
    save_settings: bool = False


@dataclass
class RESTGetInstanceSettings:
    wid: str = None
    webhook_url: str = None
    webhook_url_token: str = None
    state_webhook: str = None
    incoming_webhook: str = None
    outgoing_webhook: str = None
    outgoing_api_message_webhook: str = None
    delay_send_messages_milliseconds: int = 0


@dataclass
class RESTSendMessage:
    id: str = None


@dataclass
class RESTGetInstanceStatus:
    instance_status: str = None


@dataclass
class RESTGetMessage(RESTSendMessage):
    id: str = None
    type: str = None
    timestamp: int = 0
    chat_id: str = None
    text: str = None
    status: str = None
    send_by_api: bool = False


@dataclass
class RESTQRCode:
    type: str = None
    message: str = None


@dataclass
class RESTAuthorizationCode:
    status: bool = False
    code: str = None


@dataclass
class RESTLogout:
    is_logout: bool = None

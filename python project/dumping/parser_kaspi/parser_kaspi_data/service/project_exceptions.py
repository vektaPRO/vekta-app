class ProxyProviderException(BaseException):
    pass


class RetryableHttpClientException(BaseException):
    pass


class RetriesExceededException(BaseException):
    pass


class IncorrectLoginException(BaseException):
    pass


class MerchantSettingsRetrieveException(BaseException):
    pass


class XmlFileLinkIsNone(BaseException):
    pass


class KaspiCabinetSmsSendingException(BaseException):
    pass


class SmsVerificationFailedException(BaseException):
    pass


class KaspiUserCreationFailedException(BaseException):
    pass


class KaspiLoginAlreadyExistsException(BaseException):
    pass

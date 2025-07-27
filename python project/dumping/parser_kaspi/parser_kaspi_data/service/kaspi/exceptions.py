

class ResponseError(Exception):
    pass


class RequestError(Exception):
    pass


class IncorrectLoginException(BaseException):
    pass


class InvalidSessionException(BaseException):
    pass

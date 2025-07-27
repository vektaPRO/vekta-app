import logging
import time
from enum import Enum
from django.conf import settings
from parser_kaspi_data.service.kaspi.exceptions import RequestError


REQUESTS_RETRY_TIMEOUT_SECONDS = 2
logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


class RequestMethod(str, Enum):
    GET = 'GET'
    POST = 'POST'


def get_url(host, path, *ids, **params):
    if path[0] == '/':
        path = path[1:]
    if host[-1] != '/':
        host += '/'
    if ids:
        path = path % ids

    url = host + path
    if params:
        url += '?'
        data = ''
        for k, v in params.items():
            data += f'{k}={v}&'
        url += data[:-1]

    return url


def http_retry_wrapper(retries):
    def decorator(func):
        def wrapper(*args, **kwargs):
            for _ in range(retries):
                try:
                    return func(*args, **kwargs)
                except RequestError as err:
                    if _ == retries - 1:
                        logger.info('Num retries exceeded for %s, args: %s, kwargs: %s',
                                    func.__name__, args, kwargs)
                        raise err
                    else:
                        logger.error('Retryable error occurred during %s.'
                                     ' Retrying after timeout, args: %s, kwargs: %s',
                                     func.__name__, args, kwargs
                                     )
                        time.sleep(REQUESTS_RETRY_TIMEOUT_SECONDS)
                except BaseException as exc:
                    logger.error('Error occurred during %s, error %s', func.__name__, exc)
                    raise exc
            return None
        return wrapper
    return decorator

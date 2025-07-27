import json
import logging
import sys
import traceback
from logging import Logger

from httpx import Headers, Response

from django.conf import settings


def get_logger(name: str) -> Logger:
    logging.basicConfig(
        level=logging.INFO,
        filename='logs.txt',
        force=True,
        format="%(asctime)s:%(name)s:%(levelname)s: %(message)s"
    )

    return logging.getLogger(name)


def format_exception(e) -> str:
    return ''.join(traceback.format_exception(*(sys.exc_info()))) + '\n' + f'{e.__class__}\n' + f'{e.__str__()}\n' + f'{e}\n'


def log_traffic(function, response: Response, uid: str=None) -> None:
    logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)
    headers: Headers = response.headers
    headers_str = json.dumps(headers.multi_items()).replace('\n', '\t').replace('\r', '')
    logger.info(
        f'{function}\t{response.url}\t{response.num_bytes_downloaded} bytes\t{response.elapsed.total_seconds()} seconds\t{headers_str}',
        extra={'uid': uid}
    )

import logging
import json

from django.core.serializers.json import DjangoJSONEncoder


class CabinetLogger(object):
    """
    Class for fast logging Cabinet
    """

    cabinet_logger = logging.getLogger('cabinet_logger')

    @classmethod
    def info(cls, message, **kwargs):
        kwargs['message'] = message.decode() if isinstance(message, bytes) else message
        cls.cabinet_logger.info(json.dumps(kwargs, cls=DjangoJSONEncoder))

    @classmethod
    def warning(cls, message, **kwargs):
        kwargs['message'] = message.decode() if isinstance(message, bytes) else message
        cls.cabinet_logger.warning(json.dumps(kwargs, cls=DjangoJSONEncoder))

    @classmethod
    def error(cls, message, **kwargs):
        kwargs['message'] = message.decode() if isinstance(message, bytes) else message
        cls.cabinet_logger.error(json.dumps(kwargs, cls=DjangoJSONEncoder))

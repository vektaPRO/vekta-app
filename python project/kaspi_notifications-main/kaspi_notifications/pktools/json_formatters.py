# -*- coding: utf-8 -*-
# fork of simple-json-log-formatter=0.5.5 https://pypi.org/project/simple-json-log-formatter/
import logging
import sys
import json
import numbers

import datetime
import traceback
from inspect import istraceback

from pytz import timezone
from django.conf import settings

PYTHON_MAJOR_VERSION = sys.version_info[0]


CRITICAL = 50
FATAL = CRITICAL
ERROR = 40
WARNING = 30
WARN = WARNING
INFO = 20
DEBUG = 10
NOTSET = 0

_levelToName = {
    CRITICAL: 'CRITICAL',
    ERROR: 'ERROR',
    WARNING: 'WARNING',
    INFO: 'INFO',
    DEBUG: 'DEBUG',
    NOTSET: 'NOTSET',
}

DEFAULT_LOG_RECORD_FIELDS = {'name', 'msg', 'args', 'levelname', 'levelno',
                             'pathname', 'filename', 'module', 'exc_info',
                             'exc_class', 'exc_msg', 'exc_traceback',
                             'exc_text', 'stack_info', 'lineno', 'funcName',
                             'created', 'msecs', 'relativeCreated', 'thread',
                             'threadName', 'processName', 'process'}


class SimpleJsonFormatter(logging.Formatter):
    level_to_name_mapping = _levelToName

    def __init__(self, fmt=None, datefmt=None, style='%', serializer=json.dumps):
        super(SimpleJsonFormatter, self).__init__()
        self.serializer = serializer

    @staticmethod
    def _default_json_handler(obj):
        if isinstance(obj, (datetime.date, datetime.time)):
            return str(obj.isoformat())
        elif istraceback(obj):
            tb = ''.join(traceback.format_tb(obj))
            return tb.strip()
        elif isinstance(obj, Exception):
            return "Exception: {}".format(str(obj))
        return str(obj)

    def format(self, record):
        msg = {
            'timestamp': str(datetime.datetime.now(timezone(settings.TIME_ZONE)).strftime('%Y-%m-%dT%H:%M:%S.%f%z')),
            'line_number': record.lineno,
            'function': str(record.funcName),
            'module': str(record.module),
            'level': str(self.level_to_name_mapping[record.levelno]),
            'path': str(record.pathname)
        }

        for field, value in list(record.__dict__.items()):
            if field not in DEFAULT_LOG_RECORD_FIELDS:
                if isinstance(value, numbers.Number):
                    msg[field] = value
                elif value is None:
                    msg[field] = value
                elif type(value) == dict:
                    msg[field] = json.dumps(value)
                else:
                    msg[field] = str(value)

        if isinstance(record.msg, dict):
            msg.update(record.msg)
        elif type(record.msg) is str and '%' in record.msg and len(record.args) > 0:
            try:
                msg['msg'] = (record.msg % record.args)
            except ValueError:
                msg['msg'] = record.msg
        else:
            msg['msg'] = record.msg

        if record.exc_info:
            msg['exc_class'], msg['exc_msg'], msg['exc_traceback'] = record.exc_info

        return str(self.serializer(msg, default=self._default_json_handler))
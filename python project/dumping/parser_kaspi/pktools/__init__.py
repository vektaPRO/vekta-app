from datetime import datetime
import time


class ObjectJSON(dict):

    def __getattr__(self, item):
        try:
            return self[item]
        except KeyError:
            raise AttributeError

    def __setattr__(self, key, value):
        self[key] = value


class JSONSerializable(object):
    def tolist(self):
        """ for kombu(celery) json encoder"""
        return self.__dict__

    def __json__(self):
        """ for rest-framework json encoder"""
        return self.__dict__


def to_json(obj):
    if isinstance(obj, datetime):
        return time.mktime(obj.timetuple())
    TypeError(repr(obj) + ' is not JSON serializable')

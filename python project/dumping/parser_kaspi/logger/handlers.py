import json
import logging
from logging import Handler
from django.conf import settings


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


class DBHandler(Handler, object):
    """
    This log handler writes messages to a database model defined in settings.py
    If log message is a json string, it will try to apply the array onto the log event object
    """

    model_name = None
    db_name = 'logger'

    def __init__(self, model=""):
        super(DBHandler, self).__init__()
        self.model_name = model

    def emit(self, record):
        # Big try block here to forward record to a file if exception occurred
        try:
            # instantiate the model
            try:
                model = self.get_model(self.model_name)
            except: # noqa
                from logger.models import GeneralLog as model

            log_entry = model(level=record.levelname, message=self.format(record))

            # check if msg is json and apply to log record object
            try:
                data = json.loads(record.msg)
                for k, v in list(data.items()):
                    if hasattr(log_entry, k):
                        try:
                            setattr(log_entry, k, v)
                        except:
                            pass
            except: # noqa
                pass

            log_entry.save(using=self.db_name)
        except Exception as e:
            try:
                db_log_dict = json.loads(record.msg)
                logger.log(record.levelno, record.msg)
            except Exception as err:
                logger.error('Could not log: %s', err)
            logger.error(e)

    def get_model(self, name):
        names = name.split('.')
        mod = __import__('.'.join(names[:-1]), fromlist=names[-1:])
        return getattr(mod, names[-1])

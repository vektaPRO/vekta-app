from .base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True


ALLOWED_HOSTS = [
    'sharex.sky-ddns.kz', 'www.sharex.sky-ddns.kz',
    '127.0.0.1', 'localhost', 'web'
]

DEFAULT_LOGGER_NAME = CONSOLE_LOGGER_NAME = 'notify'

DEFAULT_LOGGER_HANDLERS = ['console', 'default_file']
DB_LEVEL = 'WARNING'


LOGGING = {
    'version': 1,
    'disable_existing_loggers': True,
    'root': {
        'level': 'WARNING',
        'handlers': ['console'],
    },
    'formatters': {
        'general': {
            'format': '%(asctime)s %(levelname)s\t%(message)s',
            # 'datefmt': '%m/%d %H:%M:%S'
        },
        'json': {
            '()': 'pktools.json_formatters.SimpleJsonFormatter'
        },
        'verbose': {
            'format': '%(asctime)s %(levelname)s %(process)d %(thread)d\t%(message)s',
            'datefmt': '%m/%d %H:%M:%S'
        }
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse'
        }
    },

    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'stream': sys.stdout,
            'formatter': 'general'
        },
        'default_file': {
            'level': 'INFO',
            'class': 'logging.handlers.WatchedFileHandler',
            'filename': rel_to(LOG_DIR, 'default.log'),
            'formatter': 'json',
        },
        'db_file': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': rel_to(LOG_DIR, 'db.log'),
            'maxBytes': 1024 * 1024 * 50,
            'backupCount': 5,
            'formatter': 'verbose',
        },
        'cabinet_db_log_handler': {
            'level': 'INFO',
            'class': 'logger.handlers.DBHandler',
            'model': 'logger.models.CabinetLog',
            'formatter': 'verbose'
        }
    },

    'loggers': {
        'django.request': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'django.db.backends': {
            'handlers': ['db_file'],
            'level': DB_LEVEL,
            'propagate': True,
        },
        DEFAULT_LOGGER_NAME: {
            'handlers': DEFAULT_LOGGER_HANDLERS,
            'level': 'DEBUG',
            'propagate': True,
        },
        'cabinet_logger': {
            'handlers': ['cabinet_db_log_handler'],
            'level': 'INFO',
            'propagate': False
        }
    }
}


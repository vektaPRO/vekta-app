import os

from .base import *
from dotenv import load_dotenv


load_dotenv()

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False


STATIC_ROOT = BASE_DIR / 'productionfiles'

STATIC_URL = 'static/'


# for media files
DEFAULT_FILE_STORAGE = 'parser_kaspi.storages.PublicMediaStorage'



LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
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

    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
        'default_log_handler': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR.parent.parent / 'logs' / 'default.log',
            'backupCount': 500,
            'maxBytes': 15 * 1024 * 1024,  # 15 MB
            'formatter': 'json'
        },
        'auth_log_handler': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR.parent.parent / 'logs' / 'auth.log',
            'backupCount': 500,
            'maxBytes': 15 * 1024 * 1024,  # 15 MB
            'formatter': 'json'
        },
        'metrics_log_handler': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR.parent.parent / 'logs' / 'metrics.log',
            'backupCount': 100,
            'maxBytes': 15 * 1024 * 1024,  # 15 MB
            'formatter': 'json'
        },
        'storage_log_handler': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR.parent.parent / 'logs' / 'storage.log',
            'backupCount': 100,
            'maxBytes': 5 * 1024 * 1024,
            'formatter': 'json',
        },
        'proxy_log_handler': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': BASE_DIR.parent.parent / 'logs' / 'proxy.log',
            'backupCount': 100,
            'maxBytes': 5 * 1024 * 1024,
            'formatter': 'json'
        },
        'cabinet_db_log_handler': {
            'level': 'INFO',
            'class': 'logger.handlers.DBHandler',
            'model': 'logger.models.CabinetLog',
            'formatter': 'verbose'
        }
    },

    'loggers': {
        DEFAULT_LOGGER_NAME: {
            'handlers': ['default_log_handler'],
            'level': 'INFO',
            'propagate': True
        },
        AUTH_LOGGER_NAME: {
            'handlers': ['auth_log_handler'],
            'level': 'INFO',
            'propagate': True
        },
        METRICS_LOGGER_NAME: {
            'handlers': ['metrics_log_handler'],
            'level': 'INFO',
            'propagate': True
        },
        STORAGE_LOGGER_NAME: {
            'handlers': ['storage_log_handler'],
            'level': 'INFO',
            'propagate': True,
        },
        PROXY_LOGGER_NAME: {
            'handlers': ['proxy_log_handler'],
            'level': 'INFO',
            'propagate': True
        },
        'django': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': True,
        },
        'django.request': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG',
        },
        'cabinet_logger': {
            'handlers': ['cabinet_db_log_handler'],
            'level': 'INFO',
            'propagate': False
        }
    }
}


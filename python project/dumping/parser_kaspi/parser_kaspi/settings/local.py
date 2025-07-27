from .base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True
DEFAULT_FILE_STORAGE = 'django.core.files.storage.FileSystemStorage'

MEDIA_URL = '/'
MEDIA_ROOT = os.path.join(BASE_DIR, '..')


LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,

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
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'stream': sys.stdout,
            'formatter': 'general'
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
            'handlers': ['default_log_handler', 'console'],
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


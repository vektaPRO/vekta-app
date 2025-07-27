from .base import *


DEBUG = False

sentry_sdk.init(
    dsn=get_env_variable('SENTRY_DSN'),
    integrations=[DjangoIntegration()],
    traces_sample_rate=1.0,
    send_default_pii=True,
)

STATIC_ROOT = BASE_DIR / 'productionfiles'

ALLOWED_HOSTS = [
    'sharex.sky-ddns.kz', 'www.sharex.sky-ddns.kz',
    '127.0.0.1', 'localhost', 'web'
]

DEFAULT_LOGGER_NAME = CONSOLE_LOGGER_NAME = 'notify'

DEFAULT_LOGGER_HANDLERS = ['default_file', 'sentry']
DB_LEVEL = 'ERROR'


LOGGING = {
    'version': 1,
    'disable_existing_loggers': True,
    'root': {
        'level': 'WARNING',
        # 'handlers': ['console'],
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
        'gunicorn': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'formatter': 'verbose',
            'filename': rel_to(LOG_DIR, 'gunicorn.log'),
            'maxBytes': 1024 * 1024 * 100,
        },
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
            'class': 'logging.FileHandler',
            'filename': rel_to(LOG_DIR, 'db.log'),
            'formatter': 'verbose',
        },
        'sentry': {
            'level': 'ERROR',
            'class': 'sentry_sdk.integrations.logging.EventHandler'
        },
        'cabinet_db_log_handler': {
            'level': 'INFO',
            'class': 'logger.handlers.DBHandler',
            'model': 'logger.models.CabinetLog',
            'formatter': 'verbose'
        }
        # TODO cabinet db log
    },

    'loggers': {
        'django': {
            'handlers': DEFAULT_LOGGER_HANDLERS,
            'level': 'ERROR',
            'propagate': True,
        },
        'django.request': {
            'handlers': ['sentry'],
            'level': 'ERROR',
            'propagate': False,
        },
        'gunicorn.errors': {
            'handlers': ['gunicorn', 'sentry'],
            'level': 'ERROR',
            'propagate': True,
        },
        'django.db.backends': {
            'handlers': ['db_file', 'sentry'],
            'level': DB_LEVEL,
            'propagate': True,
        },
        DEFAULT_LOGGER_NAME: {
            'handlers': DEFAULT_LOGGER_HANDLERS,
            'level': 'INFO',
            'propagate': True,
        },
        'cabinet_logger': {
            'handlers': ['cabinet_db_log_handler'],
            'level': 'INFO',
            'propagate': False
        }
        # TODO cabinet log
    }
}

LOGGER_DATABASES = ['logger']


DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('MASTER_DB_NAME'),
        'USER': os.getenv('MASTER_DB_USER'),
        'PASSWORD': os.getenv('MASTER_DB_PASSWORD'),
        'HOST': os.getenv('MASTER_DB_HOST'),
        'CONN_MAX_AGE': 0,
        'DISABLE_SERVER_SIDE_CURSORS': True,
    },
    'replica': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('REPLICA_DB_NAME'),
        'USER': os.getenv('REPLICA_DB_USER'),
        'PASSWORD': os.getenv('REPLICA_DB_PASSWORD'),
        'HOST': os.getenv('REPLICA_DB_HOST'),
        'CONN_MAX_AGE': 0,
        'DISABLE_SERVER_SIDE_CURSORS': True,
    },
    'logger': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('LOGGER_DB_NAME'),
        'USER': os.getenv('LOGGER_POSTGRES_USER'),
        'PASSWORD': os.getenv('LOGGER_POSTGRES_PASSWORD'),
        'HOST': os.getenv('LOGGER_DB_HOST'),
        'PORT': os.getenv('LOGGER_DB_PORT')
    }
}

DATABASE_ROUTERS = ['kaspi_notifications.router.ReplicaRouter']

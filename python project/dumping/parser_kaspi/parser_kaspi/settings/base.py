import os
import sys
import dj_database_url
from pathlib import Path
from dotenv import load_dotenv


load_dotenv()

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/4.2/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.getenv('SECRET_KEY')

ALLOWED_HOSTS = ['*', '164.90.181.189', 'irocket.sky-ddns.kz']


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_celery_beat',
    'rest_framework',
    'django_filters',
    'corsheaders',
    'rest_framework.authtoken',
    'parser_kaspi_data',
    'pktools',
    'import_export',
    'logger',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
]

ROOT_URLCONF = 'parser_kaspi.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'parser_kaspi.wsgi.application'


# Database
# https://docs.djangoproject.com/en/4.2/ref/settings/#databases

# DATABASES = {
#     'default': {
#         'ENGINE': os.getenv('DB_ENGINE', 'django.db.backends.postgresql'),
#         'NAME': os.getenv('DB_NAME'),
#         'USER': os.getenv('POSTGRES_USER'),
#         'PASSWORD': os.getenv('POSTGRES_PASSWORD'),
#         'HOST': os.getenv('DB_HOST'),
#         'PORT': os.getenv('DB_PORT')
#     }
# }

DATABASES = {
    'default': dj_database_url.config(),
    'logger': {
        'ENGINE': os.getenv('LOGGER_DB_ENGINE', 'django.db.backends.postgresql'),
        'NAME': os.getenv('LOGGER_DB_NAME'),
        'USER': os.getenv('LOGGER_POSTGRES_USER'),
        'PASSWORD': os.getenv('LOGGER_POSTGRES_PASSWORD'),
        'HOST': os.getenv('LOGGER_DB_HOST'),
        'PORT': os.getenv('LOGGER_DB_PORT')
    }
}
DATABASES['default']['DISABLE_SERVER_SIDE_CURSORS'] = True


# Password validation
# https://docs.djangoproject.com/en/4.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/4.2/topics/i18n/

LANGUAGE_CODE = 'ru'

TIME_ZONE = 'Asia/Almaty'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/4.2/howto/static-files/

STATIC_URL = '/static/'
# STATIC_ROOT = os.path.join(BASE_DIR, 'static')
STATICFILES_DIRS = [
    BASE_DIR / 'static'
]
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Default primary key field type
# https://docs.djangoproject.com/en/4.2/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],

    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],

    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 10,
}

CSRF_TRUSTED_ORIGINS = ['http://*.127.0.0.1', 'http://164.90.181.189', 'http://irocket.sky-ddns.kz', 'https://irocket.sky-ddns.kz']

AUTH_USER_MODEL = 'parser_kaspi_data.CustomUser'
ACCOUNT_USER_MODEL_USERNAME_FIELD = None
ACCOUNT_USERNAME_REQUIRED = False

CORS_ALLOWED_ORIGINS = [
    'http://localhost:5173',
    'http://irocket.sky-ddns.kz',
    'https://irocket.sky-ddns.kz',
    'https://irocket-five.vercel.app',
    'https://irocket-xi.vercel.app',
    'https://irocket.kz',
    # 'http://159.89.160.51/',
    'https://sharex.kz',
    'https://app.sharex.kz',
    'https://app.irocket.kz'
]

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        'LOCATION': os.getenv('REDIS_URL')
    }
}

CACHE_TTL = 60 * 5

LOGGER_DATABASES = ['logger']


DEFAULT_LOGGER_NAME = 'parser_kaspi.default'
AUTH_LOGGER_NAME = 'parser_kaspi.auth'
METRICS_LOGGER_NAME = 'parser_kaspi.metrics'
STORAGE_LOGGER_NAME = 'parser_kaspi.storage'
PROXY_LOGGER_NAME = 'parser_kaspi.proxy'

HORIZONTAL_SCALING = os.getenv('HORIZONTAL_SCALING') == 'true'

# There are 2 queues: default, rasberry
# default queue tasks process on DO vms
# raspberry queue tasks process on Raspberry
# if raspberry is off, all task must process in DO vms
# else parsing task will process in Raspberry
RASPBERRY_ON_PROD = os.getenv('RASPBERRY_ON_PROD') == 'true'

CELERY_TASK_DEFAULT_QUEUE = 'default'
CELERY_TASK_RASPBERRY_QUEUE = 'raspberry'
CELERY_TASK_PARSE_PRODUCTS_QUEUE = CELERY_TASK_RASPBERRY_QUEUE if RASPBERRY_ON_PROD else CELERY_TASK_DEFAULT_QUEUE

CELERY_TASK_ROUTES = {
    'parser_kaspi.periodic.check_proxies_balance': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.periodic.check_left_day': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.periodic.sync_products_with_cabinet': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.periodic.prepare_and_distribute_products_process': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.tasks.healthcheck_other_services': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.tasks.notify_user_registration_telegram_channel': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.tasks.send_message_green_api': CELERY_TASK_DEFAULT_QUEUE,
    'parser_kaspi.tasks.process_products': CELERY_TASK_RASPBERRY_QUEUE,
}

CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers.DatabaseScheduler'


WHATSAPP_CREATE_URL = os.getenv('WHATSAPP_CREATE_URL')
WHATSAPP_VERIFY_URL = os.getenv('WHATSAPP_VERIFY_URL')
WHATSAPP_AUTH_TOKEN = os.getenv('WHATSAPP_AUTH_TOKEN')

MERCHANT_CABINET_BASE_URL = os.getenv('MERCHANT_CABINET_BASE_URL')
MERCHANT_CABINET_API_BASE_URL = os.getenv('MERCHANT_CABINET_API_BASE_URL')
ANALYTICS_SERVICE_URL = os.getenv('ANALYTICS_SERVICE_URL')
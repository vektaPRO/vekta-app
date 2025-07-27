import os
import sys
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from pathlib import Path
from .variables import *


# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True


# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent.parent
PROJECT_PATH = os.path.abspath(os.path.dirname(__file__) + '/../..')


def rel(*x):
    return os.path.join(PROJECT_PATH, *x)


def rel_to(to, *x):
    return os.path.join(to, *x)


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/4.2/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = get_env_variable('SECRET_KEY')


ALLOWED_HOSTS = [
    'sharex.sky-ddns.kz', 'www.sharex.sky-ddns.kz',
    '127.0.0.1', 'localhost'
]


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'django_filters',
    'django_celery_beat',
    'pktools',
    'notifications',
    'api',
    'logger'
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'kaspi_notifications.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [
            os.path.join(BASE_DIR, 'notifications/templates')
        ],
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

WSGI_APPLICATION = 'kaspi_notifications.wsgi.application'

LOGGER_DATABASES = ['logger']


# Database
# https://docs.djangoproject.com/en/4.2/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': get_env_variable('DB_ENGINE'),
        'NAME': get_env_variable('DB_NAME'),
        'USER': get_env_variable('POSTGRES_USER'),
        'PASSWORD': get_env_variable('POSTGRES_PASSWORD'),
        'HOST': get_env_variable('DB_HOST'),
        'PORT': get_env_variable('DB_PORT'),
        'DISABLE_SERVER_SIDE_CURSORS': True
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
STATICFILES_DIRS = [
    BASE_DIR / 'static'
]

STATIC_ROOT = BASE_DIR / 'productionfiles'
# # STATIC_ROOT = ''
# STATIC_URL = '/static/'

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Default primary key field type
# https://docs.djangoproject.com/en/4.2/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

CSRF_TRUSTED_ORIGINS = ['https://sharex.sky-ddns.kz', 'http://*.127.0.0.1', 'https://new-sharex.sky-ddns.kz']

AUTH_USER_MODEL = 'notifications.CustomUser'
LOGIN_URL = '/admin/login/'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'api.custom_authentication.IrocketAuthentication',
    )
}

WORK_ROOT = rel_to('..', '..',)
LOGS_FOLDER = get_env_or_default('LOGS_FOLDER', rel_to(WORK_ROOT, 'logs'))
LOG_DIR = rel_to(LOGS_FOLDER, 'notify')


CELERY_ENABLE_UTC = True
CELERY_TIMEZONE = 'Asia/Almaty'


CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers.DatabaseScheduler'
CELERY_TASK_DEFAULT_QUEUE = 'default'
CELERY_TASK_MERCHANT_QUEUE = 'merchant'


CELERY_TASK_ROUTES = {
    'kaspi_notifications.tasks.force_notify_orders_2_review': CELERY_TASK_DEFAULT_QUEUE,
    'kaspi_notifications.tasks.process_merchant_new_orders': CELERY_TASK_MERCHANT_QUEUE,
    'kaspi_notifications.periodic.parse_new_orders': CELERY_TASK_DEFAULT_QUEUE,
    'kaspi_notifications.periodic.process_delivered_orders': CELERY_TASK_MERCHANT_QUEUE,
}


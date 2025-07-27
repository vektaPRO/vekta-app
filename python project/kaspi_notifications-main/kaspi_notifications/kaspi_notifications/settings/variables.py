import os

from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

load_dotenv()


def get_env_variable(var_name):
    try:
        return os.environ[var_name]
    except KeyError:
        error_msg = 'Set the %s environment variable' % var_name
        raise ImproperlyConfigured(error_msg)


def get_env_or_default(var_name, default):
    return os.environ.get(var_name, default)


#tg bot config
TG_BOT_TOKEN = get_env_variable('TG_BOT_TOKEN')
CHAT_ID = get_env_variable('CHAT_ID')

#sign_up_tg_bot
SIGN_UP_TG_TOKEN = get_env_variable('SIGN_UP_TG_TOKEN')
SIGN_UP_TG_TOKEN_TEST = get_env_variable('SIGN_UP_TG_TOKEN_TEST')
ROBOKASSA_PAYMENT_TOKEN = get_env_variable('ROBOKASSA_PAYMENT_TOKEN')
GREEN_API_PARTNER_TOKEN = get_env_variable('GREEN_API_PARTNER_TOKEN')
KASPI_BASE_URL = get_env_variable('KASPI_BASE_URL')
GREEN_API_BASE_URL = get_env_variable('GREEN_API_BASE_URL')
CORE_SERVICE_URL = get_env_variable('CORE_SERVICE_URL')
KASPI_ORDER_REVIEW_URL = get_env_variable('KASPI_ORDER_REVIEW_URL')
USE_REPLICA_DATABASE = get_env_or_default('USE_REPLICA_DATABASE', 'false').lower() == 'true'
NEW_ORDERS_PERIODIC_MINUTES = get_env_or_default('NEW_ORDERS_PERIODIC_MINUTES', 20)

#IRocket GreenAPI instance
IROCKET_INSTANCE_ID=get_env_variable('IROCKET_INSTANCE_ID')
IROCKET_INSTANCE_TOKEN=get_env_variable('IROCKET_INSTANCE_TOKEN')

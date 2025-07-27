import requests
import logging
from django.conf import settings
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth import get_user_model

from notifications.models import Merchant

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class IrocketAuthentication(BaseAuthentication):
    keyword = ['Bearer', 'Token']

    def authenticate(self, request):
        auth = get_authorization_header(request).split()

        if not auth:
            return None
        if len(auth) == 1:
            msg = 'Invalid token header. No credentials provided.'
            raise AuthenticationFailed(msg)
        elif len(auth) > 2:
            msg = 'Invalid token header. Token string should not contain spaces.'
            raise AuthenticationFailed(msg)

        try:
            token = auth[1].decode()
            token_type = auth[0].decode().lower()
        except UnicodeError:
            msg = 'Invalid token header. Token string should not contain invalid characters.'
            raise AuthenticationFailed(msg)

        if token_type not in [k.lower() for k in self.keyword]:
            raise AuthenticationFailed(f'Unsupported token type: {token_type.title()}')

        return self.authentication_credentials(token)

    def authentication_credentials(self, key):
        url = f'{settings.CORE_SERVICE_URL}/token/{key}/'
        logger.info('Fetching user credentials from core service', extra={
            'token': key,
            'core_service_url': url,
        })

        try:
            response = requests.get(url)
            if response.status_code == 200:
                data = response.json()
                logger.info('Successfully fetched credentials from core service', extra={
                    'response_status': response.status_code,
                    'response': data,
                })
            else:
                logger.error('Failed to retrieve user credentials from core service', extra={
                    'token': key,
                    'response_status': response.status_code,
                    'error': response.text,
                })
                raise AuthenticationFailed(f'error: {response.text}', response.status_code)

        except requests.exceptions.RequestException as e:
            logger.error('Error fetching credentials from core service' + str(e), extra={
                'token': key,
                'error': str(e),
            })
            raise AuthenticationFailed('Failed to retrieve user credentials from core service.')

        user_data = data.get('user', '')
        phone_number = user_data.get('phone_number', '')
        email = user_data.get('email', '')
        full_name = user_data.get('full_name', 'Unnamed User').strip()
        user_id = user_data.get('id', '')

        name_parts = full_name.split()
        first_name = name_parts[0] if len(name_parts) > 0 else ''
        last_name = name_parts[1] if len(name_parts) > 1 else ''

        user, created = get_user_model().objects.get_or_create(
            core_id=user_id,
            defaults={
                'email': email if email else '',
                'first_name': first_name,
                'last_name': last_name,
            }
        )
    # TODO decide how to create Merchant and link to User

    #     merchant, _ = Merchant.objects.get_or_create(user=user)
    #     merchant.phone_number = phone_number
    #     merchant.save()

        if created:
            logger.info('New user created', extra={
                'phone_number': phone_number,
                'email': email,
                'user_id': user_id,
            })

        return user, key

    def get_authenticate_header(self, request):
        return self.keyword

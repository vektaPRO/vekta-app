import logging

from django.conf import settings

from parser_kaspi_data.service.analytics.rest_requests import BaseRequest, AnalyticsUserRegistrationRequest

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class AnalyticsClient(object):

    def __init__(self, request_url=None):
        self.request_url = request_url or settings.ANALYTICS_SERVICE_URL

    @staticmethod
    def process_request(request: BaseRequest, method: str):
        try:
            data = request.run()
            return data
        except Exception as err:
            logger.exception('Client.%s: request error %s' % (method, err))

    def register_based_on_token(self, token):
        return self.process_request(
            request=AnalyticsUserRegistrationRequest(
                request_url=self.request_url,
                headers={'Authorization': 'Token %s' % token},
            ),
            method='register_based_on_token'
        )

from rest_framework import status

from parser_kaspi_data.service.kaspi.exceptions import ResponseError
from parser_kaspi_data.service.kaspi.rest_responses import BaseResponse


class AnalyticsUserRegistrationResponse(BaseResponse):

    def parse_errors(self):
        if self.code != status.HTTP_200_OK:
            raise ResponseError(self.data)

    def parse_response(self):
        user_data = self.data.get('user', None)
        bot_link = self.data.get('bot_link', None)

        if user_data and bot_link:
            subscription_days = user_data.get("subscription_days", 0)
            return {
                "subscription_days": subscription_days,
                "bot_link": bot_link
            }
        else:
            raise ResponseError("Invalid response data")
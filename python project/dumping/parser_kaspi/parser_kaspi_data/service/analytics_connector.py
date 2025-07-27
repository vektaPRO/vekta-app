from parser_kaspi_data.service.analytics.client import AnalyticsClient


class AnalyticsConnector:
    def __init__(self):
        self.client = AnalyticsClient()

    def register_user_based_on_token(self, token):
        user = self.client.register_based_on_token(token=token)
        return user


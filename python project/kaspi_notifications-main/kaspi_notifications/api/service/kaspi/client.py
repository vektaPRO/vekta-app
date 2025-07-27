import logging
from django.conf import settings
from api.service.kaspi.rest_requests import OrderListRequest, OrderEntriesRequest, \
    OrderEntriesProductRequest, ConfirmNewOrderRequest

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class Client(object):
    request_url = None
    auth_token = None
    kaspi_shop_uid = None

    def __init__(self, auth_token, kaspi_shop_uid):
        self.request_url = settings.KASPI_BASE_URL
        self.auth_token = auth_token
        self.kaspi_shop_uid = kaspi_shop_uid

    def _headers(self):
        return dict(kaspi_shop_uid=self.kaspi_shop_uid,
                    kaspi_token=self.auth_token)

    def get_orders(self, order_state=None, order_status=None, order_code=None, start_date=None,
                   finish_date=None, page=None, page_size=None, merchant_name=None, merchant_id=None, uid=None):
        extra_data = {
            'kaspi_shop_uid': self.kaspi_shop_uid,
            'merchant_pk': merchant_id,
            'uid': uid,
        }

        if order_code is not None:
            extra_data.update({'order_code': order_code})
        else:
            extra_data.update({'order_state': order_state,
                               'start_date': start_date,
                               'finish_date': finish_date
                               })

        logger.info("#Kaspi.client.get_orders, obtaining orders of merchant %s",
                    merchant_name, extra=extra_data)

        params = {
            'page[number]': page,
            'page[size]': page_size,
            'filter[orders][state]': order_state,
            'filter[orders][status]': order_status,
            'filter[orders][code]': order_code,
            'filter[orders][creationDate][$ge]': start_date,
            'filter[orders][creationDate][$le]': finish_date,
        }

        order_request = OrderListRequest(request_url=self.request_url,
                                         headers=self._headers(),
                                         params=params, )
        order_response = order_request.run()

        return order_response

    def get_order_entries(self, order_id: str, merchant_name=None, merchant_id=None, uid=None):
        extra_data = {
            'merchant_name': merchant_name,
            'kaspi_shop_uid': self.kaspi_shop_uid,
            'merchant_pk': merchant_id,
            'uid': uid,
        }
        logger.info("#Kaspi.client.get_order_entries, obtaining order entries by order_id: %s",
                    order_id, extra=extra_data)

        order_entries_request = OrderEntriesRequest(request_url=self.request_url,
                                                    headers=self._headers(),
                                                    ids=(order_id,))

        order_entries_response = order_entries_request.run()

        return order_entries_response

    def get_order_entries_product(self, entry_id: str, merchant_name=None, merchant_id=None, uid=None):
        extra_data = {
            'merchant_name': merchant_name,
            'kaspi_shop_uid': self.kaspi_shop_uid,
            'merchant_pk': merchant_id,
            'uid': uid,
        }
        logger.info("#Kaspi.client.get_order_entries_product, obtaining product by order's entry_id: %s",
                    entry_id, extra=extra_data)
        order_entries_request = OrderEntriesProductRequest(request_url=self.request_url,
                                                           headers=self._headers(),
                                                           ids=(entry_id,))
        order_entries_response = order_entries_request.run()

        return order_entries_response

    def confirm_new_order(self, order_id=None, order_code=None, merchant_id=None, merchant_name=None, uid=None):
        extra_data = {
            'merchant_name': merchant_name,
            'kaspi_shop_uid': self.kaspi_shop_uid,
            'merchant_pk': merchant_id,
            'uid': uid,
        }
        payload = {
            "data": {
                "type": "orders",
                "id": order_id,
                "attributes": {
                    "code": order_code,
                    "status": "ACCEPTED_BY_MERCHANT"
                }
            }
        }
        logger.info("#Kaspi.client.confirm_new_order, new order is confirming by order_id: %s and order_code: %s",
                    order_id, order_code, extra=extra_data)
        confirm_new_order_request = ConfirmNewOrderRequest(request_url=self.request_url,
                                                           headers=self._headers(),
                                                           data=payload)
        confirm_new_order_response = confirm_new_order_request.run()

        return confirm_new_order_response

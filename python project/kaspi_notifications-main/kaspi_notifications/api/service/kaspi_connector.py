import time
from django.conf import settings
from rest_framework.exceptions import AuthenticationFailed, ParseError
from api.service.kaspi.client import Client
from notifications.models import Merchant
from pktools.string import generate_string
from pktools.date import get_date_range_in_ms
import logging

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class KaspiConnector:
    ORDER_STATE_NEW = 'NEW'
    ORDER_STATE_KASPI_DELIVERY = 'KASPI_DELIVERY'
    ORDER_STATE_DELIVERY = 'DELIVERY'
    ORDER_STATE_PICKUP = 'PICKUP'
    ORDER_STATE_SIGN_REQUIRED = 'SIGN_REQUIRED'

    ORDER_STATUS_ACCEPTED_BY_MERCHANT = 'ACCEPTED_BY_MERCHANT'
    ORDER_STATUS_APPROVED_BY_BANK = 'APPROVED_BY_BANK'

    REQUESTS_RETRY_TIMEOUT_SECONDS = 2
    DEFAULT_ORDER_STATES = [
        ORDER_STATE_NEW, ORDER_STATE_KASPI_DELIVERY, ORDER_STATE_DELIVERY,
        ORDER_STATE_PICKUP, ORDER_STATE_SIGN_REQUIRED
    ]
    DEFAULT_ORDER_STATUSES = [
        ORDER_STATUS_ACCEPTED_BY_MERCHANT, ORDER_STATUS_APPROVED_BY_BANK
    ]

    def __init__(self, merchant: Merchant):
        self.client = Client(merchant.kaspi_token, merchant.kaspi_shop_uid)
        self.merchant = merchant

    @staticmethod
    def is_merchant_exists(merchant_name=None, kaspi_token=None, kaspi_shop_uid=None, uid=None):
        """
        Checks the merchant exists in Kaspi. Returns True if a 400 error is encountered, indicating the merchant
        exists in Kaspi. Returns False in cases of AuthenticationFailed or other exceptions.
        """
        uid = uid or generate_string()
        extra_data = {
            "merchant_name": merchant_name,
            "kaspi_token": kaspi_token,
            "kaspi_shop_uid": kaspi_shop_uid,
            "uid": uid
        }
        client = Client(kaspi_token, kaspi_shop_uid)

        try:
            client.get_orders()
        except ParseError:
            logger.info("#KaspiConnector.is_merchant_exists. Merchant is verified",
                        extra=extra_data)
            return True
        except AuthenticationFailed as e:
            logger.info("#KaspiConnector.is_merchant_exists. Authentication failed. Exception: %s", e,
                        extra=extra_data)
            return False
        except BaseException as err:
            logger.error('#KaspiConnector.is_merchant_exists. Request error %s.', err, extra=extra_data)
            return False

    def get_orders_by_state(self, order_state=None, order_statuses=None, start_date=None,
                            finish_date=None, uid=None):
        # get orders by state
        uid = uid or generate_string()

        # TODO async
        order_statuses = order_statuses or self.DEFAULT_ORDER_STATUSES

        """
        Converts provided dates to milliseconds; uses default range if not provided. The default date range starts
        two days before midnight of the current day and ends two days after, just before midnight.
        """

        start_date_ms, finish_date_ms = get_date_range_in_ms(start_date, finish_date)

        # To log extra details
        extra_data = {
            'start_date': start_date,
            'finish_date': finish_date,
            'merchant_name': self.merchant.name,
            'kaspi_shop_uid': self.merchant.kaspi_shop_uid,
            'merchant_pk': self.merchant.pk,
            'uid': uid
        }

        orders = []
        current_page = 0
        loop = True
        while loop:
            try:
                orders_per_page = self.client.get_orders(order_state=order_state,
                                                         order_status=order_statuses,
                                                         start_date=start_date_ms,
                                                         finish_date=finish_date_ms,
                                                         page=current_page,
                                                         page_size=100,
                                                         merchant_name=self.merchant.name,
                                                         merchant_id=self.merchant.pk,
                                                         uid=uid)

                orders.extend(orders_per_page.data)

                if current_page + 1 >= orders_per_page.page_count:
                    break

                current_page += 1

            except BaseException as err:
                logger.error("#KaspiConnector.get_orders_by_state"
                             " request error: %s", err, extra=extra_data)
                for _ in range(3):
                    try:
                        time.sleep(KaspiConnector.REQUESTS_RETRY_TIMEOUT_SECONDS)
                        orders_per_page = self.client.get_orders(order_state=order_state,
                                                                 order_status=order_statuses,
                                                                 start_date=start_date_ms,
                                                                 finish_date=finish_date_ms,
                                                                 page=current_page,
                                                                 page_size=100,
                                                                 merchant_name=self.merchant.name,
                                                                 merchant_id=self.merchant.pk,
                                                                 )
                        if orders_per_page.data:
                            orders.extend(orders_per_page.data)
                            break
                    except BaseException as exc:
                        logger.error('#KaspiConnector.get_orders_by_state'
                                     ' request retry error %s', exc, extra=extra_data)
                loop = False
        logger.info("#KaspiConnector.get_orders_by_state response successful. Total order count: %s. State: %s",
                    orders.__len__(), order_state, extra=extra_data)

        return orders

    def get_orders(self, order_states=None, order_statuses=None, start_date=None, finish_date=None, uid=None):
        """
        Get all orders
        order_statuses: default = KaspiConnector.DEFAULT_ORDER_STATUSES
        order_states: default = KaspiConnector.DEFAULT_ORDER_STATUSES
        """
        uid = uid or generate_string()
        if order_states is None:
            order_states = KaspiConnector.DEFAULT_ORDER_STATES

        orders = []

        for order_state in order_states:
            state_orders = self.get_orders_by_state(order_state, order_statuses, start_date, finish_date, uid)
            orders.extend(state_orders)

        return orders

    def get_order_entries(self, order_id, uid=None):
        uid = uid or generate_string()
        # To log extra details
        extra_data = {
            'order_id': order_id,
            'merchant_name': self.merchant.name,
            'kaspi_shop_uid': self.merchant.kaspi_shop_uid,
            'merchant_pk': self.merchant.pk,
            'uid': uid
        }

        order_products = []
        try:
            order_products = self.client.get_order_entries(order_id=order_id,
                                                           merchant_name=self.merchant.name,
                                                           merchant_id=self.merchant.pk,
                                                           uid=uid)
        except BaseException as err:
            logger.error("#KaspiConnector.get_order_entries"
                         "request error: %s", err, extra=extra_data)

            for _ in range(3):
                try:
                    order_products = self.client.get_order_entries(order_id=order_id,
                                                                   merchant_id=self.merchant.name,
                                                                   merchant_name=self.merchant.pk,
                                                                   uid=uid)
                    if order_products:
                        break
                except BaseException as exc:
                    logger.error('#KaspiConnector.get_order_entries request retry error %s',
                                 exc, extra=extra_data)

        logger.info("#KaspiConnector.get_order_entries response successful. Total product count: %s.",
                    len(order_products), extra=extra_data)

        return order_products

    def get_order_entries_product(self, entry_id, uid=None):
        uid = uid or generate_string()
        # To log extra details
        extra_data = {
            'entry_id': entry_id,
            'merchant_name': self.merchant.name,
            'kaspi_shop_uid': self.merchant.kaspi_shop_uid,
            'merchant_pk': self.merchant.pk,
            'uid': uid
        }

        product = None

        try:
            product = self.client.get_order_entries_product(entry_id=entry_id,
                                                            merchant_name=self.merchant.name,
                                                            merchant_id=self.merchant.pk,
                                                            uid=uid)
        except BaseException as err:
            logger.error("#KaspiConnector.get_order_entries_product"
                         "request error: %s", err, extra=extra_data)

            for _ in range(3):
                try:
                    product = self.client.get_order_entries_product(entry_id, self.merchant.name,
                                                                    self.merchant.pk,
                                                                    uid=uid)
                    if product:
                        break
                except BaseException as exc:
                    logger.error('#KaspiConnector.get_order_entries_product request retry error %s',
                                 exc, extra=extra_data)

        if product:
            logger.info("#KaspiConnector.get_order_entries_product response successful. "
                        "Product: %s, master_code: %s", product.name, product.master_code, extra=extra_data)
        else:
            logger.error("#KaspiConnector.get_entries_product returned no product for entry_id: %s.",
                         entry_id, extra=extra_data)

        return product

    def get_order_by_code(self, order_code=None, uid=None):
        uid = uid or generate_string()
        # To log extra details
        extra_data = {
            'merchant_name': self.merchant.name,
            'kaspi_shop_uid': self.merchant.kaspi_shop_uid,
            'merchant_pk': self.merchant.pk,
            'uid': uid
        }

        order = None

        try:
            orders = self.client.get_orders(order_code=order_code,
                                            merchant_name=self.merchant.name,
                                            merchant_id=self.merchant.pk,
                                            uid=uid)
            order = orders.data[0]
        except BaseException as err:
            logger.error("#KaspiConnector.get_order_by_code request error: %s", err, extra=extra_data)
            for _ in range(3):
                try:
                    orders = self.client.get_orders(order_code=order_code,
                                                    merchant_name=self.merchant.name,
                                                    merchant_id=self.merchant.pk,
                                                    uid=uid)
                    if orders:
                        order = orders.data[0]
                        break
                except BaseException as exc:
                    logger.error("#KaspiConnector.get_order_by_code request retry error %s",
                                 exc, extra=extra_data)

        if order:
            logger.info("#KaspiConnector.get_order_by_code response successful. Order_code: %s, order_state: %s",
                        order.attributes.code, order.attributes.state, extra=extra_data)

        else:
            logger.error("#KaspiConnector.get_order_by_code returned no order by code: %s",
                         order_code, extra=extra_data)

        return order

    def confirm_new_order(self, order_id=None, order_code=None, uid=None):
        """
            Confirms a new order in the Kaspi system by updating its status
            from "APPROVED_BY_BANK" to "ACCEPTED_BY_MERCHANT".

            This method is primarily used when the merchant's auto_accept field is set to True.

        """
        uid = uid or generate_string()

        extra_data = {
            'merchant_name': self.merchant.name,
            'kaspi_shop_uid': self.merchant.kaspi_shop_uid,
            'merchant_pk': self.merchant.pk,
            'uid': uid
        }
        confirmation_new_order = None
        try:
            confirmation_new_order = self.client.confirm_new_order(order_id=order_id,
                                                                   order_code=order_code,
                                                                   merchant_name=self.merchant.name,
                                                                   merchant_id=self.merchant.pk,
                                                                   uid=uid)
            logger.info("#KaspiConnector.confirm_new_order response successful. Order_id: %s, order_code: %s, "
                        "merchant_name: %s, merchant_id: %s ", order_id, order_code, extra=extra_data)
        except BaseException as err:
            logger.error("#KaspiConnector.confirm_new_order request error: %s", err, extra=extra_data)

        return confirmation_new_order

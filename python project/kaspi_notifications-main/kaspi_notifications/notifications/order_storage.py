import datetime
from typing import Union

from . import constants
from .models import KaspiNewOrder


class Orders:
    # Method to select new kaspi orders to be auto accepted
    def select_new_orders_to_be_auto_accepted(self):
        one_hour_ago = datetime.datetime.now() - datetime.timedelta(hours=1)
        orders = KaspiNewOrder.objects.filter(merchant__auto_accepting=True, merchant__communication_type='WHATSAPP',
                                              merchant__enabled=True, client_answer__isnull=True,
                                              first_message_sending_time__lt=one_hour_ago,
                                              api_order_status='APPROVED_BY_BANK').all()

        return orders

    # Method to select new kaspi orders to ask for comment
    def select_new_orders_to_ask_for_comment(self):
        orders = KaspiNewOrder.objects.filter(notification_status='client_must_be_notified',
                                              merchant__enabled=True).all().exclude(
            first_message_delivery_status__in=[constants.ERROR_WHILE_DELIVERING_MESSAGE,
                                               constants.CLIENT_WITHOUT_WHATSAPP])

        return orders

    # Method for getting all orders needs second review message
    def select_new_orders_needs_client_answer_review_green_api(self):
        orders = KaspiNewOrder.objects.filter(notification_status='need_client_to_answer',
                                              merchant__enabled=True).all()
        return orders

    # Method for getting all orders needs resend second message
    def select_new_orders_for_resend_second(self):
        orders = KaspiNewOrder.objects.filter(notification_status='client_with_delay',
                                              merchant__enabled=True).all()
        return orders

    def get_all_status_messages_postamat(self, merchant_id):
        return KaspiNewOrder.objects.filter(merchant_id=merchant_id, is_delivery_to_postamat=True)

    # Method to сhange new order notification status
    def change_new_order_notification_status(self, status, order_id):
        return KaspiNewOrder.objects.filter(kaspi_order_id=order_id).update(notification_status=status)

    # Method to сhange new order status
    def change_new_order_status(self, status, order_id):
        return KaspiNewOrder.objects.filter(kaspi_order_id=order_id).update(order_status=status)

    # Method to save details of new order in db
    def save_new_order_details(self, order_code, order_id, creation_date, phone_number, status, full_name, merchant,
                               api_status, api_state, planned_delivery_date, is_first_message) -> KaspiNewOrder:

        if is_first_message:
            return KaspiNewOrder.objects.create(kaspi_order_id=order_id, kaspi_order_code=order_code,
                                                order_date=creation_date,
                                                phone_number=phone_number, notification_status=status,
                                                full_name=full_name,
                                                merchant=merchant, api_order_status=api_status,
                                                api_order_state=api_state,
                                                planned_delivery_date=planned_delivery_date)
        else:
            return KaspiNewOrder.objects.create(kaspi_order_id=order_id, kaspi_order_code=order_code,
                                                order_date=creation_date,
                                                phone_number=phone_number, notification_status=status,
                                                full_name=full_name,
                                                merchant=merchant, api_order_status=api_status,
                                                api_order_state=api_state,
                                                planned_delivery_date=planned_delivery_date,
                                                first_message_delivery_status='первое сообщение отключено',
                                                first_message_sending_time=datetime.datetime.now())

    # Method to save client answer about new order
    def save_new_order_client_answer(self, answer, order_id):
        return KaspiNewOrder.objects.filter(kaspi_order_id=order_id).update(client_answer=answer)

    # Method to retrieve new order by id
    def get_new_order_by_id(self, order_id) -> Union[KaspiNewOrder, None]:
        return KaspiNewOrder.objects.filter(kaspi_order_id=order_id).first()

    def change_order_review_delivery_status(self, status, order_id):
        return KaspiNewOrder.objects.filter(kaspi_order_id=order_id).update(second_message_delivery_status=status)

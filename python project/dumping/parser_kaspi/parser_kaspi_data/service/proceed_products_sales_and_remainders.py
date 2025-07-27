import datetime
import os
from time import sleep

import pytz
from django.db.models import Sum, Q
from django.utils import timezone

from parser_kaspi_data.models import KaspiProduct, KaspiOrder, KaspiOrderProduct, Merchant, UserNotification
from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.green_api import send_message_through_green_api
from parser_kaspi_data.service.kaspi.kaspi_api import get_orders_with_products, get_kaspi_order
from parser_kaspi_data.service.kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods
from parser_kaspi_data.service.project_constants import INCORRECT_LOGIN
from parser_kaspi_data.service.project_exceptions import IncorrectLoginException
from parser_kaspi_data.service.proxy_manager import get_proxy_provider
from parser_kaspi_data.service.utils import convert_datetime_to_milliseconds
from asgiref.sync import sync_to_async


logger = project_logger.get_logger(__name__)

ORDERS_TYPES = ['DELIVERY', 'NEW', 'KASPI_DELIVERY', 'PICKUP']


def sync_kaspi_orders(date_start, date_end, order_type, order_status):
    """ Method to get synchronize kaspi orders and products data in db """
    start_date = convert_datetime_to_milliseconds(date_start)
    end_date = convert_datetime_to_milliseconds(date_end)
    merchants = Merchant.objects.all()
    for merchant in merchants:
        try:
            logger.info(f'Retrieving orders info with order_type = {order_type} and order_status = {order_status}')
            orders = get_orders_with_products(page_size=10, order_state=order_type, date_start=start_date,
                                              date_finish=end_date, order_status=order_status, kaspi_token=merchant.kaspi_token)

            logger.info('Synchronization of kaspi orders and product data has started')

            products_dict = {}

            for order in orders:
                kaspi_order = KaspiOrder.objects.filter(order_id=order['order_id']).first()
                if kaspi_order:
                    if kaspi_order.order_status == order['status']:
                        continue
                    else:
                        kaspi_order.order_status = order['status']
                        kaspi_order.save()

                else:
                    kaspi_order = KaspiOrder.objects.create(order_id=order['order_id'], order_status=order['status'],
                                                            order_type=order['type'], order_date=order['date'])
                    for order_entry in order['items']:
                        if order_entry["product_code"] not in products_dict:
                            products_dict[order_entry["product_code"]] = KaspiProduct.objects.filter(master_sku=order_entry["product_code"]).first()

                        KaspiOrderProduct.objects.create(order=kaspi_order, product=products_dict[order_entry["product_code"]],
                                                         quantity=order_entry['quantity'])
        except Exception as e:
            logger.error(
                f'Some general merchant {merchant} failure while synchronising kaspi orders to process remainders')
            logger.error(project_logger.format_exception(e))

    logger.info(f'Synchronization of kaspi orders and product data with order_type = {order_type} and order_status = {order_status} has ended')


async def recheck_products_statuses():
    proxy_provider = await get_proxy_provider()
    """ Method to get products to be marked as unavailable in kaspi because its remainders are null """
    timezone.now()
    today = datetime.datetime.utcnow().date()
    date_start = datetime.datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=pytz.UTC)
    date_finish = datetime.datetime(today.year, today.month, today.day, 23, 59, 59, tzinfo=pytz.UTC)

    sync_kaspi_orders(date_start, date_finish, 'ARCHIVE', 'COMPLETED')

    sync_accepted_kaspi_orders()

    for order_type in ORDERS_TYPES:
        sync_kaspi_orders(date_start, date_finish, order_type, 'ACCEPTED_BY_MERCHANT')

    merchants = Merchant.objects.filter(enabled=True).all()
    for merchant in merchants:
        try:
            if merchant.allowed_number_of_products_with_remainders is not None:
                products = merchant.kaspi_products.filter(remainders__isnull=False).exclude(remainders=0).all()[:merchant.allowed_number_of_products_with_remainders]
            else:
                products = merchant.kaspi_products.filter(remainders__isnull=False).exclude(remainders=0).all()
            logger.info(f'Amount of products with remainders = {len(products)}')
            merchant = await sync_to_async(Merchant.objects.select_related('user').get)(id=merchant.id)
            merchant_user = merchant.user
            try:
                kaspi_merchant_cabinet_methods = KaspiMerchantCabinetMethods(login=merchant.login,
                                                                             password=merchant.password)
                merchant_user.informed_about_login_problems = False
                await sync_to_async(merchant_user.save)()
            except IncorrectLoginException:
                logger.info(f'Login or password of kaspi cabinet for merchant {merchant} seems to be incorrect, '
                            f'impossible to parse data to recheck products statuses')
                user_notification = await sync_to_async(UserNotification.objects.filter(user=merchant_user, message_type=INCORRECT_LOGIN).first)()
                if not user_notification:
                    await sync_to_async(UserNotification.objects.create)(user=merchant_user, message_type='incorrect login',
                                                    message_level='Warning',
                                                    message_text=f'Уважаемый пользователь!\nВозможно, что у вас изменились '
                                                                 f'логин или пароль от каспи кабинета.\nДемпинг невозможен, '
                                                                 f'необходимо немедленно связаться с менеджером по телефону '
                                                                 f'https://wa.me/{os.getenv("MANAGER_PHONE")} для выяснения деталей.')
                await sync_to_async(send_message_through_green_api)(merchant)
                return

            for product in products:
                if product.remainders is None:
                    continue
                sold_quantity = product.order_products.filter(Q(order__order_status='COMPLETED') &
                                                              Q(order__order_date__gte=product.remainders_date)).aggregate(Sum('quantity'))
                reserved_quantity = product.order_products.filter(Q(order__order_status='ACCEPTED_BY_MERCHANT') &
                                                                  Q(order__order_date__gte=product.remainders_date)).aggregate(Sum('quantity'))
                product.reserved_remainders = reserved_quantity['quantity__sum'] if reserved_quantity['quantity__sum'] else 0
                product.sold_remainders = sold_quantity['quantity__sum'] if sold_quantity['quantity__sum'] else 0
                product.save()
                product.calculated_remainders = product.remainders - (product.sold_remainders + product.reserved_remainders)
                product.save()

                if product.calculated_remainders <= 0:
                    if product.available is False:
                        logger.info(f'product {product.code} has remainders {product.calculated_remainders}, '
                                    f'but it is already unavailable, nothing was made')
                        continue
                    logger.info(f'making product {product.code} unavailable')
                    # mark as unavailable
                    await kaspi_merchant_cabinet_methods.make_product_unavailable(merchant.merchant_id, product.master_sku,
                                                                            product.title, proxy_provider)
                    sleep(1)
                    product.available = False
                    product.save()
                else:
                    if product.available is True:
                        logger.info(f'product {product.code} has remainders {product.calculated_remainders}, '
                                    f'but it is already available, nothing was made')
                        continue
                    logger.info(f'making product {product.code} available')
                    # mark as available
                    await kaspi_merchant_cabinet_methods.make_product_available(merchant.merchant_id, product.master_sku,
                                                                          product.title, product.price, proxy_provider)
                    sleep(1)
                    product.available = True
                    product.save()
        except Exception as e:
            logger.error(f'Some general merchant {merchant} failure while rechecking products statuses to process remainders')
            logger.error(project_logger.format_exception(e))


def sync_accepted_kaspi_orders():
    kaspi_orders_accepted = KaspiOrder.objects.filter(order_status='ACCEPTED_BY_MERCHANT').all()
    for kaspi_order in kaspi_orders_accepted:
        try:
            order = get_kaspi_order(kaspi_order.order_id, kaspi_order.merchant.kaspi_token)
            if kaspi_order.order_status == order['status'] and kaspi_order.order_type == order['type']:
                logger.info(f'Order {kaspi_order.order_id}"s status has not changed, skipping it')
                continue
            else:
                kaspi_order.order_status = order['status']
                kaspi_order.order_type = order['type']
                kaspi_order.save()
        except Exception as e:
            logger.error(f'Some failure while rechecking order {kaspi_order} status to proceed product remainders')
            logger.error(project_logger.format_exception(e))

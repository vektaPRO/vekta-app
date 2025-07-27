import os
import logging
import datetime
import asyncio
from django.core.cache import cache
from typing import List
from celery import shared_task
from django.conf import settings
from pktools.helpers import time_it_and_log
from parser_kaspi_data.models import Merchant, KaspiProduct, ProductPrice
from parser_kaspi_data.service import green_api
from parser_kaspi_data.service.kaspi_connector import KaspiConnector
from parser_kaspi_data.service.analytics_connector import AnalyticsConnector
from parser_kaspi_data.service.read_emails_service import check_email_and_try_to_read_its_content
from .celery import app


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


@shared_task
def send_message_green_api(merchant_id):
    merchant = Merchant.objects.get(pk=merchant_id)
    green_api.send_message_through_green_api(merchant)

    green_api.send_message_through_green_api(merchant)


@app.task
def get_password_from_email(kaspi_merchant_id) -> None:

    def get_current_timestamp() -> int:
        return int(datetime.datetime.now().timestamp())

    started_at = get_current_timestamp()
    logger.info(f'Task get_password_from_email for merchant {kaspi_merchant_id} has started :: {started_at}')
    check_email_and_try_to_read_its_content(kaspi_merchant_id)
    duration = get_current_timestamp() - started_at
    logger.info(f'Task get_password_from_email for merchant {kaspi_merchant_id} completed in {duration} seconds')


@shared_task
@time_it_and_log
def process_products(product_ids: List[int], uid: str) -> None:
    """
    fetch actual, get competitors data and change price
    product_ids.__len__ = 50
    """

    def _get_place_data(offers_info, merchant_name: str) -> tuple:
        current_place = 4
        first_place_price = 0
        second_place_price = 0
        third_place_price = 0

        # Inara's algorithm
        if offers_info.total >= 1:
            first_place_price = offers_info.offers[0].price
            if offers_info.offers[0].merchant_name == merchant_name:
                current_place = 1

        if offers_info.total >= 2:
            second_place_price = offers_info.offers[1].price
            if offers_info.offers[1].merchant_name == merchant_name:
                current_place = 2

        if offers_info.total >= 3:
            third_place_price = offers_info.offers[2].price
            if offers_info.offers[2].merchant_name == merchant_name:
                current_place = 3

        return current_place, {
            1: first_place_price,
            2: second_place_price,
            3: third_place_price,
        }

    # limit used for SQL query optimize
    kps = KaspiProduct.objects.filter(id__in=product_ids).select_related('merchant')[:50]
    product_prices = list()

    for kp in kps:
        try:
            logger.info('#parser_kaspi.tasks.process_products started',
                        extra={
                            'kaspi_product_code': kp.code,
                            'kaspi_product_id': kp.id,
                            'merchant': '%s, %s' % (kp.merchant_name, kp.merchant_id),
                            'price_difference': kp.price_difference,
                            'current_price': kp.price,
                            'min_price': kp.min_price,
                            'max_price': kp.max_price,
                            'uid': uid
                        })
            kp.price_difference = kp.price_difference or 1
            target_price = kp.price
            target_place = kp.target_price_place
            # кейде юзер target_price_place жазбайды, ондайды жалпы магазиннің немесе 1 позияға ұмтыламыз
            if target_place is None:
                target_place = 1 if kp.merchant.price_place is None else kp.merchant.price_place

            target_place = int(target_place)

            kaspi = KaspiConnector(merchant=kp.merchant)
            product = kaspi.get_product_detail(kp, uid)

            # TODO need to be eligible city id
            city = product.cityInfo[0]
            # city.price - actual price
            # city.id - available city id

            offers_data = kaspi.get_product_competitors(
                city_id=city.id,
                code=kp.code,
                uid=uid
            )

            curr_place, card_prices = _get_place_data(offers_data, kp.merchant.name)

            # егер біздің товар біз қалаған n орында тұрса, онда бағаны n-1 бағасына жақын қылу керек
            if curr_place == target_place:
                closest_place_price = card_prices.get(curr_place + 1, 0)
                target_price = closest_place_price - kp.price_difference if closest_place_price else kp.price
            else:
                kp.price_difference = 1 if kp.price_difference is None else kp.price_difference
                target_price = card_prices[target_place] - kp.price_difference if kp.price_difference else kp.price

            if kp.min_price:
                target_price = max(target_price, kp.min_price)

            if kp.max_price:
                target_price = min(target_price, kp.max_price)

            extra_data = {
                'kaspi_product_id': kp.id,
                'kaspi_product_code': kp.code,
                'merchant': '%s, %s' % (kp.merchant_name, kp.merchant_id),
                'price_difference': kp.price_difference,
                'current_price': kp.price,
                'target_price': target_price,
                'target_place': target_place,
                'current_place': curr_place,
                'min_price': kp.min_price,
                'max_price': kp.max_price,
                'places': card_prices,
                'uid': uid
            }

            if target_price <= 0:
                logger.info(
                    '#parser_kaspi.tasks.process_products failed, target price is 0',
                    extra=extra_data
                )
                continue

            if kp.price == target_price:
                logger.info(
                    '#parser_kaspi.tasks.process_products failed, target price is product price',
                    extra=extra_data
                )
                continue

            logger.info(
                '#parser_kaspi.tasks.process_products success',
                extra=extra_data
            )

            pp = kaspi.update_product_and_mark(
                city_ids=[city.id],
                price=target_price,
                kaspi_product=kp,
                uid=uid,
            )

            if pp is None:
                logger.error('#parser_kaspi.tasks.process_products update_product failed'
                             'uid %s', uid, extra=extra_data)
                continue

            kp.price = target_price
            kp.product_price = 'Hot'
            kp.save()
            product_prices.append(pp)
            cache.set(kp.id, pp.date_of_changing, timeout=10 * 60)
        except BaseException as exc:
            logger.info('#parser_kaspi.tasks.process_products product failed %s', exc,
                        extra={
                            'kaspi_product_code': kp.code,
                            'kaspi_product_id': kp.id,
                            'merchant': '%s, %s' % (kp.merchant_name, kp.merchant_id),
                            'price_difference': kp.price_difference,
                            'current_price': kp.price,
                            'min_price': kp.min_price,
                            'max_price': kp.max_price,
                            'uid': uid
                        }
                        )

    pps = ProductPrice.objects.bulk_create(product_prices)
    logger.info(
        '#parser_kaspi.tasks.process_products inserted successfully product prices',
        extra={
            'changes_count': pps.__len__(),
            'kaspi_product_ids': [pp.id for pp in pps],
        }
    )


@shared_task
@time_it_and_log
def notify_user_registration_telegram_channel(data: dict):
    from parser_kaspi_data.service.tg_bot_functions import send_kaspi_client_data_to_tg

    date_time = data.get("date_time")
    full_name = data.get("full_name")
    email = data.get("email")
    phone_number = data.get("phone_number")

    message = f'Сегодня в {date_time} обратился следующий клиент для подключения к Демпингу:\n' \
              f'ФИО: {full_name}\n' \
              f'Email: {email}\n' \
              f'Телефон: {phone_number}\n'

    asyncio.run(send_kaspi_client_data_to_tg(message=message, chat_id=os.getenv("CHAT_ID")))

    logger.info('parser_kaspi.tasks.notify_user_registration_telegram_channel success')


@shared_task
@time_it_and_log
def healthcheck_other_services(token: str, phone_number: str):
    '''
    Healthcheck request from core service to others, that say 'Hey There are new user with key and phone_number'
    '''
    analytics = AnalyticsConnector()
    analytics.register_user_based_on_token(token=token)
    logger.info('parser_kaspi.tasks.healthcheck_other_services success', extra=dict(phone_number=phone_number))

import asyncio
import datetime
import logging
from django.conf import settings
from django.utils import timezone

from pktools.helpers import lock_and_log, time_it_and_log, chunked_data
from pktools.string import generate_string
from parser_kaspi_data.models import Merchant, KaspiProduct
from parser_kaspi_data.service import project_logger, proxy_manager, xml_service, functions_for_celery_tasks
from parser_kaspi_data.service.proceed_products_sales_and_remainders import recheck_products_statuses
from parser_kaspi_data.service.tg_bot_functions import send_notification_about_asocks_balance
from parser_kaspi.tasks import process_products

from .celery import app


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


def get_current_timestamp() -> int:
    return int(datetime.datetime.now().timestamp())


@app.task
@lock_and_log
def sync_products_by_card_info():
    """
    Get competitors data and stores in DB
    """
    pass


@app.task
@lock_and_log
def prepare_and_distribute_products_process():
    uuid = generate_string()
    uid_list = list()
    actual_merchant_ids = list(Merchant.objects.filter(
        enable_parsing=True,
        enabled=True,
        execution_type=Merchant.EXECUTION_TYPE_B
    ).values_list('id', flat=True))

    product_ids = list(
        KaspiProduct.objects.filter(
            merchant_id__in=actual_merchant_ids,
            recently_parsed=True,
            price_auto_change=True
        ).values_list('id', flat=True)
    )

    for chunk in chunked_data(product_ids, 50):
        uid = generate_string()
        process_products.delay(chunk, uid)
        logger.info('#parser_kaspi.periodic.prepare_products_and_start: thread started',
                    extra={
                        'uid': uid,
                        'product_ids': chunk
                    })
        uid_list.append(uid)

    logger.info('#parser_kaspi.periodic.prepare_products_and_start: started uid %s',
                uuid,
                extra={
                    'uids': uid_list,
                    'merchant_ids': actual_merchant_ids
                }
    )


@app.task
@lock_and_log
def sync_products_with_cabinet():

    @time_it_and_log
    def process_merchant_cabinet(merchant_id, uid=None):
        uid = uid or generate_string()
        merchant = Merchant.objects.get(pk=merchant_id)

        # getting products from Cabinet
        proxy_provider = asyncio.run(proxy_manager.get_proxy_provider())
        sku_list = asyncio.run(xml_service.generate_sku(merchant, proxy_provider, uid))

        logger.info('#process_merchant_cabinet merchant id %s, count sku %s, uid %s',
                    merchant_id, len(sku_list),  uid)

        # checked products from cabinet
        master_skus = list(map(lambda x: x['sku_merch'], sku_list))

        # checked products from DB
        local_products_sku = KaspiProduct.objects.filter(
            merchant_id=merchant_id, recently_parsed=True
        ).values_list('master_sku', flat=True)

        # analyzing products in DB
        uncheck_products_sku = list(set(local_products_sku) - set(master_skus))
        create_or_check_products_sku = list(set(master_skus) - set(local_products_sku))

        # unchecking products
        KaspiProduct.objects.filter(
            master_sku__in=uncheck_products_sku, merchant_id=merchant_id
        ).update(recently_parsed=False)

        # check products
        KaspiProduct.objects.filter(
            master_sku__in=create_or_check_products_sku, merchant_id=merchant_id
        ).update(recently_parsed=True)

        # creating products
        checked_products_sku = list(KaspiProduct.objects.filter(
            master_sku__in=create_or_check_products_sku, merchant_id=merchant_id
        ).values_list('master_sku', flat=True))
        create_products_sku = list(set(create_or_check_products_sku) - set(checked_products_sku))
        create_products = list(filter(lambda x: x['sku_merch'] in create_products_sku, sku_list))

        products = [
            KaspiProduct(
                title=kp['title'],
                price=kp['min_price'],
                code=kp['sku'],
                master_sku=kp['sku_merch'],
                available=kp['available'],
                merchant_id=kp['merchant'].pk,
                product_card_link=kp['product_card_link'],
                product_image_link=kp['product_image_link'],
                availabilities=kp['availabilities']
            ) for kp in create_products
        ]

        KaspiProduct.objects.bulk_create(products)

    actual_merchants = list(Merchant.objects.filter(
        enable_parsing=True,
        enabled=True,
        execution_type=Merchant.EXECUTION_TYPE_B
    ).values_list('id', 'name'))

    logger.info(
        '#parser_kaspi.periodic.sync_products_with_cabinet started with merchants',
        extra={
            'merchants': list(map(lambda x: x[1], actual_merchants)),
            'merchant_ids': list(map(lambda x: x[0], actual_merchants)),
        }
    )

    for m in actual_merchants:
        try:
            process_merchant_cabinet(m[0])
            logger.info('#parser_kaspi.periodic.sync_products_with_cabinet merchant success %s', m[1])
        except BaseException as err:
            logger.error(
                '#parser_kaspi.periodic.sync_products_with_cabinet merchant %s %s raised error %s',
                m[0], m[1], err
            )


@app.task
@lock_and_log
def check_left_day():
    logger.info(f'Task check_left_day has started')
    merchants = Merchant.objects.filter(
        subscription_date_end__lte=timezone.now(),
        enabled=True
    )
    for merchant in merchants:
        try:
            merchant.enabled = False
            merchant.save()
            logger.info(f'Skipping merchant - {merchant.name} has no left day')

        except BaseException as e:
            logger.exception(f'Exception raised while processing merchant {merchant.name}, error = {e}')
            continue

    logger.info(f'Task check_left_day has ended')


@app.task
@lock_and_log
def check_proxies_balance():
    loop = asyncio.get_event_loop()
    loop.run_until_complete(send_notification_about_asocks_balance())

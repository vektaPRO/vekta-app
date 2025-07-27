import os
import timeit
import logging
import asyncio
from typing import List, Any, Generator, Union

from asgiref.sync import sync_to_async
from django.conf import settings
from pktools.stash import cached
from parser_kaspi.tasks import send_message_green_api
from parser_kaspi_data.models import Merchant, KaspiProduct, UserNotification
from parser_kaspi_data.products_storage import Product
from parser_kaspi_data.project_additional_models.data_models import SkuDict, PriceModel
from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods
from parser_kaspi_data.service.parser import Parser
from parser_kaspi_data.service.project_constants import INCORRECT_LOGIN
from parser_kaspi_data.service.project_exceptions import IncorrectLoginException
from parser_kaspi_data.service.proxy_manager import ProxyProvider

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)

filename = 'output.xml'


def get_filename():
    return filename


@cached.func(timeout=1 * 60 * 60, exclude_kwarg_keys=['proxy_provider', 'uid'])
async def generate_sku(merchant: Merchant, proxy_provider, uid: str) -> Union[List[SkuDict], None]:
    merchant = await sync_to_async(Merchant.objects.select_related('user').get)(id=merchant.id)
    merchant_user = merchant.user
    try:
        kaspi_merchant_cabinet_methods = KaspiMerchantCabinetMethods(login=merchant.login,
                                                                     password=merchant.password)
        merchant_user.informed_about_login_problems = False
        await sync_to_async(merchant_user.save)()
    except IncorrectLoginException:
        logger.info(f'Login or password of kaspi cabinet for merchant {merchant} seems to be incorrect, '
                    f'impossible to parse data to generate sku, uid %s', uid)
        user_notification = await sync_to_async(UserNotification.objects.filter(user=merchant_user, message_type=INCORRECT_LOGIN).first)()
        if not user_notification:
            await sync_to_async(UserNotification.objects.create)(user=merchant_user, message_type='incorrect login',
                                            message_level='Warning',
                                            message_text=f'Уважаемый пользователь!\nВозможно, что у вас изменились '
                                                         f'логин или пароль от каспи кабинета.\nДемпинг невозможен, '
                                                         f'необходимо немедленно связаться с менеджером по телефону '
                                                         f'https://wa.me/{os.getenv("MANAGER_PHONE")} для выяснения деталей.')
        await send_message_green_api.delay(merchant)
        return
    sku_dict_list = []
    try:
        products_data_available = await kaspi_merchant_cabinet_methods.get_merchant_products(
            merchant.merchant_id,
            proxy_provider,
            'true',
            uid
        )
        # products_data_archived = await kaspi_merchant_cabinet_methods.get_merchant_products_info(merchant.merchant_id, 'false',  proxy_provider)
        # products_data_total = products_data_available + products_data_archived

        for product in products_data_available:
            min_price = product['minPrice']
            sku_merch = product['sku']
            sku = product['masterSku']
            title = product['masterTitle']
            available = product['available']
            product_card_link = 'https://kaspi.kz/shop' + product['shopLink']
            product_image_link = 'https://resources.cdn-kaspi.kz/img/m/p/' + product['images'][0] + '?format=gallery-small'
            availabilities = []
            for availability in product['availabilities']:
                del availability['stockCount']
                del availability['preOrder']
                availabilities.append(availability)

            sku_dict_list.append(SkuDict(sku_merch=sku_merch, sku=sku,
                                         title=title, min_price=min_price,
                                         available=available, merchant=merchant,
                                         product_card_link=product_card_link, product_image_link=product_image_link,
                                         availabilities=availabilities))

    except Exception as e:
        logger.error(f'Error while generating products sku', extra={'uid': uid})
        logger.error(project_logger.format_exception(e))

    return sku_dict_list


async def parse_and_save_data_and_create_xml_file(proxy_provider: ProxyProvider, merchant: Merchant, uid: str):
    start = timeit.default_timer()
    sku_list = await generate_sku(merchant, proxy_provider, uid)

    result = []
    count_responses = 0

    for sku_chunk in _chunked_data(sku_list):
        city_sku_list = PriceModel(city=750000000, sku_list=sku_chunk)
        response = await Parser().process_list(city_sku_list, proxy_provider, uid)
        count_responses += len(response)
        logger.info(
            'Number of record Merchant %s, response count overall %s, current %s',
            merchant.name, count_responses, len(response), extra={'uid': uid}
        )
        result.extend(response)
        if count_responses % 1000 == 0:
            await asyncio.sleep(10)

    logger.info(
        'Number parsed records for Merchant %s, id %s is %s',
        merchant.name, merchant.id, count_responses, extra={'uid': uid})

    products_ids = []
    for item in result:
        logger.info(f'Item = {item}')

        if not isinstance(item, dict):
            logger.warning(f'Item {item} is not dict, impossible to process this product while parsing', extra={'uid': uid})
            continue

        products_ids.append(item['sku'])

        if item is not None:
            current_price_place = 4
            first_place_price = 0
            second_place_price = 0
            third_place_price = 0
            if merchant.competitors_to_exclude is not None:
                logger.info(merchant.competitors_to_exclude, extra={'uid': uid})
                for competitor in item['merchants']:
                    if competitor['merchantName'] in merchant.competitors_to_exclude:
                        item['merchants'].remove(competitor)
            if len(item['merchants']) >= 1:
                first_place_price = int(item['merchants'][0]['price'])
                if item['merchants'][0]['merchantName'] == merchant.name:
                    current_price_place = 1
            if len(item['merchants']) >= 2:
                second_place_price = int(item['merchants'][1]['price'])
                if item['merchants'][1]['merchantName'] == merchant.name:
                    current_price_place = 2
            if len(item['merchants']) >= 3:
                third_place_price = int(item['merchants'][2]['price'])
                if item['merchants'][2]['merchantName'] == merchant.name:
                    current_price_place = 3


            # save parsed product to db
            if await sync_to_async(Product.check_if_product_exists)(item['skuMerch'], item['merchant']):
                await sync_to_async(Product.update_product_info)(item['title'], item['minPrice'], first_place_price,
                                                                 second_place_price, third_place_price, item['sku'],
                                                                 item['skuMerch'], item['available'], item['merchant'],
                                                                 current_price_place, item['product_card_link'],
                                                                 item['product_image_link'], item['availabilities'])
            else:
                await sync_to_async(Product.create_new_product)(item['title'], item['minPrice'], first_place_price,
                                                                second_place_price, third_place_price, item['sku'],
                                                                item['skuMerch'], item['available'], item['merchant'],
                                                                current_price_place, item['product_card_link'],
                                                                 item['product_image_link'], item['availabilities'])

    products_to_be_marked_as_not_recently_parsed = await sync_to_async(list)(
        KaspiProduct.objects.filter(merchant=merchant).exclude(code__in=products_ids).update(recently_parsed=False)
    )
    logger.info(f'Products that are not actual = {products_to_be_marked_as_not_recently_parsed}', extra={'uid': uid})


def _chunked_data(data: List[Any],
                  chunk_size: int = 200
                  ) -> Generator[List[Any], None, None]:
    for i in range(0, len(data), chunk_size):
        yield data[i:i + chunk_size]

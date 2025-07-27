import asyncio
import datetime
import os
import logging
from time import sleep
from typing import List

from asgiref.sync import sync_to_async

from django.conf import settings
from . import project_logger
from .green_api import send_message_through_green_api
from .kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods
from .project_exceptions import IncorrectLoginException
from .project_constants import HOT_CATEGORY, NUM_CHECKS_TO_SKIP_FOR_WARM_PRODUCT, WARM_CATEGORY, COLD_CATEGORY, \
    NUM_CHECKS_TO_SKIP_FOR_COLD_PRODUCT, INCORRECT_LOGIN
from .proxy_manager import get_proxy_provider, ProxyProvider
from .xml_file_to_change_prices import create_xml
from .xml_service import parse_and_save_data_and_create_xml_file
from ..models import ProductPrice, Merchant, KaspiProduct, UserNotification
from ..products_storage import Product

REQUESTS_COOLDOWN_SECONDS = 0.5

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


async def xml_file_generation(products: List, merchant: Merchant) -> None:
    try:
        logger.info(
            f'Xml-file creation to change prices for merchant {merchant.name} started :: {datetime.datetime.now()}')
        await create_xml(products, merchant)
        logger.info(
            f'Xml-file creation to change prices merchant {merchant.name} ended :: {datetime.datetime.now()}')
    except Exception as e:
        logger.error(f'Some error occurred while xml-file creation to change prices for merchant {merchant.name}')
        logger.error(project_logger.format_exception(e))


async def change_product_price(kaspi_merchant_cabinet_methods, merchant, new_price, product, product_details,
                               proxy_provider) -> bool:
    logger.info(
        f'Changing price of {product.master_sku} from {product.price} to {new_price} because current price place '
        f'is {product.current_price_place} and target price place is {product.target_price_place}'
    )
    try:
        change_price_successful = await kaspi_merchant_cabinet_methods.change_price(merchant.merchant_id,
                                                                                    product.master_sku,
                                                                                    product.title,
                                                                                    product_details['availabilities'],
                                                                                    product_details['city_prices'],
                                                                                    new_price, proxy_provider
                                                                                    )
        if change_price_successful:
            product.price = new_price
            await sync_to_async(product.save)()
            await sync_to_async(ProductPrice.objects.create)(product=product, changed_price=new_price)

        return change_price_successful

    except Exception as e:
        logger.error(f'Error while changing price for product {product.master_sku}')
        logger.error(project_logger.format_exception(e))


async def change_prices_by_merchant_if_needed(proxy_provider: ProxyProvider, merchant: Merchant):
    try:
        started_at = datetime.datetime.now().timestamp()
        logger.info(f'change_price_for_products for merchant {merchant.merchant_id} started at {started_at}')
        products_to_be_checked = await sync_to_async(list)(Product.get_products_with_auto_price_change(merchant))
        products_not_to_be_checked = await sync_to_async(list)(Product.get_products_without_auto_price_change(merchant, products_to_be_checked))

        num_successfully_changed_prices = 0
        num_unsuccessfully_changed_prices = 0
        num_unchanged_prices = 0
        logger.info(f'Number of products with prices to be checked for merchant {merchant.name} = {len(products_to_be_checked)}')
        logger.info(
            f'Number of products with prices not to be checked for merchant {merchant.name} = {len(products_not_to_be_checked)}')
        if len(products_to_be_checked) == 0:
            logger.info(f'No products with prices to be checked for merchant {merchant.name}')
            return
        merchant = await sync_to_async(Merchant.objects.select_related('user').get)(id=merchant.id)
        merchant_user = merchant.user
        try:
            kaspi_merchant_cabinet_methods = KaspiMerchantCabinetMethods(login=merchant.login, password=merchant.password)

            merchant_user.informed_about_login_problems = False
            await sync_to_async(merchant_user.save)()
        except IncorrectLoginException:
            logger.info(f'Login or password of kaspi cabinet for merchant {merchant} seems to be incorrect, '
                        f'impossible to parse data to change prices')
            user_notification = await sync_to_async(UserNotification.objects.filter(user=merchant_user, message_type=INCORRECT_LOGIN).first)()
            if not user_notification:
                await sync_to_async(UserNotification.objects.create)(user=merchant_user, message_type='incorrect login', message_level='Warning',
                                                message_text=f'Уважаемый пользователь!\nВозможно, что у вас изменились '
                                                             f'логин или пароль от каспи кабинета.\nДемпинг невозможен, '
                                                             f'необходимо немедленно связаться с менеджером по телефону '
                                                             f'https://wa.me/{os.getenv("MANAGER_PHONE")} для выяснения деталей.')
            await sync_to_async(send_message_through_green_api)(merchant)
            return
        tasks_chunk = []
        products_to_change_price = []
        products_not_to_change_price = []
        for product in products_not_to_be_checked:
            product_price_data = {'product': product, 'price': product.price,
                                  'product_details': {'availabilities': product.availabilities}}
            products_not_to_change_price.append(product_price_data)

        for product in products_to_be_checked:
            try:
                is_price_within_boundaries = (
                        (not product.min_price or product.price >= product.min_price) and
                        (not product.max_price or product.price <= product.max_price)
                )

                sku_log_details = f'Merchant {merchant.merchant_id}, sku {product.master_sku}, code {product.code}'
                verbose_price_explanation_log = (
                    f'{sku_log_details}, price = {product.price}, '
                    f'competitor prices = [{product.first_place_price}, {product.second_place_price}, {product.third_place_price}], '
                    f'product target place = {product.target_price_place}, product price diff {product.price_difference} '
                    f'merchant target place = {merchant.price_place}, merchant price diff {merchant.price_difference} '
                    f'min price = {product.min_price}, max price = {product.max_price}, price in boundaries: {"yes" if is_price_within_boundaries else "no"}'
                )
                product_competitors_prices = {
                    1: product.first_place_price if product.first_place_price is not None else 0,
                    2: product.second_place_price if product.first_place_price is not None else 0,
                    3: product.third_place_price if product.first_place_price is not None else 0
                }

                product_details = await kaspi_merchant_cabinet_methods.get_product_details(merchant.merchant_id,
                                                                                           product.master_sku,
                                                                                           proxy_provider)

                if product.num_checks_to_skip > 0 and is_price_within_boundaries:
                    logger.info(
                        f'num_checks_to_skip for product {product.code} is {product.num_checks_to_skip} '
                        f'so skipping this product')
                    product.num_checks_to_skip -= 1
                    await sync_to_async(product.save)()
                    num_unchanged_prices += 1
                    product = {'product': product, 'price': product.price, 'product_details': product_details}
                    products_not_to_change_price.append(product)
                    continue

                price_difference = product.price_difference if product.price_difference is not None else (
                    merchant.price_difference if merchant.price_difference is not None else 1)
                target_price_place = int(product.target_price_place if product.target_price_place is not None else (
                    merchant.price_place if merchant.price_place is not None else 1))

                if target_price_place not in product_competitors_prices and is_price_within_boundaries:
                    logger.info(
                        f'Product target price place  for product {product.code} not in [1, 2, 3] :: {target_price_place}'
                        f'so skipping this product')
                    num_unchanged_prices += 1
                    await register_product_price_change_skip(product)
                    product_price_data = {'product': product, 'price': product.price,
                                          'product_details': product_details}
                    products_not_to_change_price.append(product_price_data)
                    continue

                if target_price_place == 0 and is_price_within_boundaries:
                    logger.info(f'{verbose_price_explanation_log}. Skipping as target price place is equal to 0.')
                    num_unchanged_prices += 1
                    await register_product_price_change_skip(product)
                    product_price_data = {'product': product, 'price': product.price,
                                          'product_details': product_details}
                    products_not_to_change_price.append(product_price_data)
                    continue

                if product.current_price_place == target_price_place:
                    closest_competitor_price = product_competitors_prices[product.current_price_place + 1]
                    if closest_competitor_price == 0 and is_price_within_boundaries:
                        logger.info(f'{verbose_price_explanation_log}. Skipping as closest_competitor_price is 0')
                        num_unchanged_prices += 1
                        await register_product_price_change_skip(product)
                        product_price_data = {'product': product, 'price': product.price,
                                              'product_details': product_details}
                        products_not_to_change_price.append(product_price_data)
                        continue
                    if closest_competitor_price - product.price == price_difference and is_price_within_boundaries:
                        logger.info(
                            f'{verbose_price_explanation_log}. Skipping as product is on desired {product.current_price_place} place')
                        num_unchanged_prices += 1
                        await register_product_price_change_skip(product)
                        product_price_data = {'product': product, 'price': product.price,
                                              'product_details': product_details}
                        products_not_to_change_price.append(product_price_data)
                        continue

                    target_price = closest_competitor_price - price_difference if closest_competitor_price else product.price
                else:
                    if product_competitors_prices[target_price_place] == 0 and is_price_within_boundaries:
                        logger.info(f'{verbose_price_explanation_log}. Skipping as target competitor price is empty')
                        num_unchanged_prices += 1
                        await register_product_price_change_skip(product)
                        product_price_data = {'product': product, 'price': product.price,
                                              'product_details': product_details}
                        products_not_to_change_price.append(product_price_data)
                        continue

                    target_price = (
                        product_competitors_prices[target_price_place] - price_difference
                        if product_competitors_prices[target_price_place]
                        else product.price
                    )

                if product.min_price:
                    target_price = max(target_price, product.min_price)

                if product.max_price:
                    target_price = min(target_price, product.max_price)

                if target_price <= 0:
                    logger.info(f'{verbose_price_explanation_log}. Skipping as unable to calculate target price')
                    num_unchanged_prices += 1
                    await register_product_price_change_skip(product)
                    product_price_data = {'product': product, 'price': product.price,
                                          'product_details': product_details}
                    products_not_to_change_price.append(product_price_data)
                    continue

                if product.price == target_price:
                    logger.warning(
                        f'{verbose_price_explanation_log}. Skipping as {product.price} is the same as target price'
                        f' for the {target_price_place} place')
                    num_unchanged_prices += 1
                    await register_product_price_change_skip(product)
                    product_price_data = {'product': product, 'price': product.price,
                                          'product_details': product_details}
                    products_not_to_change_price.append(product_price_data)
                    continue

                product.product_flag = 'Hot'
                product.num_checks_without_changed_price = 0
                product.num_checks_to_skip = 0
                await sync_to_async(product.save)()

                product_price_data = {'product': product, 'price': target_price, 'product_details': product_details}
                products_to_change_price.append(product_price_data)

                logger.info(f'{verbose_price_explanation_log} result price = {target_price}')
            except KeyError as e:
                logger.error(f'KeyError for merchant {merchant.name} occurred for product {product.code} :: {e}')
                logger.error(project_logger.format_exception(e))

        number_of_products_to_change_prices = len(products_to_change_price)
        number_of_products_not_to_change_prices = len(products_not_to_change_price)
        logger.info(
            f'Number of products to change the price for merchant {merchant.name}  = {number_of_products_to_change_prices}')
        logger.info(
            f'Number of products not to change the price for merchant {merchant.name}  = {number_of_products_not_to_change_prices}')

        await xml_file_generation((products_not_to_change_price + products_to_change_price), merchant)

        if 0 < number_of_products_to_change_prices <= 250:
            logger.info(f'Merchant {merchant.name}, number of products to change prices '
                        f'is {number_of_products_to_change_prices}, so  '
                        f'changing price for each product started :: {datetime.datetime.now()}')
            for product_to_change_price in products_to_change_price:
                try:
                    task = change_product_price(kaspi_merchant_cabinet_methods, merchant,
                                                product_to_change_price['price'],
                                                product_to_change_price['product'],
                                                product_to_change_price['product_details'], proxy_provider)
                    tasks_chunk.append(task)
                    if len(tasks_chunk) == proxy_provider.num_proxies():
                        results = await asyncio.gather(*tasks_chunk, return_exceptions=True)
                        for result in results:
                            if result:
                                num_successfully_changed_prices += 1
                            else:
                                num_unsuccessfully_changed_prices += 1
                        sleep(REQUESTS_COOLDOWN_SECONDS)
                        tasks_chunk = []
                except BaseException as e:
                    logger.error(project_logger.format_exception(e))

            if len(tasks_chunk) > 0:
                results = await asyncio.gather(*tasks_chunk, return_exceptions=True)
                for result in results:
                    if result:
                        num_successfully_changed_prices += 1
                    else:
                        num_unsuccessfully_changed_prices += 1
                sleep(REQUESTS_COOLDOWN_SECONDS)
        elif number_of_products_to_change_prices == 0:
            logger.info(f'No prices to change for merchant {merchant.name}')

        duration = datetime.datetime.now().timestamp() - started_at

        logger.info(
            f'Merchant {merchant.name} prices untouched: {num_unchanged_prices}, changed: {num_successfully_changed_prices}, unable to change: {num_unsuccessfully_changed_prices}')
        logger.info(f'change_price_for_products for merchant {merchant.name} finished in {duration} sec')
    except Exception as e:
        logger.error(f'Some general merchant {merchant.name} failure while changing price')
        logger.error(project_logger.format_exception(e))


async def register_product_price_change_skip(product: KaspiProduct) -> None:
    product.num_checks_without_changed_price += 1

    if product.num_checks_without_changed_price >= 4 and product.product_flag == HOT_CATEGORY:
        product.product_flag = WARM_CATEGORY
        product.num_checks_to_skip = NUM_CHECKS_TO_SKIP_FOR_WARM_PRODUCT
        product.num_checks_without_changed_price = 0

    elif product.num_checks_without_changed_price >= 2 and product.product_flag == WARM_CATEGORY:
        product.product_flag = COLD_CATEGORY
        product.num_checks_to_skip = NUM_CHECKS_TO_SKIP_FOR_COLD_PRODUCT
        product.num_checks_without_changed_price = 0

    elif product.product_flag == WARM_CATEGORY:
        product.num_checks_to_skip = NUM_CHECKS_TO_SKIP_FOR_WARM_PRODUCT

    elif product.product_flag == COLD_CATEGORY:
        product.num_checks_to_skip = NUM_CHECKS_TO_SKIP_FOR_COLD_PRODUCT

    # noinspection PyArgumentList
    await sync_to_async(product.save)()

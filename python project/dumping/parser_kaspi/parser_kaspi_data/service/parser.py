import asyncio
import logging
from time import sleep
from django.conf import settings
from parser_kaspi_data.project_additional_models.data_models import PriceModel
from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods
from parser_kaspi_data.service.kaspi.kaspi_common_methods import get_competitors_data
from parser_kaspi_data.service.proxy_manager import ProxyProvider


REQUESTS_COUNT_PER_PROXY = 4  # Increasing this makes the script work faster but increases chances of 403 error
CHUNKS_REQUESTS_COOLDOWN_SECONDS = 0.5  # This parameter lets Kaspi think we do not do tons of requests per second

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


class Parser:
    async def process_list(self, data_list: PriceModel, proxy_provider: ProxyProvider, uid: str):
        tasks = []
        tasks_chunk = []
        for sku in data_list['sku_list']:
            task = self.process_sku(sku, data_list['city'], proxy_provider, uid)
            tasks_chunk.append(task)
            if len(tasks_chunk) == proxy_provider.num_proxies() * REQUESTS_COUNT_PER_PROXY:
                tasks.extend(await asyncio.gather(*tasks_chunk, return_exceptions=True))
                sleep(CHUNKS_REQUESTS_COOLDOWN_SECONDS)
                tasks_chunk = []

        if len(tasks_chunk) > 0:
            tasks.extend(await asyncio.gather(*tasks_chunk, return_exceptions=True))
            sleep(CHUNKS_REQUESTS_COOLDOWN_SECONDS)

        logger.info(f'Got {len(tasks)} tasks to process', extra={'uid': uid})

        return [task for task in tasks if task is not None]

    async def process_sku(self, sku, city, proxy_provider: ProxyProvider, uid: str):
        logger.info(f'process_sku :: sku:{sku} city:{city} num_proxies:{proxy_provider.num_proxies()}', extra={'uid': uid})
        try:
            competitors_data = await get_competitors_data(int(sku["sku"]), city, proxy_provider, uid)
        except BaseException as e:
            logger.error(f'Error occurred during get_competitors_data request for sku {sku}', extra={'uid': uid})
            logger.error(project_logger.format_exception(e))
            raise e

        if competitors_data is None:
            logger.error(f'Retries exceeded for get_competitors_data request for sku {sku}, returning None', extra={'uid': uid})
            return None

        offers = competitors_data['offers']

        if len(offers) == 0:
            logger.warning(f'No offers retrieved for get_competitors_data request for sku {sku}, returning None', extra={'uid': uid})
            return None

        try:
            kaspi_cabinet = KaspiMerchantCabinetMethods(
                login=sku['merchant'].login,
                password=sku['merchant'].password
            )
            sku["min_price"] = kaspi_cabinet.get_actual_product_price(
                merchant_id=sku['merchant'].merchant_id,
                product_id=sku['sku_merch'],
                city_id=city,
                proxy_proxider=proxy_provider,
                uid=uid
            )
            logger.info('#get_actual_product_price successs uid %s',
                        uid, extra={'sku': sku})
        except Exception as e:
            logger.error('#get_actual_product_price failed uid %s error %s',
                         uid, e, extra={'sku': sku})

        parsed_offer = {
            "sku": sku['sku'],
            "skuMerch": sku['sku_merch'],
            "title": sku['title'],
            "minPrice": sku['min_price'],
            "available": sku['available'],
            "merchant": sku['merchant'],
            "product_card_link": sku["product_card_link"],
            "product_image_link": sku["product_image_link"],
            "availabilities": sku["availabilities"],
            "merchants": []
        }

        for index, offer in enumerate(offers[:5]):
            merchant = {
                "merchantName": offer.get("merchantName"),
                "merchantRating": offer.get("merchantRating"),
                "price": offer.get("price")
            }
            parsed_offer["merchants"].append(merchant)

        logger.info(f'Parsed offers: {parsed_offer}', extra={'uid': uid})

        return parsed_offer

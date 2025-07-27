import os

import requests
from dotenv import load_dotenv

from parser_kaspi_data.models import Merchant
from parser_kaspi_data.project_additional_models.data_models import KaspiOrder, KaspiOrderEntry
from parser_kaspi_data.service.utils import convert_datetime_from_milliseconds

load_dotenv()


def get_headers(kaspi_token):
    return {
        'Accept': 'application/vnd.api+json',
        'X-Auth-Token': kaspi_token,
        'User-Agent': 'KaspiBot'
    }


def get_orders_with_products(page_size, order_state, date_start, date_finish, order_status, kaspi_token):
    """ Method to get information of all products in all orders from section "order_state"  and with status "order_status"
    between  "date_start"  and "date_finish" """

    merchants = Merchant.objects.all()
    for merchant in merchants:

        kaspi_orders = []
        page = 0

        while True:
            data = {
                'page[number]': page,
                'page[size]': page_size,
                'filter[orders][state]': order_state,
                'filter[orders][creationDate][$ge]': date_start,
                'filter[orders][creationDate][$le]': date_finish,
                'filter[order][status]': order_status,
                'include[orders]': 'entries'
            }
            url = 'https://kaspi.kz/shop/api/v2/orders'
            response = requests.get(url=url, params=data, headers=get_headers(kaspi_token))
            response_json = response.json()
            if 'data' in response_json:
                orders_data = response_json['data']
                orders_includes = response_json['included']
                for order_data in orders_data:
                    order_datetime = convert_datetime_from_milliseconds(order_data['attributes']['creationDate'])
                    kaspi_order = KaspiOrder(items=[], order_id=order_data['attributes']['code'], type=order_data['attributes']['state'],
                                             status=order_data['attributes']['status'], date=order_datetime)
                    entries_data = order_data['relationships']['entries']['data']
                    for entry_data in entries_data:
                        entry_id = entry_data['id']
                        for order_includes in orders_includes:
                            if entry_id == order_includes['id']:
                                quantity = order_includes['attributes']['quantity']
                                product_id = order_includes['relationships']['product']['data']['id']
                                product_info = get_product_info(product_id, merchant.kaspi_token)
                                if product_info is None:
                                    continue
                                product_code = product_info['attributes']['code']
                                title = product_info['attributes']['name']
                                kaspi_order_entry = KaspiOrderEntry(quantity=quantity, product_code=product_code, title=title)
                                kaspi_order['items'].append(kaspi_order_entry)
                                break
                    kaspi_orders.append(kaspi_order)

            if response_json['meta']['pageCount'] <= page:
                break
            page += 1

        return kaspi_orders


def get_product_info(product_code, kaspi_token):
    """ Method to get information about each product in an order (by product_code)
    Product_code is possible to get from get_order_content method """

    url = f'https://kaspi.kz/shop/api/v2/masterproducts/{product_code}/merchantProduct'
    response = requests.get(url=url, headers=get_headers(kaspi_token))

    return response.json()['data']


def get_kaspi_order(order_code, kaspi_token) -> KaspiOrder:
    """ Method to get status of individual kaspi order by order code"""

    data = {
        'filter[orders][code]': order_code,

    }
    url = 'https://kaspi.kz/shop/api/v2/orders'
    response = requests.get(url=url, params=data, headers=get_headers(kaspi_token))
    response_json = response.json()['data'][0]
    order_datetime = convert_datetime_from_milliseconds(response_json['attributes']['creationDate'])

    return KaspiOrder(items=[], order_id=response_json['attributes']['code'], type=response_json['attributes']['state'],
                      status=response_json['attributes']['status'], date=order_datetime)

import datetime
from typing import TypedDict, List


class SkuDict(TypedDict):
    sku_merch: str
    sku: str
    title: str
    min_price: str
    available: bool
    merchant: object
    product_card_link: str
    product_image_link: str
    availabilities: list


class PriceModel(TypedDict):
    city: int
    sku_list: List[SkuDict]


class CityPrices(TypedDict):
    availabilities: list
    city_prices: list


class KaspiOrderEntry(TypedDict):
    product_code: str
    quantity: int
    title: str


class KaspiOrder(TypedDict):
    items: List[KaspiOrderEntry]
    order_id: str
    date: datetime.datetime
    status: str
    type: str
import datetime
from typing import List
from dataclasses import dataclass


@dataclass
class RESTMerchantCabinetSession:
    session_id: str


@dataclass
class RESTAvailabilitiesObject:
    available: bool
    store_id: str


@dataclass
class RESTProduct:
    master_title: str
    sku: str            # model.mastersku
    master_sku: str     # mode.code
    image_link: str
    shop_link: str
    merchant_uid: str
    min_price: int
    available: bool
    availabilities: List[RESTAvailabilitiesObject | None]


@dataclass
class RESTProductList:
    data: List[RESTProduct]
    total: int


@dataclass
class RESTCity:
    id: str
    price: int
    old_price: int | None


@dataclass
class RESTProductDetail:
    sku: str  # model.mastersku
    title: str
    master_sku: str  # model.code
    cityInfo: List[RESTCity]


@dataclass
class RESTOffer:
    master_sku: str  # model.code
    merchant_id: str
    merchant_name: str
    merchant_sku: str  # model.mastersku
    merchant_reviews_quantity: int
    merchant_rating: float
    title: str
    price: float


@dataclass
class RESTOffersList:
    offers: List[RESTOffer]
    total: int
    offers_count: int
    # there are other keys

from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional


@dataclass
class Customer:
    id: str
    name: str
    firstName: str
    lastName: str
    cellPhone: str


@dataclass
class RESTOrderAttributes:
    code: str
    status: str
    totalPrice: Optional[float] = None
    plannedDeliveryDate: Optional[datetime] = None
    creationDate: Optional[datetime] = None
    isKaspiDelivery: Optional[bool] = None
    deliveryMode: Optional[str] = None
    signatureRequired: Optional[bool] = None
    state: Optional[str] = None
    customer: Optional[Customer] = None
    courierTransmissionDate: Optional[bool] = None


@dataclass
class RESTOrder:
    type: str
    id: str
    attributes: RESTOrderAttributes


@dataclass
class RESTOrderList:
    data: List[RESTOrder]
    page_count: int
    total_count: int


@dataclass
class Offer:
    code: str
    name: str


@dataclass
class Category:
    code: str
    title: str


@dataclass
class RESTOrderEntry:
    unitType: str
    type: str
    id: str
    basePrice: float
    quantity: float
    category: Category
    offer: Offer


@dataclass
class RESTOrderEntriesProduct:
    master_code: str
    name: str

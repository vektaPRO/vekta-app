from urllib3.exceptions import ResponseError
from typing import List

from api.service.kaspi.structs.base import RESTOrder, RESTOrderList, RESTOrderAttributes, Customer, \
    Category, Offer, RESTOrderEntry, RESTOrderEntriesProduct
from notifications.utils import convert_datetime_from_milliseconds


class BaseResponse:
    data = None
    code = None

    def __init__(self, data: dict, code: int, headers: dict):
        self.data = data
        self.code = code
        self.headers = headers

    def parse_response(self):
        raise NotImplementedError

    def parse_errors(self):
        if "error" in self.data:
            return ResponseError(self.data["error"])

    def parse(self):
        self.parse_errors()
        response = self.parse_response()
        return response


class OrderListResponse(BaseResponse):

    def parse_errors(self):
        if self.code != 200:
            raise ResponseError(self.data)

    def parse_response(self) -> RESTOrderList:
        order_list = RESTOrderList(
            data=[],
            total_count=self.data["meta"]["totalCount"],
            page_count=self.data["meta"]["pageCount"],
        )

        for order in self.data["data"]:

            planned_delivery_date = order['attributes'].get('plannedDeliveryDate', None)
            creation_date = order['attributes'].get('creationDate', None)
            courier_transmission_date = order['attributes']['kaspiDelivery'].get('courierTransmissionDate', None)

            if not planned_delivery_date is None:
                planned_delivery_date = convert_datetime_from_milliseconds(planned_delivery_date)
            if not creation_date is None:
                creation_date = convert_datetime_from_milliseconds(creation_date)
            if courier_transmission_date is not None:
                courier_transmission_date = convert_datetime_from_milliseconds(courier_transmission_date)

            order_obj = RESTOrder(
                type=order["type"],
                id=order["id"],
                attributes=RESTOrderAttributes(
                    code=order["attributes"]["code"],
                    plannedDeliveryDate=planned_delivery_date,
                    creationDate=creation_date,
                    isKaspiDelivery=order["attributes"]["isKaspiDelivery"],
                    deliveryMode=order["attributes"]["deliveryMode"],
                    signatureRequired=order["attributes"]["signatureRequired"],
                    state=order["attributes"]["state"],
                    status=order["attributes"]["status"],
                    totalPrice=order["attributes"]["totalPrice"],
                    courierTransmissionDate=courier_transmission_date,
                    customer=Customer(
                        id=order["attributes"]["customer"]["id"],
                        name=order["attributes"]["customer"]["name"],
                        firstName=order["attributes"]["customer"]["firstName"],
                        lastName=order["attributes"]["customer"]["lastName"],
                        cellPhone=order["attributes"]["customer"]["cellPhone"],
                    )
                ),
            )

            order_list.data.append(order_obj)

        return order_list


class OrderEntriesResponse(BaseResponse):
    def parse_errors(self):
        if self.code != 200:
            raise ResponseError(self.data)

    def parse_response(self) -> List[RESTOrderEntry]:
        order_entries = []
        for order_entry in self.data["data"]:
            product = RESTOrderEntry(
                id=order_entry["id"],
                type=order_entry["type"],
                unitType=order_entry['attributes']['unitType'],
                basePrice=order_entry['attributes']['basePrice'],
                quantity=order_entry['attributes']['quantity'],
                category=Category(
                    code=order_entry['attributes']['category']['code'],
                    title=order_entry['attributes']['category']['title'],
                ),
                offer=Offer(
                    code=order_entry['attributes']['offer']['code'],
                    name=order_entry['attributes']['offer']['name'],
                )
            )
            order_entries.append(product)

        return order_entries


class OrderEntriesProductResponse(BaseResponse):
    def parse_errors(self):
        if self.code != 200:
            raise ResponseError(self.data)

    def parse_response(self) -> RESTOrderEntriesProduct:
        product = RESTOrderEntriesProduct(
            name=self.data["data"]["attributes"]["name"],
            master_code=self.data["data"]["attributes"]["code"]
        )
        return product


class ConfirmNewOrderResponse(BaseResponse):
    def parse_response(self) -> RESTOrder:
        order = RESTOrder(
            type=self.data["data"]["type"],
            id=self.data["data"]["id"],
            attributes=RESTOrderAttributes(
                code=self.data["data"]["attributes"]["code"],
                status=self.data["data"]["attributes"]["status"]
            )
        )

        return order

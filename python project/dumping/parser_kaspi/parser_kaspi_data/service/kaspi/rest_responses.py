import re
from rest_framework import status
from .exceptions import ResponseError, IncorrectLoginException, InvalidSessionException
from parser_kaspi_data.service.kaspi.structs.base import (
    RESTMerchantCabinetSession, RESTProduct, RESTProductList, RESTAvailabilitiesObject,
    RESTCity, RESTProductDetail, RESTOffer, RESTOffersList
)


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
            raise ResponseError(self.data["error"])

    def parse(self):
        self.parse_errors()
        response = self.parse_response()
        return response


class MerchantCabinetGetSessionResponse(BaseResponse):

    def parse_errors(self):
        if self.code != status.HTTP_200_OK:
            raise IncorrectLoginException

    def parse_response(self) -> RESTMerchantCabinetSession:
        regex = r"X-Mc-Api-Session-Id=([^;]*);"
        obj = RESTMerchantCabinetSession(
            session_id=re.findall(regex, self.headers.get('Set-Cookie'), re.MULTILINE)[0]
        )
        return obj


class CabinetProductListResponse(BaseResponse):

    def parse_errors(self):
        if self.code != status.HTTP_200_OK:
            raise InvalidSessionException

    def parse_response(self) -> RESTProductList:
        product_list = RESTProductList(
            data=[],
            total=self.data['total']
        )

        for product in self.data['data']:
            product_obj = RESTProduct(
                    master_title=product['masterTitle'],
                    master_sku=product['masterSku'],
                    merchant_uid=product['merchantUid'],
                    image_link=product['images'][0],
                    shop_link=product['shopLink'],
                    min_price=product['minPrice'],
                    available=product['available'],
                    availabilities=[],
                    sku=product['sku'],
                )
            for avail in product['availabilities']:
                product_obj.availabilities.append(
                    RESTAvailabilitiesObject(
                        available=avail['available'],
                        store_id=avail['storeId']
                    )
                )
            product_list.data.append(product_obj)
        return product_list


class CabinetProductDetailResponse(BaseResponse):

    def parse_errors(self):
        if self.code != status.HTTP_200_OK:
            raise ResponseError(self.data.get('message'))

    def parse_response(self) -> RESTProductDetail:
        return RESTProductDetail(
            sku=self.data['sku'],
            title=self.data['title'],
            master_sku=self.data['masterSku'],
            cityInfo=[
                RESTCity(
                    id=city['id'],
                    price=city['price'],
                    old_price=city['oldPrice']
                )
                for city in self.data['cityInfo']
            ]
        )


class ProductCompetitorsListResponse(BaseResponse):

    def parse_errors(self):
        if self.code == status.HTTP_403_FORBIDDEN:
            raise ResponseError('Not found')
        if self.code != status.HTTP_200_OK:
            raise ResponseError(self.data)

    def parse_response(self) -> RESTOffersList:
        obj = RESTOffersList(
            offers=list(),
            total=self.data['total'],
            offers_count=self.data['offersCount']
        )

        for offer in self.data['offers']:
            obj.offers.append(
                RESTOffer(
                    master_sku=offer['masterSku'],
                    merchant_id=offer['merchantId'],
                    merchant_name=offer['merchantName'],
                    merchant_sku=offer['merchantSku'],
                    merchant_reviews_quantity=offer['merchantReviewsQuantity'],
                    merchant_rating=offer['merchantRating'],
                    title=offer['title'],
                    price=offer['price']
                )
            )

        return obj


class CabinetProductUpdateResponse(BaseResponse):

    def parse_errors(self):
        if self.code != status.HTTP_200_OK:
            raise ResponseError(self.data)

    def parse_response(self) -> str:
        return self.data.get('id', '')

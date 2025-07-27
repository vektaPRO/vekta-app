from django.db import transaction as db_transaction
from .models import KaspiProduct
from asgiref.sync import sync_to_async


class Product:

    @staticmethod
    def check_if_product_exists(product_sku, merchant):
        return KaspiProduct.objects.filter(master_sku=product_sku, merchant=merchant).exists()

    @staticmethod
    def create_new_product(title, price, first_place_price, second_place_price, third_place_price, code, master_sku, available, merchant, current_price_place,
                           product_card_link, product_image_link, availabilities):
        return KaspiProduct.objects.create(title=title, price=price, first_place_price=first_place_price,
                                           second_place_price=second_place_price, third_place_price=third_place_price,
                                           code=code, master_sku=master_sku, available=available, merchant=merchant,
                                           current_price_place=current_price_place, product_card_link=product_card_link,
                                           product_image_link=product_image_link, availabilities=availabilities)

    @staticmethod
    def update_product_info(title, price, first_place_price, second_place_price, third_place_price, code, master_sku, available, merchant, current_price_place,
                            product_card_link, product_image_link, availabilities):

        KaspiProduct.objects.filter(master_sku=master_sku, merchant=merchant).update(
            title=title,
            price=price,
            first_place_price=first_place_price,
            second_place_price=second_place_price,
            third_place_price=third_place_price,
            code=code,
            master_sku=master_sku,
            available=available,
            merchant=merchant,
            current_price_place=current_price_place,
            product_card_link=product_card_link,
            product_image_link=product_image_link,
            recently_parsed=True,
            availabilities=availabilities
        )

        return True

    @staticmethod
    def get_products_with_auto_price_change(merchant):
        if merchant.allowed_number_of_products_with_price_change:
            return KaspiProduct.objects.filter(price_auto_change=True, available=True, merchant=merchant,
                                               recently_parsed=True)[:merchant.allowed_number_of_products_with_price_change]
        return KaspiProduct.objects.filter(price_auto_change=True, available=True, merchant=merchant,
                                           recently_parsed=True)

    @staticmethod
    def get_products_without_auto_price_change(merchant, products_to_be_checked):
        return KaspiProduct.objects.filter(merchant=merchant).exclude(code__in=products_to_be_checked)


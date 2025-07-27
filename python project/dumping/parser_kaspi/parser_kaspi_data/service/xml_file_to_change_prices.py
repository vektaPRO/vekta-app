import hashlib
import os
import logging
from typing import List
import xml.etree.ElementTree as ET
from xml.dom import minidom
from xml.sax.saxutils import unescape

from asgiref.sync import sync_to_async
from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import DefaultStorage

from pktools.string import generate_string
from parser_kaspi_data.models import Merchant


logger = logging.getLogger(settings.STORAGE_LOGGER_NAME)


async def create_xml(products_list: List, merchant: Merchant):
    # TODO: estimate duration of these function
    uid = generate_string()
    logger.info(
        'Starting generate xml file for merchant %s', merchant.name,
        extra={
            'uid': uid,
            'merchant_id': merchant.id,
            'merchant_cabinet_id': merchant.merchant_id,
        }
    )

    root = ET.Element('kaspi_catalog',
                      attrib={'xmlns': 'kaspiShopping',
                              'xmlns:xsi': "http://www.w3.org/2001/XMLSchema-instance",
                              "date": "string",
                              "xsi:schemaLocation": "http://kaspi.kz/kaspishopping.xsd"}
                      )
    company_element = ET.SubElement(root, "company")
    company_element.text = merchant.name
    merchant_id_element = ET.SubElement(root, "merchantid")
    merchant_id_element.text = merchant.merchant_id
    offers_element = ET.SubElement(root, "offers")
    for product_data in products_list:
        offer_element = ET.SubElement(offers_element, "offer", attrib={"sku": unescape(str(product_data['product'].master_sku))})
        ET.SubElement(offer_element, 'model').text = unescape(str(product_data['product'].title))
        ET.SubElement(offer_element, 'brand').text = unescape(str('Brand'))
        availabilities_element = ET.SubElement(offer_element, "availabilities")
        for availability in product_data['product_details']['availabilities']:
            ET.SubElement(availabilities_element, "availability", attrib=availability)
        ET.SubElement(offer_element, 'price').text = unescape(str(product_data['price']))

    xml_str = ET.tostring(root, encoding='utf-8', method='xml')
    xml_dom = minidom.parseString(xml_str)
    pretty_xml_str: str = xml_dom.toprettyxml(indent="  ")

    hash_value = create_hash_value_for_merchant(merchant.merchant_id)
    storage = DefaultStorage()
    name = storage.save(f'output/prices_to_upload_{hash_value}.xml', ContentFile(pretty_xml_str.encode('utf-8')))
    url = storage.url(name)
    merchant.xml_file_path = url

    logger.info(
        'Completed generate xml file for merchant %s', merchant.name,
        extra={
            'uid': uid,
            'merchant_id': merchant.id,
            'merchant_cabinet_id': merchant.merchant_id,
            'file_path': url
        }
    )

    await sync_to_async(merchant.save)()


def create_hash_value_for_merchant(merchant_id):
    hash_value = hashlib.md5(f'{merchant_id} + {os.getenv("HASH")}'.encode('utf8')).hexdigest()

    return hash_value

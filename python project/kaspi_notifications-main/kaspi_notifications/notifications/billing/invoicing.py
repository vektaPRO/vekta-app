from notifications.constants import INVOICE_TYPE_REGISTRATION
from notifications.models import Merchant, Invoice


def get_invoice_price_cents(invoice_type: str) -> int:
    if invoice_type == INVOICE_TYPE_REGISTRATION:
        return 9900 * 100

    raise BaseException


def create_registration_invoice(merchant: Merchant) -> Invoice:
    invoice_type = INVOICE_TYPE_REGISTRATION
    return Invoice.objects.create(
        merchant=merchant,
        type=invoice_type,
        amount=get_invoice_price_cents(invoice_type),
        currency='KZT',
        status='draft'
    )

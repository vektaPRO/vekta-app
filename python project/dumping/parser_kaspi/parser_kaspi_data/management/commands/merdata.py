from django.core.cache import cache
from django.core.management.base import BaseCommand, CommandError
from parser_kaspi_data.models import Merchant
from parser_kaspi_data.service.kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods


class Command(BaseCommand):
    help = 'Get merchant session_id and cabinet_id'

    def add_arguments(self, parser):
        parser.add_argument('merchant_id', nargs='+', type=str)

    def handle(self, *args, **options):
        merchant_id = options['merchant_id'][0]
        try:
            merchant = Merchant.objects.get(pk=int(merchant_id))
        except Merchant.DoesNotExist:
            raise CommandError('Merchant not found')
        except Exception:
            raise CommandError('Not valid argument')

        try:
            kaspi_merchant_cabinet_methods = KaspiMerchantCabinetMethods(merchant.login, merchant.password)
            session_id = kaspi_merchant_cabinet_methods.session_id
            cabinet_id = merchant.merchant_id
        except Exception as e:
            raise CommandError(f'Failed to authenticate: {str(e)}')

        login = merchant.login
        password = merchant.password

        self.stdout.write(
            self.style.SUCCESS(f'Merchant session_id - {session_id}, cabinet_id - {cabinet_id}, login - {login}, password - {password}')
        )

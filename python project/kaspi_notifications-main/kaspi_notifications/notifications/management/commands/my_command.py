import logging

from django.conf import settings
from django.core.management.base import BaseCommand

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class Command(BaseCommand):
    help = "Test command to ensure everything is working"

    def handle(self, *args, **options):
        logger.info('NEW TEST?', extra={'SKU': {"id": 20, 'test': 'test'}})

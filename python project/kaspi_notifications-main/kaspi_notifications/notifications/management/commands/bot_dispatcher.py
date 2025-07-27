from django.core.management.base import BaseCommand

from notifications.telegram_bot.main import run_bot_dispatcher


class Command(BaseCommand):
    def handle(self, **options):
        run_bot_dispatcher()

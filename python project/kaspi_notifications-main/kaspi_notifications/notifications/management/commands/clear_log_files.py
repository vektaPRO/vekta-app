from django.core.management.base import BaseCommand, CommandError

from django.conf import settings


class Command(BaseCommand):
    help = "Clear log files"

    def handle(self, *args, **options):
        log_dir = settings.LOG_DIR

        try:
            if not log_dir.exists():
                raise CommandError(f"Log directory '{log_dir}' does not exist.")
                return

            for log_file in log_dir.iterdir():
                with open(log_file, 'w') as f:
                    f.truncate()  # Clear the file
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Log file {log_file} successfully has been cleared.')
                )

        except Exception as e:
            raise CommandError(f"An error occurred: {e}")


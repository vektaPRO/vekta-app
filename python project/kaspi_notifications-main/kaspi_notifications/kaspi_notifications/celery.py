import os

from celery import Celery
from dotenv import load_dotenv


load_dotenv()

user = os.getenv('RABBITMQ_USERNAME')
password = os.getenv('RABBITMQ_PASSWORD')
host = os.getenv('RABBITMQ_HOST')


app = Celery(
    'kaspi_notifications',
    broker=f'amqp://{user}:{password}@{host}', # Use `localhost` when running locally, use `rabbitmq` when running from container
    include=[
        'kaspi_notifications.tasks',
        'kaspi_notifications.additional_tasks',
        'kaspi_notifications.periodic',
        'notifications.greenapi_instance_functions'
    ]
)

app.config_from_object('django.conf:settings', namespace='CELERY')

import os
from celery import Celery
from dotenv import load_dotenv


load_dotenv()

password = os.getenv('REDIS_PASSWORD')
host = os.getenv('REDIS_HOST')


app = Celery(
    'parser_kaspi',
    broker=f'redis://:{password}@{host}:6379', # Use `localhost` when running locally, use `redis` when running from container
    include=['parser_kaspi.tasks', 'parser_kaspi.periodic']
)

app.config_from_object('django.conf:settings', namespace='CELERY')

if __name__ == '__main__':
    app.start()

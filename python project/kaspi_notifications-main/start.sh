#!/bin/bash

cd kaspi_notifications
#python manage.py makemigrations notifications
python manage.py migrate notifications
python manage.py migrate --noinput
python manage.py collectstatic --noinput
gunicorn kaspi_notifications.wsgi:application \
  --timeout 180 \
  --bind 0.0.0.0:8000 \
  --workers 8 \
  --log-level debug
  --access-logfile -
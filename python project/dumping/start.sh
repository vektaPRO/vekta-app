#!/bin/bash

cd parser_kaspi
#python manage.py makemigrations parser_kaspi_data
python manage.py migrate parser_kaspi_data
python manage.py migrate --noinput
python manage.py collectstatic --noinput
gunicorn parser_kaspi.wsgi:application --timeout 7000 --log-level=debug --bind 0.0.0.0:8000 --reload

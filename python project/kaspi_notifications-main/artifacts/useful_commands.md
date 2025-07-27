## Celery
### Check rabbitmq queue size
```shell
docker-compose exec rabbitmq bash
rabbitmqctl list_queues
```

### Check celery info
```shell
docker-compose exec web bash
cd kaspi_notifications
export DJANGO_SETTINGS_MODULE="kaspi_notifications.settings"; celery -A kaspi_notifications inspect active
```

### Grep followed logs
```shell
tail -f logs.txt| grep "schedule_merchants_new_orders_parsing" --line-buffered
```

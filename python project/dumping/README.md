# To initiate celery tasks locally
Run rabbitmq docker container: docker run -d -p 5672:5672 bitnami/rabbitmq:latest
export DJANGO_SETTINGS_MODULE="parser_kaspi.settings.local"; celery -A parser_kaspi worker --loglevel=DEBUG
export DJANGO_SETTINGS_MODULE="parser_kaspi.settings.local"; celery -A parser_kaspi beat --loglevel=DEBUG

# rabbitmq container
Add RABBITMQ_MANAGEMENT_ALLOW_WEB_ACCESS=True in rabbitmq container configuration in docker-compose.yaml


## Celery
### Check rabbitmq queue size
```shell
docker-compose exec rabbitmq bash
rabbitmqctl list_queues
rabbitmqctl set_disk_free_limit


##Get https-certificate
add certbot container in docker-compose.yaml and nginx.conf (not the second part)
restart containers
dry run  - docker compose run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d example.org
if everything is ok - docker compose run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ -d example.org
if everythins if ok - add second part (443) into nginx.conf
restart containers
# To initiate celery tasks locally
Run rabbitmq docker container: docker run -d -p 5672:5672 bitnami/rabbitmq:latest
export DJANGO_SETTINGS_MODULE="kaspi_notifications.settings"; celery -A kaspi_notifications worker --loglevel=DEBUG
export DJANGO_SETTINGS_MODULE="kaspi_notifications.settings"; celery -A kaspi_notifications beat --loglevel=DEBUG

# rabbitmq container
Add RABBITMQ_MANAGEMENT_ALLOW_WEB_ACCESS=True in rabbitmq container configuration in docker-compose.yaml

# certbot
On server first of all remove certbot 443 port configuration from nginx.conf
Then docker-compose up
Then use command:
docker compose run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d example.org (with and without dry run)
Then add certbot 443 port configuration to nginx.conf and run GitHub actions to make containers up
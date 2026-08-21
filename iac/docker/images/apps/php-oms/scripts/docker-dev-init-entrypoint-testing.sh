#!/bin/bash

echo "[INFO] Composer install"
cd /app
composer install

mkdir -p /app/logs && touch /app/logs/log.json && chown www-data:www-data -R /app/logs && chmod -R 0777 .database logs vendor

set -e
CON=0
while ! psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER}  -U ${DB_ROOT_USER} -c "select 1"; do
    sleep 5;
done

psql -h ${HISTORY_MASTER_HOST_FOR_ROOT_USER} -U postgres  -tc "SELECT 1 FROM pg_database WHERE datname = '$HISTORY_DB_NAME'" | grep -q 1 || createdb -h ${HISTORY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${HISTORY_DB_NAME}
psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U postgres  -tc "SELECT 1 FROM pg_database WHERE datname = '$ORDERS_DELIVERY_DB_NAME'" | grep -q 1 || createdb -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${ORDERS_DELIVERY_DB_NAME}
psql -h ${REPORT_MASTER_HOST_FOR_ROOT_USER} -U postgres  -tc "SELECT 1 FROM pg_database WHERE datname = '$REPORT_DB_NAME'" | grep -q 1 || createdb  -h ${REPORT_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${REPORT_DB_NAME}

psql -h ${HISTORY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${HISTORY_DB_NAME} -c "select 1 from history;" || CON=1
psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${ORDERS_DELIVERY_DB_NAME} -c "select 1 from guest;" || CON=1
psql -h ${REPORT_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${REPORT_DB_NAME} -c "select 1 from report_migration;" || CON=1
echo $CON

echo "[INFO] Changing postgres configuration"
psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER}  -U ${DB_ROOT_USER} -f "/app/docker/php-oms/scripts/psql-config.sql"
echo "[INFO] Reboot postgres configuration"
psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER}  -U ${DB_ROOT_USER} -c "SELECT pg_reload_conf();"

if test "${CON}" -ne 0;
then
    echo "============INITDB+STARTED============";
    php /app/migrations/setup/recreateTest.php;
    echo "============INITDB+FINISHED===========";
    psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${ORDERS_DELIVERY_DB_NAME} -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO orders_delivery;"
    psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${ORDERS_DELIVERY_DB_NAME} -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO orders_delivery;"
    exit 0;

fi
set -e

vendor/bin/phinx migrate -c ./migrations/orders_delivery.php
vendor/bin/phinx migrate -c ./migrations/report.php
vendor/bin/phinx migrate -c ./migrations/history.php
psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${ORDERS_DELIVERY_DB_NAME} -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO orders_delivery;"
psql -h ${ORDERS_DELIVERY_MASTER_HOST_FOR_ROOT_USER} -U ${DB_ROOT_USER} ${ORDERS_DELIVERY_DB_NAME} -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO orders_delivery;"

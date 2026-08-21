#!/bin/bash

mkdir -p /app/logs && touch /app/logs/log.json && chown www-data:www-data -R /app/logs && chmod -R 0777 logs

php-fpm -y /etc/php-fpm.conf -F

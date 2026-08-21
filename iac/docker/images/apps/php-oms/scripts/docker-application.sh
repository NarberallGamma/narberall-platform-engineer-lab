#!/bin/bash
set -e

/usr/lib/postfix/sbin/master -w

php-fpm -y /etc/php-fpm.conf -F

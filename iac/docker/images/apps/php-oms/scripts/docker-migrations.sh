#!/bin/bash
set -e

su www-data -c 'vendor/bin/phinx migrate -c ./migrations/orders_delivery.php'
su www-data -c 'vendor/bin/phinx migrate -c ./migrations/report.php'
su www-data -c 'vendor/bin/phinx migrate -c ./migrations/history.php'

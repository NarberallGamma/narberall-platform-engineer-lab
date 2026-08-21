#!/bin/bash

echo "chown -R www-data:www-data /app/storage"
chown -R www-data:www-data /app/storage
echo "chmod -R 755 /app/storage"
chmod -R 755 /app/storage

echo "start migrate script"

function mysql_exec {
  /usr/bin/mysql -h$DB_HOST -u$DB_USERNAME -p$DB_PASSWORD -e "$@" >&2
}

echo "start Waiting db ${DB_DATABASE}"

while true; do
  if mysqladmin ping -h $DB_HOST; then
    break;
  fi
  echo "Waiting for mysql ${DB_DATABASE} loaded!"
  sleep 1;
done

echo "start Waiting file autoload.php"

while true; do
  if [ -f /app/vendor/autoload.php ]; then
    break;
  fi
  echo "Waiting for file autoload.php!"
  sleep 1;
done

php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan cache:clear
php artisan migrate --force
php artisan db:seed
php artisan ide-helper:generate
php artisan ide-helper:meta
php artisan ide-helper:models -N

echo "finish"

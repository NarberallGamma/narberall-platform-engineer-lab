#!/bin/bash

 function mysql_exec {
   /usr/bin/mysql -h$DB_HOST -u$DB_USERNAME -p$DB_PASSWORD -e "$@" >&2
 }

 echo "start Waiting db ${DB_DATABASE}"

 while true; do
   if mysqladmin ping -h  $DB_HOST; then
     break;
   fi
   echo "Waiting for mysql ${DB_HOST} loaded!"
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

 while [  true ]; do
     php /app/artisan schedule:run > /dev/null 2>&1
     sleep 60s
 done

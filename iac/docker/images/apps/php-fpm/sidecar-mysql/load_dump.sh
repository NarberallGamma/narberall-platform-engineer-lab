#!/bin/bash -e
function mysql_exec {
  /usr/bin/mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "$@" >&2
  }

while true; do
  if mysql_exec "SELECT 1" > /dev/null; then
    break;
  fi
  echo "Waiting for mysql to appear!"
  sleep 1;
done

#db
declare -a dbs=("${MYSQL_DATABASE}")
need_repeat=1
cnt=1
while [ $need_repeat -eq 1 ]; do
	cnt=`expr $cnt + 1`
	db_var="MYSQL_DATABASE_$cnt"
	db_name="${!db_var}"
	dbs+=($db_name)
	if [ -z $db_name ]; then
	    need_repeat=0
	    break
	fi;
done
echo "Array databases created"
for i in "${dbs[@]}"
do
  echo "do work for ${i}"
  mysql_exec "DROP DATABASE IF EXISTS \`${i}\`" && echo "DB ${i} dropped"
  mysql_exec "CREATE DATABASE \`${i}\` CHARACTER SET = utf8 COLLATE = utf8_general_ci" && echo "DB ${i} created"
  mysql_exec "GRANT ALL PRIVILEGES ON \`${i}\`.* TO ${MYSQL_USER}" && echo "Rights on DB ${i} granted"
  echo "Loading dump ${i}"
  gunzip < /var/dumps/shop.sql.gz | /usr/bin/mysql -uroot -p${MYSQL_ROOT_PASSWORD} ${i}
  /usr/bin/mysql -uroot -p${MYSQL_ROOT_PASSWORD} ${i} < /var/dumps/testdata.sql
done

#create billing dump
echo "create billing dump"
mysql_exec "DROP DATABASE IF EXISTS billing" && echo "DB billing dropped"
mysql_exec "CREATE DATABASE billing" && echo "DB billing created"
echo "Loading dump"
gunzip < /var/dumps/billing.sql.gz | /usr/bin/mysql -uroot -p${MYSQL_ROOT_PASSWORD} billing

mysql_exec "UPDATE billing.users SET created_at = NOW()" && echo "DB billing create_at updated"

#create shop_conf.config
echo "create shop_conf dump"
mysql_exec "DROP DATABASE IF EXISTS shop_conf" && echo "DB shop_conf dropped"
mysql_exec "CREATE DATABASE shop_conf" && echo "DB shop_conf created"
echo "Loading dump"
gunzip < /var/dumps/shop_conf.sql.gz | /usr/bin/mysql -uroot -p${MYSQL_ROOT_PASSWORD} shop_conf

#successful load dump table
echo "load_dump db&table"
mysql_exec "DROP DATABASE IF EXISTS load_dump" && echo "DB load_dump dropped"
mysql_exec "CREATE DATABASE load_dump" && echo "DB load_dump created"
mysql_exec "CREATE TABLE load_dump.dump_loaded (number tinyint(1) DEFAULT NULL)"

#!/bin/bash

# Этот файл - черновик скрипта для бэкапа influxdb.
# Скрипт рабочий, но не универсальный.
# TODO: написать вокруг этой логики параметризацию/универсализацию.

# Initialize things
backup_name=$1
container_name=$(docker ps | grep influx |  awk '{print $1}')
timestamp=`date +"%s_%d-%B-%Y_%A@%H%M"`
backup_tmp="/tmp/influxbkp/"
backup_tar_file="influxdb_backup_$timestamp.tar.gz"

echo `date +"%d-%B-%Y@%H:%M:%S"`" - Starting backups."

# List all the databases
databases=` docker exec $container_name influx -port 8086 -execute 'show databases' | sed -n -e '/----/,$p' | grep -v -e '----' -e '_internal'`

# Loop the databases
for db in $databases; do

  echo `date +"%d-%B-%Y@%H:%M:%S"`" - Backing up database $db to $backup_tmp/$db."

  # Dump
  docker exec $container_name influxd backup -portable -database $db $backup_tmp/$db

done;

# Upload by restic
/home/restic/00-scripts/restic_backup_files.sh $backup_name $backup_tmp

#Cleanup
rm -rf $backup_tmp

# All done
echo `date +"%d-%B-%Y@%H:%M:%S"`" - All done."
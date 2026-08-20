#!/bin/bash

NAME=$1
DB=$2

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

systemctl stop neo4j || alert "Neo4j shutdown has failed"
while `nc -z 127.0.0.1 7687`; do 
    sleep 1
done
neo4j-admin dump --database=${DB} --to=/mnt/neo4j_backups/unit.dump || alert "Neo4j command 'neo4j-admin dump' has failed"
systemctl start neo4j || alert "Neo4j startup has failed"
00-scripts/borg_backup_files.sh ${NAME:-GITLAB} "/mnt/neo4j_backups" --prune "--keep-within=7d"
find /mnt/neo4j_backups -type f -ls -delete
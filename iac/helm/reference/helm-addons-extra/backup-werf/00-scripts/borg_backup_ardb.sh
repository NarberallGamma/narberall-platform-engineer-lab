#!/usr/bin/env bash

NAME=${1}
PORT=${2}
BACKUPDIR=${3}

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

if [ -z ${PORT} ]; then
  alert "Ardb port doesn't set" "Set ardb port in schedule"
fi

if [ -z ${BACKUPDIR} ]; then
  alert "Ardb backup dir doesn't set" "Set ardb backup dir in schedule"
fi

redis-cli -p ${PORT} save ardb || alert "redis-cli save failed"

00-scripts/borg_backup_files.sh ${NAME:-'ARDBUNNAMED'} "${BACKUPDIR}"
rm -v ${BACKUPDIR}/*

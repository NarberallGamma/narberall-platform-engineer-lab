#!/usr/bin/env bash

source vars
NAMEOFBACKUP=${1}
TYPEOFBACKUP='ESDUMP'
REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
INDICE=${2}
export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

type elasticdump || { alert "elasticdump not installed" "Please install elasticdump manually" ; exit 1; }

borg init -e none ${REPOSITORY}

# if indice is not set then dump all indices in ES
if [ -z "${INDICE}" ]; then
  { /usr/bin/elasticdump --all --input=http://localhost:9200 --output=$ \
        || alert "elasticdump failed $?"; } \
        | borg create --list -v --stats \
        $REPOSITORY::"$TYPEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
        || alert "borg create failed $?"
else
# else dump only given indice
  { /usr/bin/elasticdump --all --input=http://localhost:9200/${INDICE} --output=$ \
        || alert "elasticdump failed $?"; } \
        | borg create --list -v --stats \
        $REPOSITORY::"$TYPEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
        || alert "borg create failed $?"
fi

#prune
borg prune -v --list $REPOSITORY \
      --keep-within=65d || alert "borg prune failed"

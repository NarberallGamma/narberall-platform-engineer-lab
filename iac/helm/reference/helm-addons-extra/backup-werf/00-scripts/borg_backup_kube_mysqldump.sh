#!/usr/bin/env bash

source vars
# Путь до конфига kubectl
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
DEFAULTS_FILE='--defaults-file=/etc/mysql/debian.cnf'
NAMEOFNAMESPACE=${1}
NAMEOFPOD=${2}
NAMEOFBACKUP="MYSQLDUMP"
MYUSER="MYSQLUSER_HERE"
MYPASSWORD="PASS_HERE"
REPOSITORY="${BORG_SERVER}:${NAMEOFPOD}-${NAMEOFBACKUP}"

function alert {
  BACKUP_TARGET=$(hostname)-${NAMEOFPOD}
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

borg init -e none ${REPOSITORY}

POD=$(kubectl -n ${NAMEOFNAMESPACE} get pods | grep "${NAMEOFPOD}" | awk '{print $1}' | head -n 1)

kubectl exec -ti -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "mysqldump ${DEFAULTS_FILE} mysql > /dev/null"
mysqldump_exit=${?}

CREDENTIALS="${DEFAULTS_FILE}"
if [ ${mysqldump_exit} -ne 0 ];
then
  CREDENTIALS="-u${MYUSER} -p${MYPASSWORD}"
fi

kubectl exec \
  -ti \
  -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "mysqldump ${$CREDENTIALS} --single-transaction --all-databases --set-gtid-purged=OFF" \
      | borg create -v --stats --show-rc \
      $REPOSITORY::"$NAMEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
      || { alert "borg create failed: $?"; exit 1; }

borg prune -v --list $REPOSITORY \
      --keep-within=65d || alert "borg prune failed"

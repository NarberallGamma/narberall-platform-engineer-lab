#!/usr/bin/env bash

source vars
DEFAULTS_FILE='--defaults-file=/etc/mysql/debian.cnf'
NAMEOFNAMESPACE=${1}
NAMEOFPOD=${2}
NAMEOFBACKUP="MYSQLDUMP"
MYUSER="MYSQLUSER_HERE"
MYPASSWORD="CHANGE_ME"
REPOSITORY="${BORG_SERVER}:${NAMEOFPOD}-${NAMEOFBACKUP}"
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
KUBECTL="/opt/deckhouse/bin/kubectl"

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no -i /root/.ssh/.borg"

function alert {
  BACKUP_TARGET=$(hostname)-${NAMEOFPOD}
  BACKUP_TYPE=${NAMEOFBACKUP}
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

borg init -e none ${REPOSITORY}

POD=$(${KUBECTL} -n ${NAMEOFNAMESPACE} get pods | grep "${NAMEOFPOD}" | awk '{print $1}' | head -n 1)

${KUBECTL} exec -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "mysqldump ${DEFAULTS_FILE} mysql > /dev/null"
mysqldump_exit=${?}

CREDENTIALS="${DEFAULTS_FILE}"
if [ ${mysqldump_exit} -ne 0 ];
then
  CREDENTIALS="-u${MYUSER} -p${MYPASSWORD}"
fi

${KUBECTL} exec \
  -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "mysqldump ${CREDENTIALS} --single-transaction --all-databases --set-gtid-purged=OFF" \
      | borg create -v --stats --show-rc \
      $REPOSITORY::"$NAMEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
      || { alert "borg create failed: $?"; exit 1; }

borg prune -v --list $REPOSITORY --prefix "$NAMEOFBACKUP-" \
      --keep-within=65d || alert "borg prune failed"

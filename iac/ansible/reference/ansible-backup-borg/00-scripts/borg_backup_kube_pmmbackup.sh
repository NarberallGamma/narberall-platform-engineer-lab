#!/usr/bin/env bash

source vars
# Путь до конфига kubectl
KUBECONF_FILE="/home/borg/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
NAMEOFNAMESPACE=${1}
NAMEOFPOD=${2}
PSQLUSER="postgres"

function alert {
  BACKUP_TARGET=$(hostname)-${NAMEOFPOD}
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

POD=$(kubectl -n ${NAMEOFNAMESPACE} get pods | grep "${NAMEOFPOD}" | awk '{print $1}' | head -n 1)

function pmmpostgres {
  NAMEOFBACKUP="PMMPOSTGRES"
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
  borg init -e none ${REPOSITORY}
  kubectl exec \
    -ti \
    -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "pg_dump -h 127.0.0.1 -U postgres pmm-managed" \
        | borg create -v --stats --show-rc \
        $REPOSITORY::"$NAMEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
        || { alert "borg create failed: $?"; exit 1; }
}

#restore:
#clickhouse-client --query="INSERT INTO metrics FORMAT Native" < metrics.native
function pmmclickhouse {
  NAMEOFBACKUP="PMMCLICKHOUSE"
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
  borg init -e none ${REPOSITORY}
  kubectl exec \
    -ti \
    -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "clickhouse-client -d pmm --query='SELECT * FROM metrics FORMAT Native'" \
        | borg create -v --stats --show-rc \
        $REPOSITORY::"$NAMEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
        || { alert "borg create failed: $?"; exit 1; }
}

function pmmgrafana {
  NAMEOFBACKUP="PMMGRAFANA"
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
  borg init -e none ${REPOSITORY}
  kubectl exec \
    -ti \
    -n ${NAMEOFNAMESPACE} ${POD} -- sh -c "supervisorctl stop grafana && cat /pmmdata/grafana/grafana.db && supervisorctl start grafana" \
        | borg create -v --stats --show-rc \
        $REPOSITORY::"$NAMEOFBACKUP-{now:%Y-%m-%d_%H:%M:%S}" - \
        || { alert "borg create failed: $?"; exit 1; }
}

pmmpostgres;
pmmclickhouse;
pmmgrafana;

borg prune -v --list $REPOSITORY \
      --keep-within=65d || alert "borg prune failed"


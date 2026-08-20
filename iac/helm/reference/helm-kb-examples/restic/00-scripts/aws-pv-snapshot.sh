#!/usr/bin/env bash
# Этот скрипт - способ ручного управления снепшотами pv в AWS

# Скрипт необходимо запускать на узле с Master-компонентами Kubernetes, чаще
# всего им является узел с именем kube-master или именем bastion
# На этом сервере должен быть установлен aws cli.
# В home-каталоге пользователя restic должен быть .aws с корректным конфигом и кредами.

# Принцип работы:
#   - определение нужного pvc
#   - определение по pvc его pv
#   - определение по pv соответствующий ему volume-id в AWS
#   - создание снепшота aws volume с заданным description
#   - получение списка снепшотов с указанным description и их ротация в соответствии с prune

# Пример использования в schedule:
# restic_run_on.sh 10.0.0.1 aws-pv-snapshot.sh '-n clickhouse-production -po ch-cluster-0 -volume data-storage -description ClickHouse-backup -k "2 month"'

################################################################################

# Путь до конфига kubectl
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
KUBECTL="/opt/deckhouse/bin/kubectl"

CUSTOMPRUNE_DEFAULT='2 month'

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${DESCRIPTION}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options n:p:v:d:k: --longoptions ,namespace:,pod:,volume:,description:,prune: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -n|--namespace)             NAMESPACE="${2}";   shift 2;;
    -p|--pod)                   POD="${2}";         shift 2;;
    -v|--volume)                VOLUME="${2}";      shift 2;;
    -d|--description)           DESCRIPTION="${2}"; shift 2;;
    -k|--prune)                 CUSTOMPRUNE="${2}"; shift 2;;
    *) break ;;
  esac
done

IFS=$'\n'

if test -z "${NAMESPACE}";
then
  printf "%s\n" "WARNING: namespace is not specified, used default value 'default'"
  NAMESPACE="default"
fi

if test -z "${POD}";
then
  printf "%s\n" "ERROR: pod is not specified!"
  exit 1
fi

if test -z "${VOLUME}";
then
  printf "%s\n" "ERROR: volume is not specified!"
  exit 1
fi

if test -z "${DESCRIPTION}";
then
  printf "%s\n" "ERROR: description is not specified!"
  exit 1
fi

PVC=`${KUBECTL} -n ${NAMESPACE} get po ${POD} -o json | \
     jq '.spec.volumes[] | select(.name == "'${VOLUME}'") | [.persistentVolumeClaim.claimName]' | \
     jq -cr '.[]'`
if test "${?}" -ne 0 || test "${PVC}" == "null" || test "${PVC}" == "";
then
  alert "Cannot get pvc for volume ${VOLUME} in ns ${NAMESPACE}, pod ${POD}"
  exit 1
fi

PV=`${KUBECTL} -n ${NAMESPACE} get pvc ${PVC} -o json | jq -r '.spec.volumeName'`
if test "${?}" -ne 0 || test "${PV}" == "null" || test "${PV}" == "";
then
  alert "Cannot get pv for pvc ${PVC} in ns ${NAMESPACE}"
  exit 1
fi

AWS_VOLUME=`${KUBECTL} get pv ${PV} -o json | jq -r '.spec.csi.volumeHandle'`
if test "${?}" -ne 0 || test "${AWS_VOLUME}" == "null" || test "${AWS_VOLUME}" == "";
then
  alert "Cannot get aws volume id for pv ${PV}"
  exit 1
fi

# Делаем снепшот
RESULT=`aws ec2 create-snapshot --volume-id ${AWS_VOLUME} --description "${DESCRIPTION}" 2>&1`
if test "${?}" -ne 0 || test "${AWS_VOLUME}" -ne "null";
then
  alert "Cannot create aws snapshot for volume id ${AWS_VOLUME}: ${RESULT}"
  exit 1
else
  echo ${RESULT}
fi

# Список снепшотов на удаление:
aws ec2 describe-snapshots --owner self --output json | \
    jq '.Snapshots[] | select(.Description == "'${DESCRIPTION}'" and .StartTime < "'$(date --date="-${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" +%Y-%m-%d)'") | [.Description, .StartTime, .SnapshotId]'

# Удаляем старые
aws ec2 describe-snapshots --owner self --output json | \
    jq '.Snapshots[] | select(.Description == "'${DESCRIPTION}'" and .StartTime < "'$(date --date="-${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" +%Y-%m-%d)'") | [.SnapshotId]' | \
    jq -cr '.[]' | \
    while read i; do \
        aws ec2 delete-snapshot --snapshot-id $i || { alert "Cannot delete aws snapshot ${i}"; exit 1; }; \
    done

exit 0

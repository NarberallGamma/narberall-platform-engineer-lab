#!/usr/bin/env bash

# Этот скрипт - способ бэкапа ETCD развернутого в кластере для patroni

# Скрипт необходимо запускать на узле с Master-компонентами Kubernetes, чаще
# всего им является узел с именем kube-master или именем bastion

# Принцип работы:
#   - получение списка подов ETCD в пространстве имен infra-patroni-etcd
#   - для каждого пода:
#     - для версии ETCDCTL_API равной 2:
#       - копирование каталога с данными ETCD во временный каталог ${BACKUP_DIR}
#     - для версии ETCDCTL_API равной 3:
#       - создание снимка данных ETCD с помощью 'etcdctl snapshot save'
#       - копирование снимка в файл etcd-snapshot во временный каталог ${BACKUP_DIR}
#     - сохранение версии ETCD в файле etcd-version.txt во временном каталоге ${BACKUP_DIR}
#   - резервное копирование каталога ${BACKUP_DIR} с помощью скрипта borg_backup_files.sh

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_etcd_patroni.sh

################################################################################

# Путь до конфига kubectl
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
KUBECTL="/opt/deckhouse/bin/kubectl"

BACKUP_DIR="/tmp/backup/etcd/"

# Регексп по которому грепать под etcd
ETCD_PODS_REGEX="patroni-etcd"
ETCD_SNAPSHOT_FILE="/tmp/etcd-backup"

ETCDCTL_API_MIN="2"
ETCDCTL_VERSION_PROBES="
etcdctl version
ETCDCTL_API=3 etcdctl version
"

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

get_etcdctl_version()
{
  printf "%s" "${1}" | sed --quiet "/etcdctl[ \t][ \t]*version/{s/.* \([0-9]\{1,\}\(\.[0-9]\{1,\}\)\{0,\}\).*/\1/;p}"
}

get_etcdctl_api_version_major()
{
  printf "%s" "${1}" | sed --quiet "/API[ \t][ \t]*version/{s/.* \(\([0-9]\{1,\}\)\(\.[0-9]\{1,\}\)\{0,\}\).*/\2/;p}"
}

get_env_var_value()
{
  printf "%s" "${1}" | sed --quiet "/${2}=/{s/${2}=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p}"
}

remove_repeating_vfs_divider()
{
  printf "%s" "${1}" | sed --quiet "s/\/\/*/\//g;p;"
}

PODS=""
ETCD_PODS=""
let ETCD_PODS_COUNT=0
ETCDCTL_API_MAX="${ETCDCTL_API_MIN}"

IFS=$'\n'

#Список подов с именем попадающим под ${ETCD_PODS_REGEX}
PODS="$( ${KUBECTL} -n infra-patroni-etcd get pods | grep "${ETCD_PODS_REGEX}" | awk '{print $1}' )"
if test -z "${PODS}";
then
  alert "Could not find etcd pods"
  exit 1
fi

echo "Find pods:
${PODS}"

#Список подов в которых присутствует etcdctl (определяется через получение версии etcdctl)
for pod in ${PODS};
do
  etcdctl_version=""

  for probe in ${ETCDCTL_VERSION_PROBES};
  do
    etcdctl_version="$( ${KUBECTL} -n infra-patroni-etcd exec "${pod}" -- sh -c "${probe}" )"
    etcdctl_version="$( get_etcdctl_version "${etcdctl_version}" )"
    if test -n "${etcdctl_version}";
    then
      break
    fi
  done

  if test -n "${etcdctl_version}";
  then
    if test -n "${ETCD_PODS}";
    then
      ETCD_PODS="${ETCD_PODS}"$'\n'"${pod}"
    else
      ETCD_PODS="${pod}"
    fi
    let ETCD_PODS_COUNT+=1
  fi
done

if test -z "${ETCD_PODS}" -o ${ETCD_PODS_COUNT} -eq 0;
then
  alert "Could not find valid etcd pods"
  exit 1
fi

echo "Valid pods:
${ETCD_PODS}"
echo "Valid pods count: ${ETCD_PODS_COUNT}"

#Определение максимально поддерживаемой версии ETCDCTL_API
for pod in ${ETCD_PODS};
do
  for probe in ${ETCDCTL_VERSION_PROBES};
  do
    etcdctl_api_current=""
    etcdctl_api_current="$( ${KUBECTL} -n infra-patroni-etcd exec "${pod}" -- sh -c "${probe}" )"
    etcdctl_api_current="$( get_etcdctl_api_version_major "${etcdctl_api_current}" )"
    if test -n "${etcdctl_api_current}";
    then
      if test "${etcdctl_api_current}" -gt "${ETCDCTL_API_MAX}";
      then
        ETCDCTL_API_MAX="${etcdctl_api_current}"
      fi
    fi
  done
done

echo "ETCDCTL_API: ${ETCDCTL_API_MAX}"

if test ! -d "${BACKUP_DIR}";
then
  mkdir -p "${BACKUP_DIR}"
fi
if test ! -d "${BACKUP_DIR}";
then
  alert "Could not create backup directory"
  exit 1
fi

TEMPLOG="$( mktemp )"
let errors_count=0
for pod in ${ETCD_PODS};
do
  echo "Work with pod '${pod}'"

  if test "${ETCDCTL_API_MAX}" == "3";
  then
    etcd_version_backup_file=""
    etcd_version_backup_file="$( remove_repeating_vfs_divider "${BACKUP_DIR}/etcd-version-${pod}.txt" )"

    etcd_snapshot_backup_file=""
    etcd_snapshot_backup_file="$( remove_repeating_vfs_divider "${BACKUP_DIR}/etcd-snapshot-${pod}" )"

    if test ${ETCD_PODS_COUNT} -eq 1;
    then
      etcd_version_backup_file="$( remove_repeating_vfs_divider "${BACKUP_DIR}/etcd-version.txt" )"
      etcd_snapshot_backup_file="$( remove_repeating_vfs_divider "${BACKUP_DIR}/etcd-snapshot" )"
    fi

    if test -z "${etcd_version_backup_file}";
    then
      alert "Could not determine etcd version backup file for pod '${pod}'"
      let errors_count+=1
      continue
    fi

    if test -z "${etcd_snapshot_backup_file}";
    then
      alert "Could not determine etcd snapshot backup file for pod '${pod}'"
      let errors_count+=1
      continue
    fi

    echo "Etcd version backup file:  ${etcd_version_backup_file}"
    echo "Etcd snapshot backup file: ${etcd_snapshot_backup_file}"

    ${KUBECTL} -n infra-patroni-etcd exec "${pod}" -- sh -c "ETCDCTL_API=3 etcdctl snapshot save ${ETCD_SNAPSHOT_FILE}" 2>>${TEMPLOG}
    kubectl_exit_status=${?}
    if test ${kubectl_exit_status} -ne 0;
    then
      alert "etcdctl snapshot save failed: ${kubectl_exit_status}"
      let errors_count+=1
      continue
    fi

    ${KUBECTL} -n infra-patroni-etcd exec "${pod}" -- sh -c "ETCDCTL_API=3 etcdctl endpoint status -w json" | jq '.[].Status.version' >> "${etcd_version_backup_file}"

    ${KUBECTL} cp --retries=-1 "infra-patroni-etcd/${pod}:${ETCD_SNAPSHOT_FILE}" "${etcd_snapshot_backup_file}" 2>>${TEMPLOG}
    kubectl_exit_status=${?}
    if test ${kubectl_exit_status} -ne 0;
    then
      alert "etcdctl snapshot copy failed: ${kubectl_exit_status}"
      let errors_count+=1
      continue
    fi
  fi

  if test "${ETCDCTL_API_MAX}" == "2";
  then
    pod_environment=""
    pod_environment="$( ${KUBECTL} -n infra-patroni-etcd exec "${pod}" -- sh -c "printenv" )"

    etcd_name_current=""
    etcd_name_current="$( get_env_var_value "${pod_environment}" "ETCD_NAME" )"

    etcd_data_dir_current=""
    etcd_data_dir_current="$( get_env_var_value "${pod_environment}" "ETCD_DATA_DIR" )"

    if test -n "${etcd_data_dir_current}" -a -n "${etcd_name_current}";
    then
      echo "ETCD_NAME of pod:     ${etcd_name_current}"
      echo "ETCD_DATA_DIR of pod: ${etcd_data_dir_current}"
    else
      alert "Could not get ETCD_DATA_DIR or ETCD_NAME for pod '${pod}'"
      let errors_count+=1
      continue
    fi

    etcd_pod_backup_dir=""
    etcd_pod_backup_dir="$( remove_repeating_vfs_divider "${BACKUP_DIR}/${etcd_name_current}" )"

    etcd_version_backup_file=""
    etcd_version_backup_file="$( remove_repeating_vfs_divider "${etcd_pod_backup_dir}/etcd-version.txt" )"

    if test -z "${etcd_pod_backup_dir}";
    then
      alert "Could not determine backup directory for pod '${pod}'"
      let errors_count+=1
      continue
    fi

    if test -z "${etcd_version_backup_file}";
    then
      alert "Could not determine etcd version backup file for pod '${pod}'"
      let errors_count+=1
      continue
    fi

    if test ! -d "${etcd_pod_backup_dir}";
    then
      mkdir "${etcd_pod_backup_dir}"
    fi
    if test ! -d "${etcd_pod_backup_dir}";
    then
      alert "Could not create backup directory for pod '${pod}'"
      let errors_count+=1
      continue
    fi

    echo "Etcd pod backup dir: ${etcd_pod_backup_dir}"
    echo "Etcd version backup file: ${etcd_version_backup_file}"

    ${KUBECTL} -n infra-patroni-etcd exec "${pod}" -- sh -c "etcdctl --version" >> "${etcd_version_backup_file}" 2>>${TEMPLOG}

    ${KUBECTL} cp --retries=-1 "infra-patroni-etcd/${pod}:${etcd_data_dir_current}" "${etcd_pod_backup_dir}" 2>>${TEMPLOG}
    kubectl_exit_status=${?}
    if test ${kubectl_exit_status} -ne 0;
    then
      alert "etcdctl directory copy failed: ${kubectl_exit_status}"
      let errors_count+=1
      continue
    fi
  fi
done

if test ${errors_count} -lt ${ETCD_PODS_COUNT};
then
  00-scripts/borg_backup_files.sh PATRONI-ETCD "${BACKUP_DIR}" --dont-ignore-missing-files 2>>${TEMPLOG}
else
  alert "etcd backup failed" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  exit 1
fi

rm -rf "${BACKUP_DIR}"

unlink "${TEMPLOG}"

exit 0
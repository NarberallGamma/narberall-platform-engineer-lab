#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа controlplane.
# Он включает в себя бэкап etcd-кластера и содержимого /etc/kubernetes.

# Скрипт необходимо запускать на узле с Master-компонентами Kubernetes

# Принцип работы:
#   - подключение к etcd кластера с помощью etcdctl с master-ноды
#       - сохранение версии etcd кластера в файле etcd-version.txt
#       - создание снимка данных ETCD с помощью 'etcdctl snapshot save'
#   - копирование содержимого /etc/kubernetes/* в ${BACKUP_DIR}/kubernetes
#   - резервное копирование каталога ${BACKUP_DIR} с помощью скрипта borg_backup_files.sh

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_kube_master.sh

################################################################################

ETCD_VER="3.5.0"
BACKUP_DIR="/tmp/backup/etcd/"

CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 7d'
CUSTOMPRUNE=$1
if [ -z "$CUSTOMPRUNE" ] ; then
  echo "<CUSTOMPRUNE> param will set to default ${CUSTOMPRUNE_DEFAULT}!" 1>&2
  CUSTOMPRUNE="${CUSTOMPRUNE_DEFAULT}"
fi

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  CLUSTER=${CLUSTER_NAME:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

install_etcd_client()
{
  echo "Install etcdctl version=${ETCD_VER} to /usr/local/bin/etcdctl ..."

  GOOGLE_URL=https://storage.googleapis.com/etcd
  GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
  DOWNLOAD_URL=${GOOGLE_URL}

  rm -f /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
  rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

  curl -L ${DOWNLOAD_URL}/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
  tar xzvf /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
  rm -f /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
  cp /tmp/etcd-download-test/etcdctl /usr/local/bin/
  rm -rf /tmp/etcd-download-test
}

remove_repeating_vfs_divider()
{
  printf "%s" "${1}" | sed --quiet "s/\/\/*/\//g;p;"
}

IFS=$'\n'

if [ $(/usr/local/bin/etcdctl version | grep ${ETCD_VER} | wc -l) = 0 ];
then
  install_etcd_client
fi

if [ ! -x /usr/local/bin/etcdctl ];
then
  alert "etcdctl is not found on the node"
  exit 1
fi

if test ! -d "${BACKUP_DIR}/kubernetes";
then
  mkdir -p "${BACKUP_DIR}/kubernetes"
fi
if test ! -d "${BACKUP_DIR}/kubernetes";
then
  alert "Could not create backup directory"
  exit 1
fi

etcd_version_backup_file="$( remove_repeating_vfs_divider "${BACKUP_DIR}/etcd-version.txt" )"
etcd_snapshot_backup_file="$( remove_repeating_vfs_divider "${BACKUP_DIR}/etcd-snapshot" )"

echo "Etcd version backup file:  ${etcd_version_backup_file}"
echo "Etcd snapshot backup file: ${etcd_snapshot_backup_file}"

etcd_cmd="ETCDCTL_API=3 /usr/local/bin/etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key"

printf "%s\n" "${etcd_cmd} endpoint status -w json | jq '.[].Status.version' > ${etcd_version_backup_file}" | bash

etcdctl_exit_status=${?}
if test ${etcdctl_exit_status} -ne 0;
then
  alert "etcdctl get version failed: ${etcdctl_exit_status}"
  exit 1
fi

printf "%s\n" "${etcd_cmd} snapshot save ${etcd_snapshot_backup_file}" | bash

etcdctl_exit_status=${?}
if test ${etcdctl_exit_status} -ne 0;
then
  alert "etcdctl snapshot save failed: ${etcdctl_exit_status}"
  exit 1
fi

# Copy kubernetes manifests and certificates
echo "Save /etc/kubernetes..."
cp -R /etc/kubernetes/* "${BACKUP_DIR}/kubernetes"
cp_exit_status=${?}
if test ${cp_exit_status} -ne 0;
then
  alert "/etc/kubernetes directory copy failed: ${cp_exit_status}"
  exit 1
fi

if test ${errors_count} -lt ${ETCD_PODS_COUNT};
then
  00-scripts/borg_backup_files.sh ETCD "${BACKUP_DIR}" --dont-ignore-missing-files --prune "${CUSTOMPRUNE}"
else
  alert "etcd has not been backed up"
  exit 1
fi

rm -rf "${BACKUP_DIR}"

exit 0

#!/usr/bin/env bash

# Primary backup method for ClickHouse running in a k8s pod

# Applicable when the clickhouse-server pod has Altinity clickhouse-backup installed
# https://github.com/Altinity/clickhouse-backup

# How it works:

#   - create a local backup in the pod with clickhouse-backup
#   - back up the created copy with restic_backup_kube_pvc.sh

# Supported options:
# -N|--job-name               - job name, restic repository tag. Required
# -C|--config                 - path to the backup config file. Optional
# -d|--data-dir               - path to the clickhouse-server data directory, see
#                               in '/etc/clickhouse-server/config.xml' via the <path> directive.

# -n|--namespace                 - cluster namespace. Required.
# -p|--pod                       - pod name prefix or full name to connect to. Required.
# -c|--container                 - Container name in the pod. Optional.
#    --context                   - Context in the kube config file. Optional.

# -k|--prune                  - retention-options string in
#                               restic format, e.g. '--keep-hourly 72 --keep-within 30d'
#                               Optional. When omitted,
#                               ${CUSTOMPRUNE_DEFAULT} is used
# -o|--options                - extra options for clickhouse-backup create

# Schedule examples:
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_clickhouse_kube.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" -n production -p chi-clickhouse-production-0-0-0 -c clickhouse'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_clickhouse_kube.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" -n production -p chi-clickhouse-production-0-0-0 -c clickhouse --config "/etc/clickhouse-backup/config.yml"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_clickhouse_kube.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" -n production -p chi-clickhouse-production-0-0-0 -c clickhouse --config "/etc/clickhouse-backup/config.yml" --options "--tables=my_db.table1,my_db.table_nam?,other_db.*"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_clickhouse_kube.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" -n production -p chi-clickhouse-production-0-0-0 -c clickhouse --config "/etc/clickhouse-backup/config.yml" --options "--tables=single_db.*" --prune "--keep-hourly 3 --keep-within 30d"'

# ClickHouse configuration files must also be backed up. A convenient command is:
# restic_run_on.sh 10.0.0.1 restic_backup_files.sh 'SYSTEM /etc,/var/spool/cron,/etc/backup-agent/config.d ^\/etc\/\.git$'

# Connection parameters for clickhouse-server belong in /etc/clickhouse-backup/config.yml
# Example contents:
# cat /etc/clickhouse-backup/config.yml
# general:
#   remote_storage: none
#   max_file_size: 1073741824
#   backups_to_keep_local: 0
#   log_level: info
#   allow_empty_backups: false
#   restore_schema_on_cluster: "your-cluster-name" # When restoring into a clustered ClickHouse
# clickhouse:
#   username: my-user-name
#   password: "my-pass-word"
#   host: localhost
#   port: 9000
#   secure: false
#   skip_verify: false
#   log_sql_queries: true
#   debug: false
#   config_dir:      "/etc/clickhouse-server"
#   ignore_not_exists_error_during_freeze: true
#   backup_mutations: true
# File mode must be 400.
# When the path differs, pass it via "--config" or the root user's $CLICKHOUSE_BACKUP_CONFIG environment variable.


# For queries to clickhouse-server, a dedicated user is preferred
# In '/etc/clickhouse-server/users.xml', the following can be added under <users>:
#        <backup>
#            <password_sha256_hex>e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855</password_sha256_hex>
#            <networks incl="networks" replace="replace">
#                <ip>::1</ip>
#                <ip>127.0.0.1</ip>
#            </networks>
#            <profile>default</profile>
#            <quota>default</quota>
#        </backup>
# A password hash for 'password_sha256_hex' can be produced with:
# printf "%s" "${PASSWORD}" | sha256sum | tr -d '-'

################################################################################

NAMEOFBACKUP_DEFAULT='CLICKHOUSE'
CONFIG_DEFAULT='/etc/clickhouse-backup/config.yml'
CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 65d'
ADDITIONAL_OPTIONS=""
EFFECTIVE_OPTIONS=""
NAMESPACE=""
POD_PREFIX=""
POD_CONTAINER=""
CONTEXT=""

# Path to the kubectl config
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
KUBECTL="/opt/deckhouse/bin/kubectl"

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options N:C:d:n:p:c:k:o: --longoptions ,job-name:,config:,data-dir:,namespace:,pod:,container:,prune:,options: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Exit"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -N|--job-name)                NAMEOFBACKUP="${2}";  shift 2;;
    -C|--config)                  CONFIG="${2}";        shift 2;;
    -d|--data-dir)                DATA_DIR="${2}";      shift 2;;
    -n|--namespace)               NAMESPACE="${2}";     shift 2;;
    -p|--pod)                     POD_PREFIX="${2}";    shift 2;;
    -c|--container)               POD_CONTAINER="${2}"; shift 2;;
       --context)                 CONTEXT="${2}";       shift 2;;
    -k|--prune)                   CUSTOMPRUNE="${2}";   shift 2;;
    -o|--options)
                                  if test -z "${ADDITIONAL_OPTIONS}";
                                  then
                                    ADDITIONAL_OPTIONS="'${2}'"
                                  else
                                    ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                  fi
                                  shift 2;;
    *) break ;;
  esac
done

IFS=$'\n'

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test -z "${CONFIG}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${CONFIG_DEFAULT}'"
  CONFIG="${CONFIG_DEFAULT}"
fi

if test -z "${DATA_DIR}";
then
  alert "clickhouse-server data directory is not defined"
  exit 1
fi

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

if test -z "${NAMESPACE}";
then
  alert "Backup job namespace is not defined. Backup will not be created"
  exit 1
fi

if test -z "${POD_PREFIX}";
then
  alert "Backup job pod name is not defined. Backup will not be created"
  exit 1
fi

if test "${CONTEXT}" != '';
then
  CONTEXT="--context=${CONTEXT}"
fi

if test "${POD_CONTAINER}" != '';
then
  POD_CONTAINER="-c ${POD_CONTAINER}"
fi

POD=$(${KUBECTL} ${CONTEXT} get pods -n ${NAMESPACE} | grep "${POD_PREFIX}" | awk '{print $1}' | head -n 1)
if test -z "${POD}";
then
  alert "Backup job can't find pod named like ${POD_PREFIX}*. Backup will not be created"
  exit 1
fi

TEMPLOG="$( mktemp )"

COMMAND_LINE=\
"${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- clickhouse-backup list | grep clickhouse-backup | grep local 2>>$TEMPLOG"

printf "%s\n" "Check backup dir:"
printf "%s\n" "${COMMAND_LINE}"
bash -c "${COMMAND_LINE}"

if [ $? -eq 0 ]; then
  alert "Backup folder is alrerady created, another backup has been started?" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  exit 1
fi

COMMAND_LINE=\
"${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- clickhouse-backup create ${EFFECTIVE_OPTIONS} --config=${CONFIG} clickhouse-backup 2>>$TEMPLOG"

printf "%s\n" "Create backup:"
printf "%s\n" "${COMMAND_LINE}"
bash -c "${COMMAND_LINE}"

if [ $? -ne 0 ]; then
   alert "Clickhouse-backup create clickhouse-backup failed." "$( tail -n 20 < "${TEMPLOG}" )"
   unlink "${TEMPLOG}"
   exit 1
fi

00-scripts/restic_backup_kube_pvc.sh "${NAMEOFBACKUP}" -q "${DATA_DIR}/backup/clickhouse-backup" -n "${NAMESPACE}" -p "${POD}" "${POD_CONTAINER}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

if [ $? -ne 0 ]; then
  alert "clickhouse-backup data directory backup failed"
  ${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- clickhouse-backup delete local clickhouse-backup 2>>$TEMPLOG
  ${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- clickhouse-backup clean 2>>$TEMPLOG
  exit 1
fi

COMMAND_LINE=\
"${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- sh -c 'clickhouse-backup delete local clickhouse-backup && clickhouse-backup clean' 2>>$TEMPLOG"

printf "%s\n" "Clean snapshot:"
printf "%s\n" "${COMMAND_LINE}"
bash -c "${COMMAND_LINE}"

if [ $? -ne 0 ]; then
   alert "Snapshot cleanup failed." "$( tail -n 20 < "${TEMPLOG}" )"
   unlink "${TEMPLOG}"
   exit 1
fi

unlink "${TEMPLOG}"

exit 0

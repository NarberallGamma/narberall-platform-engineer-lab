#!/usr/bin/env bash

# Backs up PVC contents of a pod

# How it works:
#   - create a tar backup of files and/or directories in the restic repository with
#     'restic backup'
#   - delete old backups in the restic repository with 'restic forget'

# Supported options:
# -q|--add-quoted                - path to a file or directory to
#                                  back up. The option may be repeated; the
#                                  backup will include all listed files and/or directories.
#                                  Listed paths are wrapped in single quotes — paths
#                                  with spaces are handled correctly, but wildcards
#                                  will not expand. Optional; when omitted, all PVCs in the pod are read
# -n|--namespace                 - cluster namespace. Required.
# -p|--pod                       - pod name prefix or full name to connect to. Required.
# -c|--container                 - Container name in the pod. Optional.
#    --context                   - Context in the kube config file. Optional.
# -t|--tar-options               - tar options for building the archive. Optional.
# -k|--prune                     - retention-options string in
#                                  restic format, e.g. '--keep-hourly 72 --keep-within 30d'
#                                  Optional. When omitted,
#                                  ${CUSTOMPRUNE_DEFAULT} is used

# Positional arguments:
# ${1} - job name, restic repository tag. Required

# Schedule examples:
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_kube_pvc.sh 'DATA  -q /app/data,/var -n production -p services-files-0 -c php --prune "--keep-hourly 3 --keep-within 30d"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_kube_pvc.sh 'DATA  -q /app/data,/var -n production -p services-files-0 -c php --tar-options "--exclude=temp-* --exclude=lost+found" --prune "--keep-hourly 3 --keep-within 30d"'

################################################################################

CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 65d'

# Path to the kubectl config
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
KUBECTL="/opt/deckhouse/bin/kubectl"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

################################################################################

DIRS_QUOTED=""
CUSTOMPRUNE=""
NAMESPACE=""
POD_PREFIX=""
POD_CONTAINER=""
CONTEXT=""
TAR_OPTIONS=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options q:n:p:c:t:k: --longoptions ,add-quoted:,namespace:,pod:,container:,context:,tar-options:,prune:,dont-ignore-missing-files -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -q|--add-quoted)
                                    if test -z "${DIRS_QUOTED}";
                                    then
                                      if test -n "${2}";
                                      then
                                        DIRS_QUOTED="'${2}'"
                                      fi
                                    else
                                      if test -n "${2}";
                                      then
                                        DIRS_QUOTED="${DIRS_QUOTED} '${2}'"
                                      fi
                                    fi

                                    shift 2;;

    -n|--namespace)                 NAMESPACE="${2}";                 shift 2;;
    -p|--pod)                       POD_PREFIX="${2}";                shift 2;;
    -c|--container)                 POD_CONTAINER="${2}";             shift 2;;
       --context)                   CONTEXT="${2}";                   shift 2;;
    -t|--tar-options)               TAR_OPTIONS="${2}";               shift 2;;
    -k|--prune)                     CUSTOMPRUNE="${2}";               shift 2;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

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

POD=$(${KUBECTL} ${CONTEXT} get pods -n ${NAMESPACE} | grep "${POD_PREFIX}" | awk '{print $1}' | head -n 1)
if test -z "${POD}";
then
  alert "Backup job can't find pod named like ${POD_PREFIX}*. Backup will not be created"
  exit 1
fi

if test -z "${DIRS_QUOTED}";
then
  DIRS=`${KUBECTL} ${CONTEXT} get pod -n ${NAMESPACE} ${POD} -o json | jq '.spec.containers[].volumeMounts[].mountPath' | grep -v "secrets/kubernetes.io/serviceaccount" | awk -F\" '{print $2}' | tr "\n" " "`
else
  DIRS="${DIRS_QUOTED}"
fi

if test "${POD_CONTAINER}" != '';
then
  POD_CONTAINER="-c ${POD_CONTAINER}"
fi

TEMPLOG="$( mktemp )"
TEMPLOGPRUNE="$( mktemp )"

restic init || echo "skip initialization."

COMMAND_LINE=\
"${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- tar ${TAR_OPTIONS} -cf - ${DIRS} 2>>$TEMPLOG"
RESTIC_COMMAND_LINE=\
"restic backup --verbose \
--tag ${NAMEOFBACKUP} \
--stdin --stdin-filename ${NAMEOFBACKUP}.tar"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${COMMAND_LINE} | ${RESTIC_COMMAND_LINE}"
bash -c "${COMMAND_LINE}" | bash -c "${RESTIC_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

# Print log to stdout for manual run and logger
cat "${TEMPLOG}"

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "${KUBECTL} exec failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "restic create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

unlink "${TEMPLOG}"

PRUNE_COMMAND_LINE=\
"restic forget --prune --tag '${NAMEOFBACKUP}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash &> "${TEMPLOGPRUNE}"

PRUNE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOGPRUNE}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "restic forget failed" "$( tail -n 20 < "${TEMPLOGPRUNE}" )"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

unlink "${TEMPLOGPRUNE}"

exit 0

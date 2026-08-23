#!/usr/bin/env bash

# Backup script for d8-stronghold

# How it works:
#   - create a Vault backup with 'vault operator raft snapshot save raft.snap'. The snapshot is taken from the active master, resolved via stronghold-active.d8-stronghold.svc.cluster.local
#   - restore from backup: 'vault operator raft snapshot restore -force raft.snap' + restore token values in the secret (after snapshot restore) in stronghold-keys. Keys in stronghold-keys do not change and can be copied into the panel.
# Safety:
#   - policy, configured in ui/stronghold/policies/acl
#     name: backup, path "/sys/storage/raft/snapshot" { capabilities = ["read"]}
#   - role, configured in Authentication Methods (kubernetes)
#     Name: backup
#     Alias name source: serviceaccount_name
#     Bound service account names: backup
#     Bound service account namespaces: backup
#     Generated Token's Policies: backup
# Supported options:
# -b|--name               - backup name
# -p|--path               - path to a directory in Vault
# -k|--prune              - retention-options string in
#                           Borg format, e.g. '--keep-hourly 72 --keep-within=30d'
# --skip-hostname-prefix  - omit from the Borg repository name
#                           the '$(hostname)-' prefix. Optional. Because commands run from the backup pod, it is better to always use it.
#
# Positional arguments:
# ${1} - job name, Borg repository name suffix. When omitted,
#        the name from ${NAMEOFBACKUP_DEFAULT} is used

# Schedule examples:
# /app/00-scripts/wrapper_ssh-agent.sh /app/00-scripts/borg_backup_vault_stronghold.sh '--name VAULT-PROD --path "kubernetes_local" --prune "--keep-hourly 3 --keep-within=30d" --skip-hostname-prefix'

################################################################################

source vars

NAMEOFBACKUP_DEFAULT="VAULT"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'
TYPEOFBACKUP="VAULT"

################################################################################

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

get_env_var_value()
{
  if test -n "${1}";
  then
    printenv | grep --fixed-regexp "${1}=" | sed --quiet "s/[^=]*=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p"
  fi
}

################################################################################

CUSTOMPRUNE=""
ERRLOG=`mktemp`

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options b:k:p: --longoptions ,name:,prune:,path:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -b|--name)                NAMEOFBACKUP="${2}"; shift 2;;
    -k|--prune)               CUSTOMPRUNE="${2}";  shift 2;;
    -p|--path)                VAULT_PATH="${2}";   shift 2;;
    --skip-hostname-prefix)   DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
then
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
else
  REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
fi

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

# Get JSON Web Token
JWT=$(cat /run/secrets/kubernetes.io/serviceaccount/token)

# Define active node adress

export VAULT_ADDR=https://stronghold-active.d8-stronghold.svc.cluster.local:8200
export VAULT_SKIP_VERIFY=true
# Get Vault Token

export VAULT_TOKEN=$(vault write auth/${VAULT_PATH}/login role=backup jwt="${JWT}" -format=json | jq -r .auth.client_token)

# Get Vault Snap

vault operator raft snapshot save raft.snap

# Create backup

printf "%s\n" "Create backup archive:"

borg create --show-rc --stats "${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}" raft.snap

CREATE_EXIT="${?}"

if test "${CREATE_EXIT}" -ne 0;
then
  alert "backup failed, exit code ${CREATE_EXIT}. Pruning of old archives skipped" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi

printf "%s\n" "Prune old backup archives:"
borg prune --show-rc --list ${REPOSITORY} ${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}} 2>>$ERRLOG


PRUNE_EXIT="${?}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "borg prune failed, exit code ${PRUNE_EXIT}" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi

rm $ERRLOG

exit 0

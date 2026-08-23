#!/usr/bin/env bash

# Primary backup method for Vault

# How it works:
#   - create a Vault backup with 'curl --header "X-Vault-Token: xxx" --request GET http://127.0.0.1:8200/v1/sys/storage/raft/snapshot -o raft.snap'
#   - restore from backup: 'curl --header "X-Vault-Token: yyy" --request POST --data-binary @raft.snap http://127.0.0.1:8200/v1/sys/storage/raft/snapshot'
# Safety:
#   - policy
#     tee snapshot_policy.hcl <<EOF
#     path "/sys/storage/raft/snapshot"
#     {
#       capabilities = ["read"]
#     }
#     EOF
#     VAULT_TOKEN=yyy vault policy write snapshot_agent snapshot_policy.hcl
#   - token
#     VAULT_TOKEN=yyy vault token create -policy=snapshot_agent -display-name=backup -no-default-policy=true
#
# Supported options:
# -h|--host               - Vault connection address. Optional
# -r|--port               - Vault connection port. Optional
# -s|--ssl                - Vault connection protocol. Optional
# -p|--password           - path to the token file used to connect to Vault,
#                           or the name of an environment variable that holds this password.
# -k|--prune              - retention-options string in
#                           Borg format, e.g. '--keep-hourly 72 --keep-within=30d'
#                           Optional. When omitted,
#                           ${CUSTOMPRUNE_DEFAULT} is used
# --skip-hostname-prefix  - omit from the Borg repository name
#                           the '$(hostname)-' prefix. Optional

# Positional arguments:
# ${1} - job name, Borg repository name suffix. When omitted,
#        the name from ${NAMEOFBACKUP_DEFAULT} is used

# Schedule examples:
# borg_run_on.sh 10.0.0.1 borg_backup_vault.sh
# borg_run_on.sh 10.0.0.1 borg_backup_vault.sh 'VAULT '
# borg_run_on.sh 10.0.0.1 borg_backup_vault.sh 'VAULT --host 127.0.0.1 --port 8200'
# borg_run_on.sh 10.0.0.1 borg_backup_vault.sh 'VAULT --prune "--keep-hourly 3 --keep-within=30d"'
# wrapper_ssh-agent.sh borg_backup_vault.sh 'VAULT --host 10.0.0.1'

# The value of [-p, --password] must not be
# the password itself. Pass one of:
#   - path to a password file. Owner must be 'root:root' and
#     mode must be '0400'
#   - the name of an environment variable that holds this password

################################################################################

source vars

NAMEOFBACKUP_DEFAULT="VAULT"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'
TYPEOFBACKUP="VAULT"
PASSWORD=""
ASSWORD_EVOLVED=""

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
HOST="127.0.0.1"
PORT="8200"
ERRLOG=`mktemp`

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options h:r:k:s:p: --longoptions ,host:,port:,prune:,ssl:,password:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -h|--host)                HOST="${2}";         shift 2;;
    -r|--port)                PORT="${2}";         shift 2;;
    -k|--prune)               CUSTOMPRUNE="${2}";  shift 2;;
    -p|--password)            PASSWORD="${2}";     shift 2;;
    -s|--ssl)                 USE_SSL="yes";       shift 1;;
    --skip-hostname-prefix)   DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"

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

if test "${USE_SSL}" == "yes";
then
  HTTP="https"
else
  HTTP="http"
fi

if test -n "${PASSWORD}";
then
  if test -f "${PASSWORD}";
  then
    PASSWORD_EVOLVED="$( head -n 1 "${PASSWORD}" )"
    PASSWORD_EVOLVED="$( trim_trailing_spaces "${PASSWORD_EVOLVED}" )"
  else
    PASSWORD_EVOLVED="$( get_env_var_value "${PASSWORD}" )"
  fi
fi

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

BACKUP_COMMAND_LINE=\
"curl --header \"X-Vault-Token: ${PASSWORD_EVOLVED}\" --request GET ${HTTP}://${HOST}:${PORT}/v1/sys/storage/raft/snapshot 2>>$ERRLOG"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"

printf "%s\n" "${BACKUP_COMMAND_LINE//$PASSWORD_EVOLVED/xxx} | ${BORG_COMMAND_LINE}"
bash -c "${BACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "backup failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "borg create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi


PRUNE_COMMAND_LINE=\
"borg prune --show-rc --list '${REPOSITORY}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}} 2>>$ERRLOG"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

PRUNE_EXIT="${?}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "borg prune failed, exit code ${PRUNE_EXIT}" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi

rm $ERRLOG

exit 0

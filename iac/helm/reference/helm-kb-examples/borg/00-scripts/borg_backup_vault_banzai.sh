#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа vault.banzaicloud.com

# Принцип работы:
#   - создание резервной копии vault с помощью команды 'curl --header "X-Vault-Token: xxx" --request GET http://127.0.0.1:8200/v1/sys/storage/raft/snapshot -o raft.snap'
#   - востановление из бэкапа 'curl --header "X-Vault-Token: yyy" --request POST --data-binary @raft.snap http://127.0.0.1:8200/v1/sys/storage/raft/snapshot'
# Безопастность:
#   - политика, настраивается в vault.banzaicloud.com operator cr
#  externalConfig:
#    policies:
#      - name: snapshot_agent
#        rules: |
#          path "/sys/storage/raft/snapshot"
#          {
#            capabilities = ["read"]
#          }
#    auth:
#      - type: kubernetes
#        path: kubernetes/production
#        config:
#          kubernetes_host: {{ .Values.auth.kubernetes.host.prod }}
#          token_reviewer_jwt: {{ .Values.auth.kubernetes.token_reviewer_jwt.prod }}
#          kubernetes_ca_cert: {{ .Values.auth.kubernetes.kubernetes_ca_cert | toJson }}
#        roles:
#          - name: backup
#            bound_service_account_names: ["backup"]
#            bound_service_account_namespaces: ["backup"]
#            policies: ["snapshot_agent"]
#            ttl: 1h
#    - SA для бэкапа
#    apiVersion: v1
#    kind: ServiceAccount
#    metadata:
#      name: backup
#
# Поддерживаемые опции:
# -b|--name               - имя бэкапа
# -h|--host               - адрес подключения к Vault.
# -n|--namespace          - vault namespace
# -r|--port               - порт подключения к Vault.
# -s|--ssl                - протокол подключения к Vault.
# -p|--path               - путь к каталогу в vault
# -k|--prune              - строка с опциями алгоритма сохранения резервных копий в
#                           формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                           Необязательный аргумент, без указания этой опции будет
#                           использовано значение ${CUSTOMPRUNE_DEFAULT}
# --skip-hostname-prefix  - позволяет исключить из имени Borg-репозитория
#                           префикс '$(hostname)-'. Необязательный аргумент

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория, без указания будет
#        использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}

# Примеры использования в schedule:
# wrapper_ssh-agent.sh borg_backup_vault_banzai.sh '--name VAULT-PROD --host vault-prod --namespace vault-prod --port 8200 --path "kubernetes/production" --ssl --skip-hostname-prefix'
# wrapper_ssh-agent.sh borg_backup_vault_banzai.sh '--name VAULT --host vault-prod --namespace vault-prod --path "kubernetes/dev" --prune "--keep-hourly 3 --keep-within=30d"''

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
PORT="8200"
ERRLOG=`mktemp`

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options b:h:n:r:k:p:s: --longoptions ,name:,host:,namespace:,port:,prune:,ssl:,path:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
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
    -h|--host)                HOST="${2}";         shift 2;;
    -n|--namespace)           NS="${2}";           shift 2;;
    -r|--port)                PORT="${2}";         shift 2;;
    -k|--prune)               CUSTOMPRUNE="${2}";  shift 2;;
    -p|--path)                VAULT_PATH="${2}";   shift 2;;
    -s|--ssl)                 USE_SSL="yes";       shift 1;;
    --skip-hostname-prefix)   DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

# Check params
params=( HOST NS VAULT_PATH )
for param in "${params[@]}"
do
    if test -z "${!param}"; then
        alert "Backup parameter ${param} is not defined"
        exit 1
    fi
done

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

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

# Get JSON Web Token
JWT=$(cat /run/secrets/kubernetes.io/serviceaccount/token)

# Get Vault Token
VAULT_TOKEN=$(curl -sk --request POST --data "{\"jwt\": \"${JWT}\", \"role\": \"backup\"}" \
                              "${HTTP}://${HOST}.${NS}.svc.cluster.local:${PORT}/v1/auth/${VAULT_PATH}/login" \
                              | jq .auth.client_token | sed 's/"//g')

# Get Leader
LEADER=$(curl -sk "${HTTP}://${HOST}.${NS}.svc.cluster.local:${PORT}/v1/sys/leader" \
         | jq .leader_cluster_address | awk -F ":" '{print $2}' | sed 's/\/\///')

BACKUP_COMMAND_LINE=\
"curl -sk --header \"X-Vault-Token: ${VAULT_TOKEN}\" --request GET ${HTTP}://${LEADER}.${NS}.svc.cluster.local:${PORT}/v1/sys/storage/raft/snapshot 2>>$ERRLOG"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"

printf "%s\n" "${BACKUP_COMMAND_LINE//$VAULT_TOKEN/xxx} | ${BORG_COMMAND_LINE}"
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

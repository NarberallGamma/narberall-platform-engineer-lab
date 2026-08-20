#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа Mongo

# Принцип работы:
#   - вызов mongodump с передачей дампа в stdout
#   - резервное копирование дампа с помощью restic с получением дампа из stdin

# Поддерживаемые опции:
# -h|--host                      - адрес подключения к Mongo. Обязательный аргумент,
#                                  для обратной совместимости осталась возможность
#                                  указать адрес подключения через второй (${2})
#                                  позиционный аргумент. Эта опция имеет более
#                                  высокий приоритет чем позиционный аргумент
# -r|--port                      - порт подключения к Mongo. Необязательный аргумент
# -u|--user                      - имя пользователя, используемого для подключения
#                                  к Mongo. Необязательный аргумент, без указания
#                                  этой опции будет использовано значение ${USER_DEFAULT}
# -p|--password                  - путь к файлу с паролем, используемым для
#                                  подключения к Mongo, или имя переменной
#                                  окружения, содержащей этот пароль. Необязательный аргумент
#    --authenticationDatabase    - имя базы данных, используемой для хранения параметров
#                                  аутентификации. Необязательный аргумент, без указания этой
#                                  опции будет использовано значение ${AUTH_DATABASE_DEFAULT}
# -a|--add-mongodump-option      - дополнительная опция которая будет передана
#                                  mongodump. Если опция mongodump имеет
#                                  значение, то его необходимо указать либо через
#                                  знак равенства ( = ) (возможно только для
#                                  длинных опций), либо через пробел, но в
#                                  этом случае опцию mongodump вместе с ее
#                                  значением необходимо поместить в двойные или
#                                  одинарные кавычки. Например:
#                                   - --add-mongodump-option --db=db1
#                                   - --add-mongodump-option '--db db1'
#                                   - --add-mongodump-option "--db db1"
#                                  Опция может быть указана несколько раз,
#                                  mongodump будут переданы все указанные опции.
#                                  Необязательный аргумент
# -k|--prune                     - строка с опциями алгоритма сохранения резервных копий в
#                                  формате программы restic, например '--keep-hourly 72 --keep-within 30d'
#                                  Необязательный аргумент, без указания этой опции будет
#                                  использовано значение ${CUSTOMPRUNE_DEFAULT}

# Позиционные аргументы:
# ${1} - имя задания, тег restic-репозитория. Обязательный аргумент
# ${2} - адрес подключения к Mongo. Обязательный аргумент, если НЕ использована
#        опция -h|--host

# Примеры использования в schedule:
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> 127.0.0.1'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1 --port 27017'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass"'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --user admin'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --user admin --authenticationDatabase admin'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --add-mongodump-option "--db test"'
# restic_run_on.sh 10.0.0.1 restic_backup_mongo_ext.sh 'MONGO --bucket <restic_bucket_from_values> --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --prune "--keep-hourly 3 --keep-within 2y5m7d3h"'
# /app/00-scripts/restic_backup_mongo_ext.sh MONGODB-PRODUCTION --bucket <restic_bucket_from_values> --host "rs0/mongo-mongodb-0.mongo-mongodb-headless.mongo-production.svc.cluster.local:27017,mongo-mongodb-1.mongo-mongodb-headless.mongo-production.svc.cluster.local:27017" --add-mongodump-option="--readPreference secondary"

# Запрещается указывать в качестве значения опции [-p, --password]
# непосредственно пароль. В качестве ее значения необходимо указать:
#   - путь к файлу с паролем. Владельцем этого файл должен быть 'root:root' и
#     для него должны быть установлены права '0400'
#   - имя переменной окружения, содержащей этот пароль

################################################################################

TYPEOFBACKUP='files'
USER_DEFAULT="admin"
AUTH_DATABASE_DEFAULT="admin"
CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 65d'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

trim_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^'*//;s/'*$//;p"
}

get_env_var_value()
{
  if test -n "${1}";
  then
    printenv | grep --fixed-regexp "${1}=" | sed --quiet "s/[^=]*=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p"
  fi
}

################################################################################
NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
AUTH_DATABASE=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""

PASSWORD_EVOLVED=""
EFFECTIVE_OPTIONS=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options b:h:r:u:p:a:k: --longoptions ,bucket:,host:,port:,user:,password:,authenticationDatabase:,add-mongodump-option:,prune: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -b|--bucket)                  BUCKET="${2}";            shift 2;;
    -h|--host)                    HOST="${2}";              shift 2;;
    -r|--port)                    PORT="${2}";              shift 2;;
    -u|--user)                    USER="${2}";              shift 2;;
    -p|--password)                PASSWORD="${2}";          shift 2;;
       --authenticationDatabase)  AUTH_DATABASE="${2}";     shift 2;;
    -a|--add-mongodump-option)
                                  if test -z "${ADDITIONAL_OPTIONS}";
                                  then
                                    ADDITIONAL_OPTIONS="'${2}'"
                                  else
                                    ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                  fi

                                  shift 2;;

    -k|--prune)                   CUSTOMPRUNE="${2}";                           shift 2;;
    *) break ;;
  esac
done

IFS=$'\n'

restic_repository_var="RESTIC_REPOSITORY_${BUCKET}"
restic_password_var="RESTIC_PASSWORD_${BUCKET}"
aws_access_key_id_var="AWS_ACCESS_KEY_ID_${BUCKET}"
aws_secret_access_key="AWS_SECRET_ACCESS_KEY_${BUCKET}"

export RESTIC_REPOSITORY=${!restic_repository_var}
export RESTIC_PASSWORD=${!restic_password_var}
export AWS_ACCESS_KEY_ID=${!aws_access_key_id_var}
export AWS_SECRET_ACCESS_KEY=${!aws_secret_access_key}

NAMEOFBACKUP="${2}"
if test -z "${HOST}";
then
  HOST="${3}"
fi

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${HOST}";
then
  alert "Mongo host is not defined. Backup will not be created"
  exit 1
fi

if test -z "${BUCKET}";
then
  alert "Mongo bucket is not defined. Backup will not be created"
  exit 1
fi

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --host '${HOST}'"

if test -n "${PORT}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --port '${PORT}'"
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

if test -n "${PASSWORD_EVOLVED}";
then
  if test -z "${USER}";
  then
    printf "%s\n" "WARNING: user name is not defined, used default value '${USER_DEFAULT}'"
    USER="${USER_DEFAULT}"
  fi

  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --username '${USER}'"
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --password '${PASSWORD_EVOLVED}'"

  if test -z "${AUTH_DATABASE}";
  then
    printf "%s\n" "WARNING: authentication database is not defined, used default value '${AUTH_DATABASE_DEFAULT}'"
    AUTH_DATABASE="${AUTH_DATABASE_DEFAULT}"
  fi

  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --authenticationDatabase '${AUTH_DATABASE}'"
fi

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --archive"

DUMPLOG="$( mktemp )"

printf "%s\n" "Initialize backup repository '${RESTIC_REPOSITORY}':"
restic init || echo "skip initialization."

MONGODUMP_COMMAND_LINE=\
"mongodump ${EFFECTIVE_OPTIONS} 2>${DUMPLOG}"

RESTIC_COMMAND_LINE=\
"restic backup --verbose --stdin --stdin-filename ${NAMEOFBACKUP}.dump \
--tag ${NAMEOFBACKUP}"

if test -z "${PASSWORD_EVOLVED}";
then
  printf "%s\n" "${MONGODUMP_COMMAND_LINE} | ${RESTIC_COMMAND_LINE}"
  bash -c "${MONGODUMP_COMMAND_LINE}" | bash -c "${RESTIC_COMMAND_LINE}"

  CREATE_EXIT=( "${PIPESTATUS[@]}" )

  if test "${CREATE_EXIT[0]}" -ne 0;
  then
    alert "mongodump failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "LOG: `cat ${DUMPLOG}`"
    rm ${DUMPLOG}
    exit 1
  fi

  if test "${CREATE_EXIT[1]}" -ne 0;
  then
    alert "restic backup failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
    rm ${DUMPLOG}
    exit 1
  fi
else
  printf "%s\n" "${MONGODUMP_COMMAND_LINE} | ${RESTIC_COMMAND_LINE}"
  printf "%s\n" "${PASSWORD_EVOLVED}" | bash -c "${MONGODUMP_COMMAND_LINE}" | bash -c "${RESTIC_COMMAND_LINE}"

  CREATE_EXIT=( "${PIPESTATUS[@]}" )

  if test "${CREATE_EXIT[1]}" -ne 0;
  then
    alert "mongodump failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "LOG: `cat ${DUMPLOG}`"
    rm ${DUMPLOG}
    exit 1
  fi

  if test "${CREATE_EXIT[2]}" -ne 0;
  then
    alert "restic backup failed, exit code ${CREATE_EXIT[2]}. Pruning of old archives skipped"
    rm ${DUMPLOG}
    exit 1
  fi
fi

rm ${DUMPLOG}

PRUNE_COMMAND_LINE=\
"restic forget --prune --tag '${NAMEOFBACKUP}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

PRUNE_EXIT="${?}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "restic prune failed, exit code ${PRUNE_EXIT}"
  exit 1
fi

exit 0

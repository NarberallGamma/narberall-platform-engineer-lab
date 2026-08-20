#!/usr/bin/env bash

# Этот скрипт - запасной способ бэкапа PostgreSQL

# Его можно применять если (должны выполняться все условия):
#   1. Версия PostgreSQL >= 8.3

# Помните, что восстановление данных из резервной копии, полученной с помощью pg_dump,
# занимает значительно больше времени чем при использовании pg_basebackup и
# на больших данных ( ~300 ГБ ) может занимать сутки

# Принцип работы:
#   - если создается резервная копия одной базы данных или не указана опция --one-archive:
#     - вызов pg_dump с передачей дампа в stdout
#     - резервное копирование дампа с помощью borg с получением дампа из stdin
#   - иначе:
#     - создание и сохранение дампов баз данных во временном каталоге ${TMP_DIR} с помощью pg_dump
#     - резервное копирование каталога ${TMP_DIR} с помощью скрипта borg_backup_files.sh

# Поддерживаемые опции:
# -h|--host                - адрес подключения к PostgreSQL. Необязательный аргумент
# -r|--port                - порт подключения к PostgreSQL. Необязательный аргумент
# -u|--user                - имя пользователя, используемого для подключения
#                            к PostgreSQL или запуска pg_dump. Необязательный
#                            аргумент, без указания этой опции будет использовано
#                            значение ${USER_DEFAULT}
# -p|--password            - путь к файлу с паролем, используемым для
#                            подключения к PostgreSQL, или имя переменной
#                            окружения, содержащей этот пароль. Необязательный аргумент
# -d|--db                  - имя базы данных которую необходимо бэкапить,
#                            опция может быть указана несколько раз, в
#                            резервную копию попадут все указанные базы. Если будет
#                            указано несколько баз данных, то резервная копия каждой
#                            из них будет помещена в отдельный borg-репозиторий, чье
#                            имя будет дополнено помимо имени задания также именем базы
#                            данных т.е. вместо $(hostname)-${NAMEOFBACKUP} будет
#                            использовано $(hostname)-${db}-${NAMEOFBACKUP}. Можно
#                            поместить все резервные копии баз в один архив с помощью
#                            опции --one-archive. Необходимо указать хотя бы одну базу
#                            или опцию --all-db
#    --all-db              - указание этой опции позволяет выполнить резервное
#                            копирование всех баз данных, обслуживаемых текущим
#                            экземпляром PostgreSQL. При ее использовании список
#                            баз будет сформирован из списка баз в PostgreSQL и
#                            далее резервное копирование будет выполнено по тому
#                            же алгоритму что и в случае ручного формирования
#                            списка баз с помощью опции -d|--db т.е. для каждой
#                            базы будет создан отдельный Borg-репозиторий. Смотри
#                            опции -d|--db и --one-archive
# -e|--exclude-db          - имя базы которую необходимо исключить из резервного
#                            копирования, опция может быть указана несколько раз, из
#                            резервной копии будут исключены все указанные базы
# -a|--add-pg_dump-option  - дополнительная опция которая будет передана
#                            pg_dump. Если опция pg_dump имеет
#                            значение, то его необходимо указать либо через
#                            знак равенства ( = ) (возможно только для
#                            длинных опций), либо через пробел, но в
#                            этом случае опцию pg_dump вместе с ее
#                            значением необходимо поместить в двойные или
#                            одинарные кавычки. Например:
#                             - --add-pg_dump-option --jobs=4
#                             - --add-pg_dump-option '--jobs 4'
#                             - --add-pg_dump-option "--jobs 4"
#                            Опция может быть указана несколько раз, pg_dump будут
#                            переданы все указанные опции. Необязательный аргумент
# -k|--prune               - строка с опциями алгоритма сохранения резервных копий в
#                            формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                            Необязательный аргумент, без указания этой опции будет
#                            использовано значение ${CUSTOMPRUNE_DEFAULT}
#    --do-su-under-user    - запустить pg_dump под пользователем, указанным
#                            опцией -u|--user или пользователем по умолчанию. Имеет
#                            смысл использовать в том случае, если по каким-либо
#                            причинам требуется вместо метода аутентификации 'trust'
#                            в pg_hba.conf использовать метод аутентификации 'peer'
#    --one-archive         - опция позволяет включить сохранение резервных копий
#                            разных баз в одном архиве. Для этого резервные копии баз
#                            сохраняются во временном каталоге. Помните, что в файловой
#                            системе должно быть достаточно свободного места для их хранения.
#                            В случае наличия в списке баз только одной базы, временный каталог
#                            использоваться не будет
#    --tmp-dir             - путь к временному каталогу в котором сохраняются
#                            резервные копии баз. Необязательный аргумент, без указания
#                            этой опции будет использовано значение ${TMP_DIR_DEFAULT}
#    --skip-hostname-prefix - позволяет исключить из имени Borg-репозитория
#                            префикс '$(hostname)-'. Необязательный аргумент

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория, без указания будет
#        использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}

# Запрещается указывать в качестве значения опции [-p, --password]
# непосредственно пароль. В качестве ее значения необходимо указать:
#   - путь к файлу с паролем. Владельцем этого файл должен быть 'root:root' и
#     для него должны быть установлены права '0400'
#   - имя переменной окружения, содержащей этот пароль

# Пример использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh '--db db1'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres --do-su-under-user'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres --do-su-under-user -a "--table main" -a --blobs'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres --do-su-under-user -a "--table main" -a --blobs --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --host 127.0.0.1 --user pg_super --password "/etc/backup/pg-pass"'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --all-db --exclude-db "postgres" --user postgres --do-su-under-user'
# wrapper_ssh-agent.sh  borg_backup_pg_dump.sh 'HOST-PGDUMP --db db1 --db db2 --host 192.168.0.10 --user pg_super --password "/etc/backup/pg-pass"'

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='PGDUMP'
TYPEOFBACKUP='PGDUMP'
USER_DEFAULT="postgres"
DEFAULT_DATABASE="postgres"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'
TMP_DIR_DEFAULT="/tmp/pg_dump"

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

DESIRED_OPTIONS="
'--format=c'
'--compress=0'
"

PROTECTED_DIRS='
/
/etc
/root
/home
/var
'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
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

trim_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^'*//;s/'*$//;p"
}

add_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^/'/;s/$/'/;p"
}

get_env_var_value()
{
  if test -n "${1}";
  then
    printenv | grep --fixed-regexp "${1}=" | sed --quiet "s/[^=]*=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p"
  fi
}

# Корректно сравнивает пути VFS
# uncertain - неопределенное состояние, один из аргументов не VFS-путь
# equal     - пути равны
# not_equal - пути не равны
# ${1} - one path
# ${2} - two path
compare_vfs_paths()
{
  local one_path_normalized
  local two_path_normalized
  local one_vfs_dividers_string
  local two_vfs_dividers_string

  if test -z "${1}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  if test -z "${2}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  one_path_normalized="$( printf "%s" "${1}/" | sed --quiet "s/\/\/*/\//g;p;" )"
  two_path_normalized="$( printf "%s" "${2}/" | sed --quiet "s/\/\/*/\//g;p;" )"

  one_vfs_dividers_string="$( printf "%s" "${one_path_normalized}" | sed --quiet "s/\/[^\/]\{1,\}/\//g;p;" )"
  two_vfs_dividers_string="$( printf "%s" "${two_path_normalized}" | sed --quiet "s/\/[^\/]\{1,\}/\//g;p;" )"

  if test "$( printf "%s" "${one_vfs_dividers_string}" | sed --quiet "s/[^\/]//g;p;" )" != "${one_vfs_dividers_string}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  if test "$( printf "%s" "${two_vfs_dividers_string}" | sed --quiet "s/[^\/]//g;p;" )" != "${two_vfs_dividers_string}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  if test "${one_path_normalized}" == "${two_path_normalized}";
  then
    printf "%s" "equal"
  else
    printf "%s" "not_equal"
  fi

  return 0
}

# Определяет уровень (глубину) переданного пути относительно корня VFS
# 0 - не VFS путь
# 1 - '/'
# 2 - '/etc', '/root', '/var' и т.п.
# ${1} - path
get_vfs_path_level()
{
  local path_normalized
  local vfs_dividers_string

  if test -z "${1}";
  then
    printf "%s" "0"
    return 1
  fi

  path_normalized="$( printf "%s" "${1}/" | sed --quiet "s/\/\/*/\//g;p;" )"
  vfs_dividers_string="$( printf "%s" "${path_normalized}" | sed --quiet "s/\/[^\/]\{1,\}/\//g;p;" )"

  if test "$( printf "%s" "${vfs_dividers_string}" | sed --quiet "s/[^\/]//g;p;" )" != "${vfs_dividers_string}";
  then
    printf "%s" "0"
    return 1
  fi

  printf "%s" "${vfs_dividers_string}" | wc -m

  return 0
}

################################################################################

NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
DBS=""
DBS_COUNT=""
ALL_DB=""
DBS_EXCLUDE=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""
DO_SU_UNDER_USER=""
ONE_ARCHIVE=""
TMP_DIR=""

PASSWORD_EVOLVED=""
REPOSITORY=""
EFFECTIVE_OPTIONS=""
PSQL_OPTIONS=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options h:r:u:p:d:e:a:k: --longoptions ,host:,port:,user:,password:,db:,all-db,exclude-db:,add-pg_dump-option:,prune:,do-su-under-user,one-archive,tmp-dir:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
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
    -u|--user)                USER="${2}";         shift 2;;
    -p|--password)            PASSWORD="${2}";     shift 2;;
    -d|--db)
                              if test -z "${DBS}";
                              then
                                DBS="'${2}'"
                              else
                                DBS="${DBS}"$'\n'"'${2}'"
                              fi

                              shift 2;;

       --all-db)              ALL_DB="yes";        shift 1;;

    -e|--exclude-db)
                              if test -z "${DBS_EXCLUDE}";
                              then
                                DBS_EXCLUDE="'${2}'"
                              else
                                DBS_EXCLUDE="${DBS_EXCLUDE}"$'\n'"'${2}'"
                              fi

                              shift 2;;

    -a|--add-pg_dump-option)
                              if test -z "${ADDITIONAL_OPTIONS}";
                              then
                                ADDITIONAL_OPTIONS="'${2}'"
                              else
                                ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                              fi

                              shift 2;;

    -k|--prune)               CUSTOMPRUNE="${2}";     shift 2;;
       --do-su-under-user)    DO_SU_UNDER_USER="yes"; shift 1;;
       --one-archive)         ONE_ARCHIVE="yes";      shift 1;;
       --tmp-dir)             TMP_DIR="${2}";         shift 2;;
       --skip-hostname-prefix)    DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

IFS=$'\n'

NAMEOFBACKUP="${2}"

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test -n "${HOST}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --host='${HOST}'"
  PSQL_OPTIONS="${PSQL_OPTIONS} --host '${HOST}'"
fi

if test -n "${PORT}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --port='${PORT}'"
  PSQL_OPTIONS="${PSQL_OPTIONS} --port '${PORT}'"
fi

if test -z "${USER}";
then
  printf "%s\n" "WARNING: user name is not defined, used default value '${USER_DEFAULT}'"
  USER="${USER_DEFAULT}"
fi

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --username='${USER}'"
PSQL_OPTIONS="${PSQL_OPTIONS} --username '${USER}'"

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

for option in ${DESIRED_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

if test "${ALL_DB}" == "yes";
then
  if test -n "${DBS}";
  then
    printf "%s\n" "WARNING: options '-d|--db' and '--all-db' specified at the same time. Preference will be given to the option '--all-db'"
  fi

  PSQL_COMMAND_LINE="psql ${PSQL_OPTIONS} --no-align --tuples-only --command 'SELECT datname FROM pg_database WHERE datistemplate = false;' '${DEFAULT_DATABASE}'"

  if test -z "${PASSWORD_EVOLVED}";
  then
    if test "${DO_SU_UNDER_USER}" == "yes";
    then
      DBS="$( add_trailing_single_quotes "$( su - "${USER}" -c "${PSQL_COMMAND_LINE}" )" )"
    else
      DBS="$( add_trailing_single_quotes "$( bash -c "${PSQL_COMMAND_LINE}" )" )"
    fi
  else
    if test "${DO_SU_UNDER_USER}" == "yes";
    then
      DBS="$( add_trailing_single_quotes "$( su - "${USER}" -c "PGPASSWORD=${PASSWORD_EVOLVED} ${PSQL_COMMAND_LINE}" )" )"
    else
      DBS="$( add_trailing_single_quotes "$( PGPASSWORD="${PASSWORD_EVOLVED}" bash -c "${PSQL_COMMAND_LINE}" )" )"
    fi
  fi
fi

DBS="$( printf "%s" "${DBS}" | sort | uniq )"

for db_exclude in ${DBS_EXCLUDE};
do
  DBS="$( printf "%s" "${DBS}" | grep --fixed-regexp --invert-match "${db_exclude}" )"
done

DBS_COUNT="$( printf "%s" "${DBS}" | grep ".*" --count )"

if test "${DBS_COUNT}" -lt 1;
then
  alert "Databases list is empty - nothing to backup. Backup will not be created"
  exit 1
fi

if test "${ONE_ARCHIVE}" == "yes" -a "${DBS_COUNT}" -gt 1;
then
  printf "%s\n" "Is used the mode of saving databases copies in the temporary directory"

  if test -z "${TMP_DIR}";
  then
    printf "%s\n" "WARNING: temporary directory is not defined, used default value '${TMP_DIR_DEFAULT}'"
    TMP_DIR="${TMP_DIR_DEFAULT}"
  fi

  for dir in ${PROTECTED_DIRS};
  do
  if test "$( compare_vfs_paths "${TMP_DIR}" "${dir}" )" == "equal" -o "$( compare_vfs_paths "${TMP_DIR}" "${dir}" )" == "uncertain";
    then
      alert "Directory '${dir}' is protected and cannot be specified as the temporary directory. Backup will not be created"
      exit 1
    fi
  done

  if test "$( get_vfs_path_level "${TMP_DIR}" )" -le "2";
  then
    alert "Temporary directory level cannot be less that 2. Backup will not be created"
    exit 1
  fi

  if test -d "${TMP_DIR}";
  then
    printf "%s\n" "Remove temporary directory '${TMP_DIR}':"
    rm -rf "${TMP_DIR}"
  fi

  if test ! -d "${TMP_DIR}";
  then
    printf "%s\n" "Create temporary directory '${TMP_DIR}':"
    mkdir -p "${TMP_DIR}"
    if test ! -d "${TMP_DIR}";
    then
      alert "Cannot create temporary directory '${TMP_DIR}'. Backup will not be created"
      exit 1
    fi
  fi

  if test "${DO_SU_UNDER_USER}" == "yes";
  then
    printf "%s\n" "Change owner for temporary directory to '${USER}':"
    chown "${USER}" "${TMP_DIR}"
    if test "${?}" -ne 0;
    then
      alert "Cannot change owner for temporary directory '${TMP_DIR}' to '${USER}'. Backup will not be created"
      exit 1
    fi
  fi

  printf "%s\n" "Create backup in temporary directory:"

  let backup_errors_count=0
  current_error=""
  errors_list=""

  for db in ${DBS};
  do
    PG_DUMP_COMMAND_LINE="pg_dump ${EFFECTIVE_OPTIONS} --file='${TMP_DIR}/$( trim_trailing_single_quotes "${db}" )' ${db}"

    if test -z "${PASSWORD_EVOLVED}";
    then
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\""
        su - "${USER}" -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE}"
        bash -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      fi
    else
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\""
        su - "${USER}" -c "PGPASSWORD=${PASSWORD_EVOLVED} ${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE}"
        PGPASSWORD="${PASSWORD_EVOLVED}" bash -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      fi
    fi

    if test "${PG_DUMP_EXIT}" -ne 0;
    then
      current_error="pg_dump failed for database ${db}"

      if test -z "${errors_list}";
      then
        errors_list="${current_error}"
      else
        errors_list="${errors_list}"$'\n'"${current_error}"
      fi

      let backup_errors_count+=1
      continue
    fi
  done

  if test "${backup_errors_count}" -eq "${DBS_COUNT}";
  then
    alert "Errors found during backup, see description for view error list. Backup will not be created" "${errors_list}"
    rm -rf "${TMP_DIR}"
    exit 1
  fi

  if test "${backup_errors_count}" -ne 0;
  then
    alert "Errors found during backup, see description for view error list. An incomplete backup will be created" "${errors_list}"
  fi

  printf "%s\n" "Create backup archive from temporary directory:"
  if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
  then
    TMP_OPTIONS="--skip-hostname-prefix"
  else
    TMP_OPTIONS=""
  fi
  00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" --add-quoted "${TMP_DIR}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --prefix "${TYPEOFBACKUP}" --dont-ignore-missing-files ${TMP_OPTIONS}

  if test "${?}" -ne 0;
  then
    alert "Cannot backup temporary directory '${TMP_DIR}'"
    rm -rf "${TMP_DIR}"
    exit 1
  fi

  printf "%s\n" "Remove temporary directory '${TMP_DIR}':"
  rm -rf "${TMP_DIR}"

  if test "${backup_errors_count}" -ne 0;
  then
    exit 1
  fi
else
  printf "%s\n" "Is used the pipe-mode"

  let backup_errors_count=0
  current_error=""
  errors_list=""

  for db in ${DBS};
  do
    if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
    then
      REPOSITORY="${BORG_SERVER}:"
    else
      REPOSITORY="${BORG_SERVER}:$(hostname)-"
    fi

    if test "${DBS_COUNT}" -gt 1;
    then
      REPOSITORY="${REPOSITORY}$( trim_trailing_single_quotes "${db}" )-${NAMEOFBACKUP}"
    else
      REPOSITORY="${REPOSITORY}${NAMEOFBACKUP}"
    fi

    printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
    borg init -e none "${REPOSITORY}"

    PG_DUMP_COMMAND_LINE="pg_dump ${EFFECTIVE_OPTIONS} ${db}"

    BORG_COMMAND_LINE="borg create --show-rc --stats '${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

    printf "%s\n" "Create backup archive:"

    if test -z "${PASSWORD_EVOLVED}";
    then
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\" | ${BORG_COMMAND_LINE}"
        su - "${USER}" -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
        bash -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      fi

      CREATE_EXIT=( "${PIPESTATUS[@]}" )

      if test "${CREATE_EXIT[0]}" -ne 0;
      then
        current_error="pg_dump failed for database ${db}, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"

        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi

        let backup_errors_count+=1
        continue
      fi

      if test "${CREATE_EXIT[1]}" -ne 0;
      then
        current_error="borg create failed for database ${db}, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"

        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi

        let backup_errors_count+=1
        continue
      fi
    else
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\" | ${BORG_COMMAND_LINE}"
        su - "${USER}" -c "PGPASSWORD=${PASSWORD_EVOLVED} ${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
        PGPASSWORD="${PASSWORD_EVOLVED}" bash -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      fi

      CREATE_EXIT=( "${PIPESTATUS[@]}" )

      if test "${CREATE_EXIT[1]}" -ne 0;
      then
        current_error="pg_dump failed for database ${db}, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"

        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi

        let backup_errors_count+=1
        continue
      fi
      if [ ! -z "${CREATE_EXIT[2]}" ] && [ "${CREATE_EXIT[2]}" -ne 0 ];
      then
        current_error="borg create failed for database ${db}, exit code ${CREATE_EXIT[2]}. Pruning of old archives skipped"

        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi

        let backup_errors_count+=1
        continue
      fi
    fi

    PRUNE_COMMAND_LINE="borg prune --show-rc --list '${REPOSITORY}' ${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

    printf "%s\n" "Prune old backup archives:"
    printf "%s\n" "${PRUNE_COMMAND_LINE}"
    printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

    PRUNE_EXIT="${?}"

    if test "${PRUNE_EXIT}" -ne 0;
    then
      current_error="borg prune failed for database ${db}, exit code ${PRUNE_EXIT}"

      if test -z "${errors_list}";
      then
        errors_list="${current_error}"
      else
        errors_list="${errors_list}"$'\n'"${current_error}"
      fi

      let backup_errors_count+=1
      continue
    fi
  done

  if test "${backup_errors_count}" -eq "${DBS_COUNT}";
  then
    alert "Errors found during backup, see description for view error list. Backup will not be created or be empty" "${errors_list}"
    exit 1
  fi

  if test "${backup_errors_count}" -ne 0;
  then
    alert "Errors found during backup, see description for view error list. An incomplete backup will be created" "${errors_list}"
    exit 1
  fi
fi

exit 0
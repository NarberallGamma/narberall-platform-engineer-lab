#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа clickhouse

# Его можно применять если (должны выполняться все условия):
#   1. для работы с таблицами во всех целевых базах данных используются движки, 
#      перечисленные в ${SUPPORTED_ENGINES}
#   2. clickhouse-server должен быть запущен на том же узле на котором будет 
#      запущен этот скрипт

# Принцип работы:
#   - создание локальных копий разделов таблиц с помощью запроса 
#    'ALTER TABLE ... FREEZE PARTITION ...' в подкаталоге 'shadow' каталога с 
#     данными clickhouse-server ( чаще всего каталог с данными - это каталог /var/lib/clickhouse) 
#   - резервное копирование каталога /var/lib/clickhouse/shadow/ с помощью скрипта borg_backup_files.sh

# Поддерживаемые опции:
# -n|--job-name               - имя задания, суффикс имени Borg-репозитория. Обязательный аргумент
# -h|--host                   - адреса подключения к clickhouse-server. Необязательный аргумент
# -r|--port                   - порт подключения к clickhouse-server. Необязательный аргумент
# -u|--user                   - имя пользователя, используемого для подключения к clickhouse-server
# -p|--password               - путь к файлу с паролем пользователя. Необязательный аргумент
# -t|--data-dir               - путь к каталогу с данными clickhouse-server, можно узнать 
#                               в файле '/etc/clickhouse-server/config.xml' по директиве <path>. 
#                               Обязательный аргумент
# -k|--prune                  - строка с опциями алгоритма сохранения резервных копий в 
#                               формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                               Необязательный аргумент, без указания этой опции будет 
#                               использовано значение ${CUSTOMPRUNE_DEFAULT}
# -d|--db                     - имя целевой базы данных, можно указать несколько раз, 
#                               резервному копированию будут подвержены все указанные базы. 
#                               Необязательный аргумент, без указания этой опции резервному 
#                               копированию будут подвержены все базы данных
#    --only-supported-engines - при указании, в список таблиц подлежащих 
#                               резервному копированию попадут только таблицы 
#                               для работы с которыми используются движки, 
#                               перечисленные в ${SUPPORTED_ENGINES}. Необязательный аргумент. 
#                               ПОМНИТЕ, что при использовании этой опции резервная копия может 
#                               оказаться неполной, но алертов об этом вы не получите
#    --debug                  - при указании будет выведен список таблиц и partitions 
#                               подлежащих резервному копированию. Необязательный аргумент

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CLCKHS" --data-dir "/var/lib/clickhouse/"'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CLCKHS" --data-dir "/var/lib/clickhouse/" --host "127.0.0.1"'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CLCKHS" --data-dir "/var/lib/clickhouse/" --host "127.0.0.1" --user "backup" --password "/etc/backup/clickhouse-pass"'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CLCKHS" --data-dir "/var/lib/clickhouse/" --host "127.0.0.1" --user "backup" --password "/etc/backup/clickhouse-pass" --only-supported-engines'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CLCKHS" --data-dir "/var/lib/clickhouse/" --host "127.0.0.1" --user "backup" --password "/etc/backup/clickhouse-pass" --only-supported-engines --prune "--keep-hourly 3 --keep-within=30d"'

# Запрещается указывать в качестве значения опции [-p, --password] 
# непосредственно пароль. В качестве ее значения необходимо указать путь к 
# файлу с паролем. Владельцем этого файл должен быть 'root:root' и для него 
# должны быть установлены права '0400'

# Для выполнения запросов к clickhouse-server желательно создать отдельного пользователя
# Для этого в файле '/etc/clickhouse-server/users.xml' можно в секции <users> вписать следующий текст:
#        <backup>
#            <password_sha256_hex>e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855</password_sha256_hex>
#            <networks incl="networks" replace="replace">
#                <ip>::1</ip>
#                <ip>127.0.0.1</ip>
#            </networks>
#            <profile>default</profile>
#            <quota>default</quota>
#        </backup>
# Хэш пароля для директивы 'password_sha256_hex' можно получить следующей командой:
# printf "%s" "${PASSWORD}" | sha256sum | tr -d '-'

################################################################################

NAMEOFBACKUP_DEFAULT='clickhouse'
SHADOW_DIR_NAME='shadow'
METADATA_DIR_NAME='metadata'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

DBS_EXCLUDE_GLOBAL='
system'

SUPPORTED_ENGINES='
%MergeTree
Merge
Distributed
'

################################################################################

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP:-NAMEOFBACKUP_DEFAULT}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

# Удаляет все вхождения строки из текста
# ${1} - input text
# ${2} - match string
delete_string_exactly()
{
  local out_text
  out_text=""
  
  for string in ${1};
  do
    if test "${string}" != "${2}";
    then
      if test -z "${out_text}";
      then
        out_text="${string}"
      else
        out_text="${out_text}"$'\n'"${string}"
      fi
    fi
  done
  
  printf "%s" "${out_text}"
}

#Удаляет избыточные символы '/' в строке
# ${1} - string
remove_repeating_vfs_divider()
{
  printf "%s" "${1}" | sed --quiet "s/\/\/*/\//g;p;"
}

# Корректно сравнивает пути VFS
# ${1} - one path
# ${2} - two path
compare_vfs_paths()
{
  local one_path_normalized
  local two_path_normalized
  
  one_path_normalized="$( printf "%s" "${1}/" | sed --quiet "s/\/\/*/\//g;p;" )"
  two_path_normalized="$( printf "%s" "${2}/" | sed --quiet "s/\/\/*/\//g;p;" )"
  
  if test "${one_path_normalized}" == "${two_path_normalized}";
  then
    printf "%s" "equal"
  else
    printf "%s" "not_equal"
  fi
}

################################################################################

NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
DATA_DIR=""
DBS_INCLUDE=""
CUSTOMPRUNE=""
ONLY_SUPPORTED_ENGINES="no"
DEBUG="no"

CONNECTION_STRING=""
DBS_EXIST=""
DBS=""
SHADOW_DIR=""
BACKUP_TARGET_STRING=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options n:h:r:u:p:t:k:d: --longoptions ,job-name:,host:,port:,user:,password:,data-dir:,prune:,db:,only-supported-engines,debug -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Exit"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -n|--job-name)                NAMEOFBACKUP="${2}"; shift 2;;
    -h|--host)                    HOST="${2}";         shift 2;;
    -r|--port)                    PORT="${2}";         shift 2;;
    -u|--user)                    USER="${2}";         shift 2;;
    -p|--password)                PASSWORD="${2}";     shift 2;;
    -t|--data-dir)                DATA_DIR="${2}";     shift 2;;
    -k|--prune)                   CUSTOMPRUNE="${2}";  shift 2;;
    -d|--db)                      
                                  if test -z "${DBS_INCLUDE}";
                                  then
                                    DBS_INCLUDE="${2}"
                                  else
                                    DBS_INCLUDE="${DBS_INCLUDE}"$'\n'"${2}"
                                  fi
                                  
                                  shift 2;;
                                  
       --only-supported-engines)  ONLY_SUPPORTED_ENGINES="yes";  shift 1;;
       --debug)                   DEBUG="yes";                   shift 1;;
    *) break ;;
  esac
done

IFS=$'\n'

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test -z "${DATA_DIR}";
then
  alert "clickhouse-server data directory is not defined"
  exit 1
fi
if test ! -d "${DATA_DIR}";
then
  alert "clickhouse-server data directory does not exist"
  exit 1
fi
if test ! -r "${DATA_DIR}";
then
  alert "clickhouse-server data directory does not readable by this user" 
  exit 1
fi
if test ! -x "${DATA_DIR}";
then
  alert "clickhouse-server data data directory does not executable by this user"
  exit 1
fi

if test -n "${HOST}";
then
  CONNECTION_STRING="${CONNECTION_STRING} --host '${HOST}'"
fi

if test -n "${PORT}";
then
  CONNECTION_STRING="${CONNECTION_STRING} --port '${PORT}'"
fi

if test -n "${USER}";
then
  CONNECTION_STRING="${CONNECTION_STRING} --user '${USER}'"
fi

if test -f "${PASSWORD}";
then
  PASSWORD="$( cat "${PASSWORD}" )"
fi

if test -n "${PASSWORD}";
then
  CONNECTION_STRING="${CONNECTION_STRING} --password '${PASSWORD}'"
fi

DBS_INCLUDE="$( printf "%s" "${DBS_INCLUDE}" | sort | uniq )"

DBS_EXIST="$( echo "clickhouse-client ${CONNECTION_STRING} --query=\"SHOW DATABASES;\"" | bash )"
if test -z "${DBS_EXIST}" -o "${?}" -ne 0;
then
  alert "List of databases on server is empty"
  exit 1
fi

if test -z "${DBS_INCLUDE}";
then
  DBS="${DBS_EXIST}"
  
  printf "%s\n%s\n" "Find databases:" "${DBS}"
  
  for db_exclude in ${DBS_EXCLUDE_GLOBAL};
  do
    DBS="$( delete_string_exactly "${DBS}" "${db_exclude}" )"
  done
  
  if test -z "${DBS}";
  then
    alert "List of databases after global exclusion is empty"
    exit 1
  fi
  
  printf "%s\n%s\n" "List of databases after global exclusion:" "${DBS}"
else
  for db_include in ${DBS_INCLUDE};
  do
    let db_include_exist=0
    
    for db_exist in ${DBS_EXIST};
    do
      if test "${db_include}" == "${db_exist}";
      then
        let db_include_exist+=1
        break
      fi
    done
    
    if test "${db_include_exist}" -gt 0;
    then
      if test -z "${DBS}";
      then
        DBS="${db_include}"
      else
        DBS="${DBS}"$'\n'"${db_include}"
      fi
    else
      alert "database '${db_include}' specified in command line does not exist in server"
    fi
  done
fi

if test -z "${DBS}";
then
  alert "List of databases for backup is empty"
  exit 1
fi

let freeze_erros_count=0
for db in ${DBS};
do
  printf "%s\n" "Processing database: ${db}"
  
  db_tables=""
  db_partitions=""
  
  if test "${ONLY_SUPPORTED_ENGINES}" == "yes";
  then
    printf "%s\n%s\n" "Will be backup up only tables with supported engines:" "${SUPPORTED_ENGINES}"
    
    for engine in ${SUPPORTED_ENGINES};
    do
      db_tables_current=""
      db_tables_current="$( echo "clickhouse-client ${CONNECTION_STRING} --query=\"SELECT name FROM system.tables WHERE database='${db}' and engine like '${engine}';\"" | bash )"
      if test "${?}" -ne 0;
      then
        let freeze_erros_count+=1
        printf "%s\n" "Cannot get tables of database '${db}' and engine '${engine}'"
        continue
      fi
      
      if test -n "${db_tables_current}";
      then
        if test -z "${db_tables}";
        then
          db_tables="${db_tables_current}"
        else
          db_tables="${db_tables}"$'\n'"${db_tables_current}"
        fi
      fi
    done
  else
    printf "%s\n" "Will be backup up all tables"
    
    db_tables="$( echo "clickhouse-client ${CONNECTION_STRING} --query=\"SHOW TABLES FROM \"${db}\";\"" | bash )"
    if test "${?}" -ne 0;
    then
      let freeze_erros_count+=1
      printf "%s\n" "Cannot get tables of database '${db}'"
      continue
    fi
  fi
  
  if test -z "${db_tables}";
  then
    printf "%s\n" "WARNING: list of database tables is empty"
    continue
  fi
  
  if test "${DEBUG}" == "yes";
  then
    printf "%s\n%s\n" "Find tables of database:" "${db_tables}"
  fi
  
  db_partitions="$( echo "clickhouse-client ${CONNECTION_STRING} --query=\"SELECT partition FROM system.parts WHERE active and database='${db}' GROUP BY partition ORDER BY partition;\"" | bash )"
  if test "${?}" -ne 0;
  then
    let freeze_erros_count+=1
    printf "%s\n" "Cannot get partitions of database '${db}'"
    continue
  fi
  
  if test -z "${db_partitions}";
  then
    printf "%s\n" "WARNING: list of database partitions is empty"
    continue
  fi
  
  if test "${DEBUG}" == "yes";
  then
    printf "%s\n%s\n" "Find partitions of database:" "${db_partitions}"
  fi
  
  for table in ${db_tables};
  do
    for partition in ${db_partitions};
    do
      freeze_query="ALTER TABLE \\\"${db}\\\".\\\"${table}\\\" FREEZE PARTITION ID '${partition}';"
      
      echo "clickhouse-client ${CONNECTION_STRING} --query=\"${freeze_query}\"" | bash
      if test "${?}" -ne 0;
      then
        let freeze_erros_count+=1
        printf "%s\n" "Cannot freeze partition '${partition}' of table '${table}' of database '${db}'"
        continue
      fi
    done
  done
done

if test "${freeze_erros_count}" -gt 0;
then
  alert "Errors occurred during the table freezing operation"
fi

SHADOW_DIR="$( remove_repeating_vfs_divider "${DATA_DIR}/${SHADOW_DIR_NAME}" )"
if test ! -d "${SHADOW_DIR}";
then
  alert "clickhouse-server shadow data directory does not exist"
  exit 1
fi
if test ! -r "${SHADOW_DIR}";
then
  alert "clickhouse-server shadow data directory does not readable by this user" 
  exit 1
fi
if test ! -x "${SHADOW_DIR}";
then
  alert "clickhouse-server shadow data directory does not executable by this user"
  exit 1
fi

BACKUP_TARGET_STRING="${SHADOW_DIR}"

for db in ${DBS};
do
  if test -z "${BACKUP_TARGET_STRING}";
  then
    BACKUP_TARGET_STRING="$( remove_repeating_vfs_divider "${DATA_DIR}/${METADATA_DIR_NAME}/${db}" )"
    BACKUP_TARGET_STRING="${BACKUP_TARGET_STRING},$( remove_repeating_vfs_divider "${DATA_DIR}/${METADATA_DIR_NAME}/${db}.sql" )"
  else
    BACKUP_TARGET_STRING="${BACKUP_TARGET_STRING},$( remove_repeating_vfs_divider "${DATA_DIR}/${METADATA_DIR_NAME}/${db}" )"
    BACKUP_TARGET_STRING="${BACKUP_TARGET_STRING},$( remove_repeating_vfs_divider "${DATA_DIR}/${METADATA_DIR_NAME}/${db}.sql" )"
  fi
done

00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" "${BACKUP_TARGET_STRING}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

if test "$( compare_vfs_paths "${SHADOW_DIR}" "/" )" == "not_equal";
then
  if test "$( compare_vfs_paths "${SHADOW_DIR}" "${DATA_DIR}" )" == "not_equal";
  then
    rm -rf "${SHADOW_DIR}"
  fi
fi

exit 0

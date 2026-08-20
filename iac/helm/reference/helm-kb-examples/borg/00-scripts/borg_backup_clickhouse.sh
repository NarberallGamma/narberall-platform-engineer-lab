#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа clickhouse

# Его можно применять если clickhouse-server запущен на том же узле на котором будет запущен этот скрипт.

# Принцип работы:

#   - создание локальной резервной копии с помощью утилиты clickhouse-backup
#     https://github.com/Altinity/clickhouse-backup
#   - резервное копирование созданной копии с помощью скрипта borg_backup_files.sh

# Поддерживаемые опции:
# -n|--job-name               - имя задания, суффикс имени Borg-репозитория. Обязательный аргумент
# -c|--config                 - путь к файлу с конфигурацией бэкапа. Необязательный аргумент
# -d|--data-dir               - путь к каталогу с данными clickhouse-server, можно узнать
#                               в файле '/etc/clickhouse-server/config.xml' по директиве <path>.
# -k|--prune                  - строка с опциями алгоритма сохранения резервных копий в
#                               формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                               Необязательный аргумент, без указания этой опции будет
#                               использовано значение ${CUSTOMPRUNE_DEFAULT}
# -o|--options                - дополнительныйе опции для clickhouse-backup create

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/"'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" --config "/etc/clickhouse-backup/config.yml"'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" --config "/etc/clickhouse-backup/config.yml" --options "--tables=my_db.table1,my_db.table_nam?,other_db.*"'
# borg_run_on.sh 10.0.0.1 borg_backup_clickhouse.sh '--job-name "CH" --data-dir "/var/lib/clickhouse/" --config "/etc/clickhouse-backup/config.yml" --options "--tables=single_db.*" --prune "--keep-hourly 3 --keep-within=30d"'

# Также следует обязательно бэкапить конфигурационные файлы Clickhouse. Это удобно делать с помощью команды вида:
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'SYSTEM /etc,/var/spool/cron,/etc/backup-agent/config.d ^\/etc\/\.git$'

# Для задания параметров подключения к clickhouse-server необходимо создать файл /etc/clickhouse-backup/config.yml
# Пример содержимого:
# cat /etc/clickhouse-backup/config.yml
# general:
#   remote_storage: none
#   max_file_size: 1073741824
#   backups_to_keep_local: 0
#   log_level: info
#   allow_empty_backups: false
#   restore_schema_on_cluster: "your-cluster-name" # В случае восстановления в кластерсный clickhouse
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
# Права на файл должны быть 400.
# Если путь к этому файлу отличается, его можно передать через дополнительный ключ "--config", или переменную окружения $CLICKHOUSE_BACKUP_CONFIG пользователя root.


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

NAMEOFBACKUP_DEFAULT='CLICKHOUSE'
CONFIG_DEFAULT='/etc/clickhouse-backup/config.yml'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'
ADDITIONAL_OPTIONS=""
EFFECTIVE_OPTIONS=""

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

function clickhouse_backup_install {
  which clickhouse-backup && return 0
  wget https://github.com/Altinity/clickhouse-backup/releases/download/v2.3.2/clickhouse-backup-linux-amd64.tar.gz
    if [ $? -ne 0 ]; then
        alert "Clickhouse-backup: clickhouse-backup download failed."
        exit 1
    fi
  tar -zxvf clickhouse-backup-linux-amd64.tar.gz -C /usr/local/bin/ --strip-components=3 build/linux/amd64/clickhouse-backup
    if [ $? -ne 0 ]; then
        alert "Clickhouse-backup: clickhouse-backup unpack failed."
        exit 1
    fi
  chown root:root /usr/local/bin/clickhouse-backup
    if [ $? -ne 0 ]; then
        alert "Clickhouse-backup: clickhouse-backup chown failed."
        exit 1
    fi
}

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options n:c:d:k:o: --longoptions ,job-name:,config:,data-dir:,prune:,options: -- "${@}" 2>/dev/null )"
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
    -c|--config)                  CONFIG="${2}";     shift 2;;
    -d|--data-dir)                DATA_DIR="${2}";     shift 2;;
    -k|--prune)                   CUSTOMPRUNE="${2}";  shift 2;;
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

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

clickhouse_backup_install

printf "%s\n" "Create clickhouse data backup"
clickhouse-backup list | grep clickhouse-backup | grep local

if [ $? -eq 0 ]; then
  alert "Backup folder is alrerady created, another backup has been started?"
  exit 1
fi

clickhouse-backup create ${EFFECTIVE_OPTIONS} --config=${CONFIG} clickhouse-backup

if [ $? -ne 0 ]; then
   alert "Clickhouse-backup create clickhouse-backup failed."
   exit 1
fi

if test ! -d "${DATA_DIR}/backup/clickhouse-backup";
then
  alert "clickhouse-backup data directory does not exist"
  exit 1
fi

00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" "${DATA_DIR}/backup/clickhouse-backup" --prune ${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}} --dont-ignore-missing-files

if [ $? -ne 0 ]; then
  alert "clickhouse-backup data directory backup failed"
  clickhouse-backup delete local clickhouse-backup
  clickhouse-backup clean
  exit 1
fi

clickhouse-backup delete local clickhouse-backup
clickhouse-backup clean

exit 0

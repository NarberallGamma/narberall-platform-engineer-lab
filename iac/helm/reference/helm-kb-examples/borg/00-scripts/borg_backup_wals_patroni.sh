#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа архивов WAL-файлов

# Принцип работы:
#   - резервное копирование архивов WAL-файлов с помощью borg_backup_files.sh
#   - удаление старых архивов WAL-файлов с помощью find

# Перед настройкой бэкапа архивов WAL-файлов требуется собственно настроить
# архивацию WAL-файлов в специально выделенный для этого каталог
# Для этого в файле postgresql.conf необходимо:
#   - включить архивацию WAL-файлов, установив параметр 'archive_mode' в 'on'
#   - указать комманду архивации WAL-файлов в параметре 'archive_command'
#   - перезапустить сервис PostgreSQL (по согласованию с командой или клиентом)
# Типичные значения параметров 'archive_mode' и 'archive_command':
# archive_mode = on
# archive_command = '/usr/bin/test ! -f /var/backups/pgsql/wal/%f.tgz && /bin/tar -zcf /var/backups/pgsql/wal/%f.tgz %p'

# Если Borg-репозиторий с бэкапами оказывается слишком большим и коэффициент
# дедпуликации в нем оказывается не больше двух т.е. 'Deduplicated size' для всего
# Borg-репозитория меньше не больше чем в 2 раза по сравнению с 'Original size', то
# можно отключить сжатие архивов WAL-файлов использовав 'archive_command' без сжатия:
# archive_command = '/usr/bin/test ! -f /var/backups/pgsql/wal/%f.tar && /bin/tar -cf /var/backups/pgsql/wal/%f.tar %p'
# Изменять archive_command можно только по согласованию с командой/клиентом

# Если WAL-файлы архивируются недостаточно часто и некоторые из бэкапов оказываются
# околонулевого размера можно указать PostgreSQL делать архивы WAL-файлов по истечении
# времени с помощью параметра archive_timeout. Хорошее значения этого параметра около 600 секунд
# Использовать параметр archive_timeout можно только по согласованию с командой/клиентом

# Поддерживаемые опции:
# -k|--prune        - строка с опциями алгоритма сохранения резервных копий в
#                     формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                     Необязательный аргумент, без указания этой опции будет
#                     использовано значение ${CUSTOMPRUNE_DEFAULT}
# -x|--patroni-port - порт patroni. по умолчанию 8008

# Позиционные аргументы:
# ${1} - путь к каталогу с архивами WAL-файлов. Обязательный аргумент
# ${2} - максимальное время жизни WAL-файлов в минутах, WAL-файлы с большим
#        временем жизни будут удалены, из-за округления фактическое время жизни
#        WAL-файлов может быть больше на 1 день от указанного максимального.
#        Необязательный аргумент, без указания этого аргумента будет
#        использовано значение ${THRESHOLD_DEFAULT}

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_wals_patroni.sh 'WAL /var/backups/pgsql/wal'
# borg_run_on.sh 10.0.0.1 borg_backup_wals_patroni.sh 'WAL /var/backups/pgsql/wal 7'
# borg_run_on.sh 10.0.0.1 borg_backup_wals_patroni.sh 'WAL /var/backups/pgsql/wal 7 --prune "--keep-hourly 3 --keep-within=30d"'

# Попытки указать в качестве каталога с архивами WAL-файлов каталоги уровня
# меньше чем 3 т.е. '/', '/etc', '/var' и т.п., а также каталоги перечисленные
# в ${PROTECTED_DIRS} приведут к аварийному завершению скрипта и отсутствию бэкапов

################################################################################

THRESHOLD_DEFAULT='14'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d'
PATRONI_PORT="8008"
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
  BACKUP_TYPE="${NAMEOFBACKUP}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
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

#Проверяет входную строку на соответствие положительному числовому формату
#${1} - string
check_to_positive_number_format()
{
  if test -n "${1}";
  then
    if test -n "$( printf "%s" "${1}" | sed --quiet "s/\([1-9]\{1,1\}\)\|\(^[1-9][0-9]*\)//;p;" )";
    then
      return 1
    fi
  else
    return 1
  fi

  return 0
}

################################################################################

CUSTOMPRUNE=""
CUSTOM_PATRONI_PORT=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options k:x: --longoptions ,prune:,patroni-port: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -k|--prune)  CUSTOMPRUNE="${2}";  shift 2;;
    -x|--patroni-port) CUSTOM_PATRONI_PORT="${2}"; shift 2;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"
WALDIR="${3}"
THRESHOLD="${4}"

IFS=$'\n'

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${WALDIR}";
then
  alert "WAL directory is not defined"
  exit 1
fi

if test ! -e "${WALDIR}";
then
  alert "WAL directory does not exists"
  exit 1
fi

if test ! -d "${WALDIR}";
then
  alert "Name of WAL directory in use but is not a directory"
  exit 1
fi

if test ! -r "${WALDIR}";
then
  alert "WAL directory does not readable by this user"
  exit 1
fi

if test ! -x "${WALDIR}";
then
  alert "WAL directory does not executable by this user"
  exit 1
fi

for dir in ${PROTECTED_DIRS};
do
if test "$( compare_vfs_paths "${WALDIR}" "${dir}" )" == "equal" -o "$( compare_vfs_paths "${WALDIR}" "${dir}" )" == "uncertain";
  then
    alert "Directory '${dir}' is protected and cannot be specified as the WAL directory."
    exit 1
  fi
done

if test "$( get_vfs_path_level "${WALDIR}" )" -le "2";
then
  alert "WAL directory level cannot be less that 2"
  exit 1
fi

check_to_positive_number_format "${THRESHOLD}"
if test "${?}" -ne 0;
then
  printf "%s\n" "WARNING: cleaning time threshold of WAL directory '${THRESHOLD}' is not numeric or less than 1. Used default value '${THRESHOLD_DEFAULT}' days"
  THRESHOLD="${THRESHOLD_DEFAULT}"
fi

# Check postgresql instance role:
p_port=${CUSTOM_PATRONI_PORT:-${PATRONI_PORT}}
ip_port=$(ss -tnlp | grep $p_port | awk '{print $4}')
role=$(curl -s $ip_port | jq -r .role)

if [[ "$role" == "master" ]] || [[ "$role" == "primary" ]]; then

  printf "%s\n" "Backup WAL directory:"

  00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" "${WALDIR}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --dont-ignore-missing-files --skip-hostname-prefix
  if test "${?}" -ne 0;
  then
    alert "Cannot backup WAL directory '${WALDIR}'. Also the WAL directory will not be cleared"
    exit 1
  fi

  printf "%s\n" "Clean WAL directory:"

  find "${WALDIR}" -mindepth 1 -type f -mmin "+${THRESHOLD}" -print -delete
  if test "${?}" -ne 0;
  then
    alert "Cannot clean WAL directory '${WALDIR}'"
    exit 1
  fi
else
  echo "This is slave, skipping backup wal"
fi

exit 0

#!/usr/bin/env bash

# Description: Monitor Borg backup freshness for a per-project repository layout

# Dependencies: sed, find, numfmt, uuidgen, jq, yq, borg

################################################################################
# Значения по умолчанию

# Пороговая (вызывающая тревогу) разница по умолчанию между временем проверки и
# датой создания последнего архива резервной копии, единица измерения - час
THRESHOLD_AGE_BY_DEFAULT='24'

# Предел хранения отключенных бэкапов, единица измерения - день
DISABLED_BACKUPS_STORAGE_LIMIT='65'

# Минимальный размер последнего архива по умолчанию, единица измерения - байт
LAST_ARCHIVE_MIN_SIZE="1048576"

# Допустимое уменьшение размера последнего архива по умолчанию, единица измерения - %
LAST_ARCHIVE_ALLOWABLE_DECREASE_SIZE="50"

BACKUP_DIRECTORY_EXPECTED_OWNER_USER="root"
BACKUP_DIRECTORY_EXPECTED_OWNER_GROUP="root"
BACKUP_DIRECTORY_EXPECTED_ACCESS_RIGHTS="drwxr-xr-x"

# Directory names that are not treated as a project directory
# Also lists restic-only backup trees so they are not counted as Borg projects
NON_PROJECT_DIRECTORIES='
RESTORE
TEMP
.borg_jobs_mon
lost+found
'

# ВременнЫе параметры повторной обработки Borg-репозиториев (заданий резервного
# копирования)
ATTEMPTS_MAX_TIME='600'
ATTEMPTS_PAUSE='60'

DEBUG="no"

SCRIPT_PATH="$( readlink -e "${0}" )"
SCRIPT_DIR="$( dirname "${SCRIPT_PATH}" )"
SCRIPT_NAME="$( basename "${SCRIPT_PATH}" )"
TEMP_FILE_PREFIX="${SCRIPT_NAME}_"

STOP_BORG_REPO_PROCESSING_DIR="/tmp/borg_jobs_mon_stop_borg_repo_processing"

# Версия скрипта
VERSION='2.13'

################################################################################
# Определения функций

# Выводит в stderr текст в зеленом цвете
# ${1} - input string
debug_green()
{
  if test "${DEBUG}" == "yes";
  then
    printf "\033[0;32m%s\033[0m\n" "${1}" 1>&2
  fi
}

# Выводит в stderr текст в желтом цвете
# ${1} - input string
debug_yellow()
{
  if test "${DEBUG}" == "yes";
  then
    printf "\033[0;33m%s\033[0m\n" "${1}" 1>&2
  fi
}

# Выводит в stderr текст в красном цвете
# ${1} - input string
debug_red()
{
  if test "${DEBUG}" == "yes";
  then
    printf "\033[0;31m%s\033[0m\n" "${1}" 1>&2
  fi
}

# Проверяет входную строку на наличие в ней символов '/'
# ${1} - string
check_to_vfs_divider()
{
  if test -n "${1}";
  then
    if test "$( printf "%s" "'${1}" | sed --quiet "/.*/{s/^'//;s/\///;p;}" )" != "${1}";
    then
      return 2
    fi
  else
    return 1
  fi

  return 0
}

# Проверяет входную строку на соответствие положительному числовому формату ( >=1 )
# ${1} - string
check_to_positive_number_format()
{
  if test -n "${1}";
  then
    if test -n "$( printf "%s" "'${1}" | sed --quiet "/.*/{s/^'//;s/\([1-9]\{1,1\}\)\|\(^[1-9][0-9]*\)//;p;}" )";
    then
      return 2
    fi
  else
    return 1
  fi

  return 0
}

# Проверяет входную строку на соответствие неотрицательному числовому формату ( >=0 )
# ${1} - string
check_to_non_negative_number_format()
{
  if test -n "${1}";
  then
    if test -n "$( printf "%s" "'${1}" | sed --quiet "/.*/{s/^'//;s/\([0-9]\{1,1\}\)\|\(^[1-9][0-9]*\)//;p;}" )";
    then
      return 2
    fi
  else
    return 1
  fi

  return 0
}

# Удаляет избыточные символы '/' в строке
# ${1} - string
remove_repeating_vfs_divider()
{
  printf "%s" "${1}" | sed --quiet "s/\/\/*/\//g;p;"
}

# Экранирует символы для передачи в json
# ${1} - input string
escape_chars_for_json()
{
  printf "%s" "${1}" | sed --quiet "s/\\\/\\\\\\\/g;s/\r/\\\r/g;s/\t/\\\t/g;s/\"/\\\\\"/g;p"
}

# Заменяет символ новой строки на символ '\n'
# ${1} - input string
escape_new_line()
{
  local out_string=""

  IFS=$'\n'

  for line in ${1};
  do
    if test -z "${out_string}";
    then
      out_string="${line}"
    else
      out_string="${out_string}\n${line}"
    fi
  done

  printf "%s" "${out_string}"
}

# Удаляет пробелы с краев строки
# ${1} - string
trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

# Удаляет из YAML-текста комментарии
# ${1} - yaml text
clear_yaml_of_comments()
{
  printf "%s" "${1}" | sed --quiet "s/[ \t]\#.*//g;s/^\#.*//g;p"
}

clear_yaml_of_insignificant_words()
{
  printf "%s" "${1}" | sed --quiet "s/^---$//;s/[ \t]\#.*//g;s/^\#.*//g;s/[ \t]//g;p"
}

# Извлекает имя задания резервного копирования из имени репозитория
# ${1} - repository name
get_backup_job_type()
{
  printf "%s" "${1}" | sed --quiet "s/.*-\([^-]*\)$/\1/;p"
}

# Смещает текст на указанное количество пробелов
# ${1} - text
# ${2} - indentation (spaces) quantity
set_text_indentation()
{
  local indent_symbol
  local indent_string

  indent_symbol=" "

  for indent in $( seq 1 "${2}" );
  do
    indent="${indent}"
    indent_string="${indent_string}${indent_symbol}"
  done

  printf "%s" "${1}" | sed --quiet "s/^/${indent_string}/;p"
}

# Проверяет что в выводе borg есть строка с ошибкой блокировки по таймауту
# ${1} - borg error text
check_that_borg_repo_locked_by_timeout()
{
  printf "%s" "${1}" | sed --quiet "/Failed to create\/acquire the lock[ \t][ \t]*.*\/lock\.exclusive[ \t][ \t]*(timeout)/{;p}"
}

# Преобразует строку, содержащую размер с кратными приставкам, в строку с числом
# ${1} - formated string
string_with_size_to_number()
{
  local suffix

  suffix="B"

  ( export LC_ALL="en_US.UTF-8"; printf "%s" "${1}" | numfmt --from=iec --suffix="${suffix}" | tr -d '\n' | sed --quiet "s/${suffix} *$//;p" )
}

# Преобразует строку с числом в строку, содержащую размер с кратными приставкам
# ${1} - formated string
number_to_string_with_size()
{
  local suffix

  suffix="B"

  ( export LC_ALL="en_US.UTF-8"; printf "%s" "${1}" | numfmt --to=iec --suffix="${suffix}" --format="%f" | tr -d '\n' )
}

# Send a message to the alert backend or stdout, wrapper for send_to_alerts
# ${1} - project
# ${2} - impact
# ${3} - description
# ${4} - message output direction, if set to 'stdout' then print message to
#       stdout, else send the message to the alert backend
send_alert()
{
  local project
  local impact
  local likelihood
  local description

  local trigger
  local summary

  project="shop-app"
  impact="critical"
  likelihood="likely"
  description="Something happened, but description is not defined!"

  trigger="borg_jobs_mon"
  summary="Problems with backups"

  if test -n "${1}";
  then
    project="${1}"
  fi

  if test -n "${2}";
  then
    impact="${2}"
  fi

  if test -n "${3}";
  then
    description="${3}"
  fi

  debug_red "--- Alert to: {${project}} BEGIN"

  case "${4}" in
    "stdout")  printf "%s\n" "${description}";;
    *)         "./send_to_alerts.sh" "${project}" "${impact}" "${likelihood}" "${trigger}" "${summary}" "${CHECK_MODE}" "${description}"
               if test ${?} -ne 0;
               then
                 "./send_to_alerts.sh" "shop-app" "critical" "likely" "${trigger}" "Cannot send alert for project {${project}}. The project may not exist." "${CHECK_MODE}"
               fi
    ;;
  esac

  debug_red "--- Alert to: {${project}} END"

  return 0
}

# Create a ticket in the ticketing system
# ${1} - project
# ${2} - subject
# ${3} - message
# ${4} - message output direction, if set to 'stdout' then print message to
#       stdout, else create a ticket in the ticketing system
create_ticket()
{
  local project
  local subject
  local message

  local recipient
  local from

  project="shop-app"
  subject="Something happened, but subject is not defined!"
  message="Something happened, but message is not defined!"

  recipient="+borg_jobs_mon@mail.example.com"
  from="$(hostname)@example.com"

  if test -n "${1}";
  then
    project="${1}"
  fi

  if test -n "${2}";
  then
    subject="${2}"
  fi

  if test -n "${3}";
  then
    message="${3}"
  fi

  recipient="${project}${recipient}"

  debug_red "--- Ticket to: {${project}} BEGIN"

  case "${4}" in
    "stdout")  printf "%s: %s: %s: %s\n%s\n" "${project}" "${from}" "${recipient}" "${subject}" "${message}";;
    *)         printf "Subject: %s\n\n%s\n" "${subject}" "${message}" | sendmail -f"${from}" "${recipient}";;
  esac

  debug_red "--- Ticket to: {${project}} END"

  return 0
}

# Выполняет отправку алертов из массива COMMON_WARNINGS
# Global variables:
#   - RO
#     - ONE_PROJECT
#     - COMMON_WARNINGS_COUNT
#     - COMMON_WARNINGS
#     - OUTPUT_DIRECTION
alerts_about_common_warnings()
{
  local alert_message
  alert_message=""

  local common_warnings_index

  let common_warnings_index=0
  while test "${common_warnings_index}" -lt "${COMMON_WARNINGS_COUNT}";
  do
    if test -n "${COMMON_WARNINGS["${common_warnings_index}"]}";
    then
      if test -n "${alert_message}";
      then
        alert_message="${alert_message}"$'\n'"${COMMON_WARNINGS["${common_warnings_index}"]}"
      else
        alert_message="${COMMON_WARNINGS["${common_warnings_index}"]}"
      fi
    fi

    let common_warnings_index+=1
  done

  if test -n "${alert_message}";
  then
    send_alert "${ONE_PROJECT}" "critical" "${alert_message}" "${OUTPUT_DIRECTION}"
  fi
}

# Выполняет отправку алертов из массива COMMON_ERRORS
# Global variables:
#   - RO
#     - ONE_PROJECT
#     - COMMON_ERRORS_COUNT
#     - COMMON_ERRORS
#     - OUTPUT_DIRECTION
alerts_about_common_errors()
{
  local alert_message
  alert_message=""

  local common_errors_index

  let common_errors_index=0
  while test "${common_errors_index}" -lt "${COMMON_ERRORS_COUNT}";
  do
    if test -n "${COMMON_ERRORS["${common_errors_index}"]}";
    then
      if test -n "${alert_message}";
      then
        alert_message="${alert_message}"$'\n'"${COMMON_ERRORS["${common_errors_index}"]}"
      else
        alert_message="${COMMON_ERRORS["${common_errors_index}"]}"
      fi
    fi

    let common_errors_index+=1
  done

  if test -n "${alert_message}";
  then
    send_alert "${ONE_PROJECT}" "catastrophic" "${alert_message}" "${OUTPUT_DIRECTION}"
  fi
}

# Выполняет отправку алертов из массива PROJECTS_WARNINGS_COMMON
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_WARNINGS_COMMON_COUNT
#     - PROJECTS_WARNINGS_COMMON
#     - OUTPUT_DIRECTION
alerts_about_projects_common_warnings()
{
  local project_index
  project_index="${1}"

  local project_warning_common_index

  local alert_message
  alert_message=""

  if test "${PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]}" -gt 0;
  then
    let project_warning_common_index=0
    while test "${project_warning_common_index}" -lt "${PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]}";
    do
      if test -n "${PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]}";
      then
        if test -n "${alert_message}";
        then
          alert_message="${alert_message}"$'\n'"${PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]}"
        else
          alert_message="${PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]}"
        fi
      fi

      let project_warning_common_index+=1
    done

    if test -n "${alert_message}";
    then
      send_alert "${PROJECTS["${project_index}"]}" "critical" "${alert_message}" "${OUTPUT_DIRECTION}"
    fi
  fi
}

# Выполняет отправку алертов из массива PROJECTS_ERRORS_COMMON
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_ERRORS_COMMON_COUNT
#     - PROJECTS_ERRORS_COMMON
#     - OUTPUT_DIRECTION
alerts_about_projects_common_erros()
{
  local project_index
  project_index="${1}"

  local project_error_common_index

  local alert_message
  alert_message=""

  if test "${PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]}" -gt 0;
  then
    let project_error_common_index=0
    while test "${project_error_common_index}" -lt "${PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]}";
    do
      if test -n "${PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]}";
      then
        if test -n "${alert_message}";
        then
          alert_message="${alert_message}"$'\n'"${PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]}"
        else
          alert_message="${PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]}"
        fi
      fi

      let project_error_common_index+=1
    done

    if test -n "${alert_message}";
    then
      send_alert "${PROJECTS["${project_index}"]}" "catastrophic" "${alert_message}" "${OUTPUT_DIRECTION}"
    fi
  fi
}

# Выполняет отправку алертов из массивов PROJECTS_WARNINGS_BACKUP
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_WARNINGS_BACKUP_COUNT
#     - PROJECTS_WARNINGS_BACKUP
#     - OUTPUT_DIRECTION
alerts_about_projects_backup_warnings()
{
  local project_index
  project_index="${1}"

  local project_job_index
  local project_warning_backup_index

  local alert_message
  alert_message=""

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    if test "${PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]}" -gt 0;
    then
      let project_warning_backup_index=0
      while test "${project_warning_backup_index}" -lt "${PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]}";
      do
        if test -n "${PROJECTS_WARNINGS_BACKUP["${project_index},${project_job_index},${project_warning_backup_index}"]}";
        then
          if test -n "${alert_message}";
          then
            alert_message="${alert_message}"$'\n'"${PROJECTS_WARNINGS_BACKUP["${project_index},${project_job_index},${project_warning_backup_index}"]}"
          else
            alert_message="${PROJECTS_WARNINGS_BACKUP["${project_index},${project_job_index},${project_warning_backup_index}"]}"
          fi
        fi

        let project_warning_backup_index+=1
      done
    fi

    let project_job_index+=1
  done

  if test -n "${alert_message}";
  then
    send_alert "${PROJECTS["${project_index}"]}" "critical" "${alert_message}" "${OUTPUT_DIRECTION}"
  fi
}

# Выполняет отправку алертов из массива PROJECTS_ERRORS_BACKUP
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
#     - OUTPUT_DIRECTION
alerts_about_projects_backup_errors()
{
  local project_index
  project_index="${1}"

  local project_job_index
  local project_error_backup_index

  local alert_message
  alert_message=""

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    if test "${PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]}" -gt 0;
    then
      let project_error_backup_index=0
      while test "${project_error_backup_index}" -lt "${PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]}";
      do
        if test -n "${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]}";
        then
          let project_error_backup_found_index=0
          while test "${project_error_backup_found_index}" -lt "${project_error_backup_index}";
          do
            if test "${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]}" == "${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_found_index}"]}";
            then
              PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_found_index}"]=""
            fi

            let project_error_backup_found_index+=1
          done

          let project_error_backup_found_index=project_error_backup_index+1
          while test "${project_error_backup_found_index}" -lt "${PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]}";
          do
            if test "${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]}" == "${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_found_index}"]}";
            then
              PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_found_index}"]=""
            fi

            let project_error_backup_found_index+=1
          done

          if test -n "${alert_message}";
          then
            alert_message="${alert_message}"$'\n'"${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]}"
          else
            alert_message="${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]}"
          fi
        fi

        let project_error_backup_index+=1
      done
    fi

    let project_job_index+=1
  done

  if test -n "${alert_message}";
  then
    send_alert "${PROJECTS["${project_index}"]}" "catastrophic" "${alert_message}" "${OUTPUT_DIRECTION}"
  fi
}

create_tickets_about_disabled_backups()
{
  local project_index
  project_index="${1}"

  local run_message
  run_message=""

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    if test "${PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT["${project_index},${project_job_index}"]}" -gt 0;
    then
      let project_warning_backup_disabled_index=0
      while test "${project_warning_backup_disabled_index}" -lt "${PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT["${project_index},${project_job_index}"]}";
      do
        if test -n "${PROJECTS_WARNINGS_BACKUP_DISABLED["${project_index},${project_job_index},${project_warning_backup_disabled_index}"]}";
        then
          if test -n "${run_message}";
          then
            run_message="${run_message}"$'\n'"${PROJECTS_WARNINGS_BACKUP_DISABLED["${project_index},${project_job_index},${project_warning_backup_disabled_index}"]}"
          else
            run_message="${PROJECTS_WARNINGS_BACKUP_DISABLED["${project_index},${project_job_index},${project_warning_backup_disabled_index}"]}"
          fi
        fi

        let project_warning_backup_disabled_index+=1
      done
    fi

    let project_job_index+=1
  done

  if test -n "${run_message}";
  then
    create_ticket "${PROJECTS["${project_index}"]}" "Превышен предел хранения отключенных бэкапов" "${run_message}" "${OUTPUT_DIRECTION}"
  fi
}

# Извлекает данные о последних бэкапах в массивы
# PROJECTS_JOBS_LAST_ARCHIVE_NAME, PROJECTS_JOBS_LAST_ARCHIVE_DATE и PROJECTS_JOBS_LAST_ARCHIVE_SIZE
# Input variables:
#   - ${1} - project index in PROJECTS array
#   - ${2} - project index in PROJECTS_JOBS array
#   - ${3} - number of last archives count for which need to get data
#   - ${4} - data level (time, size)
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_JOBS
#     - PROJECTS_JOBS_DIR
#     - PROJECTS_JOBS_THRESHOLD_AGE
#     - ONE_PROJECT
#     - ONE_PROJECT_USER
#   - RW
#     - PROJECTS_JOBS_LAST_ARCHIVE_NAME
#     - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
get_backup_data()
{
  local project_index
  project_index="${1}"

  local project_job_index
  project_job_index="${2}"

  local last_archives_count
  last_archives_count="${3}"

  local archive_data_level
  archive_data_level="${4}"

  local project_job_last_archive_index

  # Путь к временному файлу журнала с ошибками
  local temporary_error_log
  temporary_error_log="${TEMP_DIR}/${TEMP_FILE_PREFIX}_${FUNCNAME[0]}_${PROJECTS["${project_index}"]}.log"

  # Залокаливание остальных переменных
  local project_error_backup_index
  local current_job
  local current_job_dir
  local current_user
  local borg_list_out
  local borg_info_out
  local last_archive_date
  local last_archive_date_in_seconds
  local last_command_exit_value
  local last_archive_name
  local last_archive_size

  check_to_positive_number_format "${last_archives_count}"
  if test "${?}" -ne 0;
  then
    let last_archives_count=1
  fi

  current_job=""
  current_job="${PROJECTS_JOBS["${project_index},${project_job_index}"]}"

  current_job_dir=""
  current_job_dir="${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}"

  if test -z "${ONE_PROJECT}";
  then
    current_user=${PROJECTS["${project_index}"]}
  else
    current_user="${ONE_PROJECT_USER:-${ONE_PROJECT}}"
  fi

  touch "${temporary_error_log}"
  chmod 0600 "${temporary_error_log}"
  printf "%s" "" > "${temporary_error_log}"

  if test -d "${STOP_BORG_REPO_PROCESSING_DIR}";
  then
    debug_red "RETURN: Project: {${PROJECTS["${project_index}"]}} before 'borg list' because exist directory {${STOP_BORG_REPO_PROCESSING_DIR}} that signals stop borg repositories processing"

    unlink "${temporary_error_log}"
    return 3
  fi

  borg_list_out=""
  borg_list_out="$(
    sudo -u "${current_user}" -i bash -c "
      export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK='yes';
      export BORG_RELOCATED_REPO_ACCESS_IS_OK='yes';
      export BORG_PASSPHRASE='';
      borg list --sort-by timestamp --last '${last_archives_count}' --json '${current_job_dir}'" 2>"${temporary_error_log}"
  )"
  if test "${?}" -ne 0;
  then
    # Эта ошибка может быть разрешена
    let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
    let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
    PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: Cannot get list of archives for project {${PROJECTS["${project_index}"]}}: job {${current_job}}. Didn't check for late backups! $( printf "\n  Error message:\n" && set_text_indentation "$( cat "${temporary_error_log}" )" "4" )"

    if test -z "$( check_that_borg_repo_locked_by_timeout "$( cat "${temporary_error_log}" )" )";
    then
      unlink "${temporary_error_log}"
      return 2
    fi

    # Запоминание индекса ошибки на случай ее разрешения
    let PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT["${FUNCNAME[0]}"]+=1
    let projects_jobs_erros_recovered_indexes_index=PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT["${FUNCNAME[0]}"]-1
    PROJECTS_JOBS_ERROS_RECOVERED_INDEXES["${FUNCNAME[0]},${projects_jobs_erros_recovered_indexes_index}"]="${project_error_backup_index}"

    unlink "${temporary_error_log}"
    return 1
  fi

  last_archive_date=""
  last_archive_date="$( printf "%s" "${borg_list_out}" | jq -r ".archives[].start" 2>"${temporary_error_log}" )"
  if test "${?}" -ne 0;
  then
    let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
    let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
    PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: Cannot get time of last archive for project {${PROJECTS["${project_index}"]}}: job {${current_job}}. Didn't check for late backups! $( printf "\n  Error message:\n" && set_text_indentation "$( cat "${temporary_error_log}" )" "4" )"

    unlink "${temporary_error_log}"
    return 2
  fi

  for line in ${last_archive_date};
  do
    last_archive_name=""
    last_archive_date_in_seconds=""
    last_archive_size=""

    last_archive_date_in_seconds=""
    last_archive_date_in_seconds="$( date +"%s" --date="${line}" 2>"${temporary_error_log}" )"
    last_command_exit_value="${?}"

    check_to_non_negative_number_format "${last_archive_date_in_seconds}"
    if test "${?}" -ne 0 -o "${last_command_exit_value}" -ne 0;
    then
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
      let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
      PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: Failed to convert time of last archive to seconds for project {${PROJECTS["${project_index}"]}}: job {${current_job}}. Didn't check for late backups! $( printf "\n  Error message:\n" && set_text_indentation "$( cat "${temporary_error_log}" )" "4" )"

      unlink "${temporary_error_log}"
      return 2
    fi

    last_archive_name=""
    last_archive_name="$( printf "%s" "${borg_list_out}" | jq -r ".archives[] | select( .start == \"${line}\" ) | .name" 2>"${temporary_error_log}" )"
    if test "${?}" -ne 0;
    then
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
      let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
      PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: Cannot get name of last archive for project {${PROJECTS["${project_index}"]}}: job {${current_job}}. Didn't check for late backups! $( printf "\n  Error message:\n" && set_text_indentation "$( cat "${temporary_error_log}" )" "4" )"

      unlink "${temporary_error_log}"
      return 2
    fi

    if test "${archive_data_level}" == "size";
    then
      debug_yellow "PROCESSING: Project: {${PROJECTS["${project_index}"]}}, job: {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}, archive: {${last_archive_name}}"

      if test -d "${STOP_BORG_REPO_PROCESSING_DIR}";
      then
        debug_red "RETURN: Project: {${PROJECTS["${project_index}"]}} before 'borg info' because exist directory {${STOP_BORG_REPO_PROCESSING_DIR}} that signals stop borg repositories processing"

        unlink "${temporary_error_log}"
        return 3
      fi

      borg_info_out=""
      borg_info_out="$(
        sudo -u "${current_user}" -i bash -c "
          export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK='yes';
          export BORG_RELOCATED_REPO_ACCESS_IS_OK='yes';
          export BORG_PASSPHRASE='';
          borg info --json '${current_job_dir}::${last_archive_name}'" 2>"${temporary_error_log}"
      )"
      if test "${?}" -ne 0;
      then
        # Эта ошибка может быть разрешена
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: Cannot get info of archives for project {${PROJECTS["${project_index}"]}}: job {${current_job}}. Didn't check for late backups! $( printf "\n  Error message:\n" && set_text_indentation "$( cat "${temporary_error_log}" )" "4" )"

        if test -z "$( check_that_borg_repo_locked_by_timeout "$( cat "${temporary_error_log}" )" )";
        then
          unlink "${temporary_error_log}"
          return 2
        fi

        # Запоминание индекса ошибки на случай ее разрешения
        let PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT["${FUNCNAME[0]}"]+=1
        let projects_jobs_erros_recovered_indexes_index=PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT["${FUNCNAME[0]}"]-1
        PROJECTS_JOBS_ERROS_RECOVERED_INDEXES["${FUNCNAME[0]},${projects_jobs_erros_recovered_indexes_index}"]="${project_error_backup_index}"

        unlink "${temporary_error_log}"
        return 1
      fi

      last_archive_size=""
      last_archive_size="$( printf "%s" "${borg_info_out}" | jq -r ".archives[].stats.original_size" 2>"${temporary_error_log}" )"
      last_command_exit_value="${?}"

      check_to_non_negative_number_format "${last_archive_size}"
      if test "${?}" -ne 0 -o "${last_command_exit_value}" -ne 0;
      then
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: Cannot get size of last archive for project {${PROJECTS["${project_index}"]}}: job {${current_job}}. Didn't check for late backups! $( printf "\n  Error message:\n" && set_text_indentation "$( cat "${temporary_error_log}" )" "4" )"

        unlink "${temporary_error_log}"
        return 2
      fi
    fi

    # Заполнение:
    #   - PROJECTS_JOBS_LAST_ARCHIVE_NAME
    #   - PROJECTS_JOBS_LAST_ARCHIVE_DATE
    #   - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
    let PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]+=1
    let project_job_last_archive_index=PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]-1
    PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${project_job_last_archive_index}"]="${last_archive_name}"
    PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]="${last_archive_date_in_seconds}"
    PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]="${last_archive_size}"

  done

  unlink "${temporary_error_log}"

  # Обнуление ошибок в связи с тем, что нахождение в этом месте означает либо изначальное отсутствие ошибок, либо их разрешение путем повторения операции
  let projects_jobs_erros_recovered_indexes_index=0
  while test "${projects_jobs_erros_recovered_indexes_index}" -lt "${PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT["${FUNCNAME[0]}"]}";
  do
    PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${PROJECTS_JOBS_ERROS_RECOVERED_INDEXES["${FUNCNAME[0]},${projects_jobs_erros_recovered_indexes_index}"]}"]=""

    let projects_jobs_erros_recovered_indexes_index+=1
  done

  return 0
}

# Извлекает данные о бэкапах с повторением в случае появления разрешимых ошибок (timeout и т.п.)
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - ATTEMPTS_MAX_ATTEMPTS
#     - ATTEMPTS_MAX_TIME
#     - ATTEMPTS_PAUSE
#     - PROJECTS
#     - PROJECTS_JOBS_COUNT
#     - CHECK_MODE
#     - CHECK_ARCHIVE_SIZE_PERIOD
#   - RW
#     - PROJECTS_JOBS_LAST_ARCHIVE_COUNT
#     - PROJECTS_JOBS_LAST_ARCHIVE_NAME
#     - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
#     - PROJECTS_JOBS_CHECK_START
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
get_backup_data_handler()
{
  local project_index
  project_index="${1}"

  local project_job_index
  local project_job_last_archive_index

  # Переменные для работы с разрешением ошибок через повторение
  local projects_jobs_remaining_count
  let projects_jobs_remaining_count=0

  local projects_jobs_remaining
  declare -a projects_jobs_remaining

  local jobs_processing_start_date
  local jobs_processing_curre_date
  local jobs_processing_diffe_date

  local attempts_count

  # Массив с индексами сообщений об ошибках (их нужно запомнить на случай их разрешения)
  # Итерируются через "${FUNCNAME[0]},${projects_jobs_erros_recovered_indexes_index}"
  local PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT
  local PROJECTS_JOBS_ERROS_RECOVERED_INDEXES
  declare -a PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT
  declare -A PROJECTS_JOBS_ERROS_RECOVERED_INDEXES

  # Залокаливание остальных переменных
  local last_archives_count
  local archive_data_level
  local get_backup_data_exit_value

  # Заполнение projects_jobs_remaining символом '1', означающим необходимость выполнения действий для соответствующего задания
  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]=0
    projects_jobs_remaining["${project_job_index}"]="1"

    let project_job_index+=1
  done

  # Индексы ошибок для функции get_backup_data
  PROJECTS_JOBS_ERROS_RECOVERED_INDEXES_COUNT["get_backup_data"]=0

  projects_jobs_remaining_count="${PROJECTS_JOBS_COUNT["${project_index}"]}"
  jobs_processing_start_date="$( date +"%s" )"
  let attempts_count=0
  while test "${projects_jobs_remaining_count}" -gt 0;
  do
    if test -d "${STOP_BORG_REPO_PROCESSING_DIR}";
    then
      debug_red "BREAK: Project: {${PROJECTS["${project_index}"]}} from attempts cycle because exist directory {${STOP_BORG_REPO_PROCESSING_DIR}} that signals stop borg repositories processing"
      break
    fi

    let project_job_index=0
    while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
    do
      if test -d "${STOP_BORG_REPO_PROCESSING_DIR}";
      then
        debug_red "BREAK: Project: {${PROJECTS["${project_index}"]}} from job cycle because exist directory {${STOP_BORG_REPO_PROCESSING_DIR}} that signals stop borg repositories processing"
        break
      fi

      if test "${projects_jobs_remaining["${project_job_index}"]}" == "1";
      then
        PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]=0

        # В обычном режиме выполняем извлечение данных из репозитория только для НЕ disable заданий
        if test "${CHECK_MODE}" != "check-disabled-backups-storage-limit" -a "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" == "disable";
        then
          let projects_jobs_remaining_count-=1
          projects_jobs_remaining["${project_job_index}"]="0"
          let project_job_index+=1
          continue
        fi

        # В режиме проверки отключенных бэкапов выполняем извлечение данных из репозитория только ДЛЯ disable заданий
        if test "${CHECK_MODE}" == "check-disabled-backups-storage-limit" -a "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" != "disable";
        then
          let projects_jobs_remaining_count-=1
          projects_jobs_remaining["${project_job_index}"]="0"
          let project_job_index+=1
          continue
        fi

        if test "${CHECK_MODE}" == "check-archive-age" -o "${CHECK_MODE}" == "check-disabled-backups-storage-limit";
        then
          let last_archives_count=1
          archive_data_level="time"
        fi

        if test "${CHECK_MODE}" == "check-archive-size";
        then
          last_archives_count="$(( CHECK_ARCHIVE_SIZE_PERIOD/PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"] ))"
          if test "${?}" -ne 0;
          then
            debug_red "ERROR: Project: {${PROJECTS["${project_index}"]}}, job: {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}, can not calculate last_archives_count"
            let last_archives_count=1
          fi

          if test "${last_archives_count}" -lt 1;
          then
            let last_archives_count=1
          fi

          let last_archives_count+=2

          archive_data_level="size"
        fi

        debug_yellow "PROCESSING: Project: {${PROJECTS["${project_index}"]}}, job: {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}, attempts_count: {${attempts_count}}, last_archives_count: {${last_archives_count}}"

        PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]="$( date +"%s" )"

        get_backup_data "${project_index}" "${project_job_index}" "${last_archives_count}" "${archive_data_level}"
        get_backup_data_exit_value="${?}"

        if test "${get_backup_data_exit_value}" -eq 0;
        then
          let projects_jobs_remaining_count-=1
          projects_jobs_remaining["${project_job_index}"]="0"
          let project_job_index+=1
          continue
        fi

        if test "${get_backup_data_exit_value}" -eq 1;
        then
          let project_job_index+=1
          continue
        fi

        if test "${get_backup_data_exit_value}" -ne 0 -a "${get_backup_data_exit_value}" -ne 1;
        then
          let projects_jobs_remaining_count-=1
          projects_jobs_remaining["${project_job_index}"]="0"
          let project_job_index+=1
          continue
        fi
      fi

      let project_job_index+=1
    done

    let attempts_count+=1

    if test "${projects_jobs_remaining_count}" -lt 1;
    then
      debug_red "BREAK: Project: {${PROJECTS["${project_index}"]}} due to the lack of remaining tasks"
      break
    fi

    jobs_processing_curre_date="$( date +"%s" )"
    let jobs_processing_diffe_date=jobs_processing_curre_date-jobs_processing_start_date

    if test "${jobs_processing_diffe_date}" -ge "${ATTEMPTS_MAX_TIME}";
    then
      debug_red "BREAK: Project: {${PROJECTS["${project_index}"]}} due to the exceed the maximum time ${jobs_processing_diffe_date} s"
      break
    fi

    if test "${attempts_count}" -ge "${ATTEMPTS_MAX_ATTEMPTS}";
    then
      debug_red "BREAK: Project: {${PROJECTS["${project_index}"]}} due to the exceed attempts count ${attempts_count}"
      break
    fi

    sleep "${ATTEMPTS_PAUSE}"
  done
}

get_backup_data_handler_wrapper_in_case_of_run_in_new_process()
{
  local project_index
  project_index="${1}"

  local json_data_file
  json_data_file="${2}"

  # Локальные аналоги глобальных массивов необходимых из-за запуска в новом процессе
  local PROJECTS_JOBS_LAST_ARCHIVE_COUNT
  local PROJECTS_JOBS_LAST_ARCHIVE_NAME
  local PROJECTS_JOBS_LAST_ARCHIVE_DATE
  local PROJECTS_JOBS_LAST_ARCHIVE_SIZE
  declare -A PROJECTS_JOBS_LAST_ARCHIVE_COUNT
  declare -A PROJECTS_JOBS_LAST_ARCHIVE_NAME
  declare -A PROJECTS_JOBS_LAST_ARCHIVE_DATE
  declare -A PROJECTS_JOBS_LAST_ARCHIVE_SIZE

  local PROJECTS_JOBS_CHECK_START
  declare -A PROJECTS_JOBS_CHECK_START

  local PROJECTS_ERRORS_BACKUP_COUNT
  local PROJECTS_ERRORS_BACKUP
  declare -a PROJECTS_ERRORS_BACKUP_COUNT
  declare -A PROJECTS_ERRORS_BACKUP

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    # Инициализация PROJECTS_ERRORS_BACKUP_COUNT аналогично основному потоку
    let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]=0

    let project_job_index+=1
  done

  get_backup_data_handler "${project_index}"

  # Преобразование массивов в json и сохранение его в файле
  converting_backup_data "${project_index}" "${json_data_file}" "serialization"
}

# Выполняет преобразование следующих массивов в json и обратно:
#   - PROJECTS_JOBS_CHECK_START
#   - PROJECTS_JOBS_LAST_ARCHIVE_COUNT
#   - PROJECTS_JOBS_LAST_ARCHIVE_NAME
#   - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#   - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
#   - PROJECTS_ERRORS_BACKUP_COUNT
#   - PROJECTS_ERRORS_BACKUP
# Input variables:
#   - ${1} - project index in PROJECTS array
#   - ${2} - file path to json data file
#   - ${3} - direction (serialization or deserialization)
# Global variables:
#   - RO
#     - PROJECTS_JOBS_COUNT
#   - RW
#     - PROJECTS_ERRORS_COMMON_COUNT
#     - PROJECTS_ERRORS_COMMON
#     - PROJECTS_JOBS_CHECK_START
#     - PROJECTS_JOBS_LAST_ARCHIVE_COUNT
#     - PROJECTS_JOBS_LAST_ARCHIVE_NAME
#     - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
converting_backup_data()
{
  local project_index
  project_index="${1}"

  local json_data_file
  json_data_file="${2}"

  local direction
  direction="${3}"

  # Залокаливание остальных переменных
  local backup_data_in_json
  local job_errors_json_data
  local job_archives_json_data
  local escaped_for_json_string

  local project_job_index
  local project_error_backup_index
  local project_job_last_archive_index
  local job_errors_length
  local job_errors_index
  local deserialization_erros_count

#  Формат:
#    {
#      "jobs":
#      {
#        "0":
#        {
#          "check_start": "1556308123",
#          "archives":
#          {
#            "0":
#            {
#              "name": "name_1",
#              "size": "size_1",
#              "date": "date_1"
#            },
#            "1":
#            {
#              "name": "name_2",
#              "size": "size_2",
#              "date": "date_2"
#            }
#          },
#          "job_errors":
#          [
#            "error_1",
#            "error_2"
#          ]
#        },
#        "1":
#        {
#          "check_start": "1556308143",
#          "archives":
#          {
#            "0":
#            {
#              "name": "name_1",
#              "size": "size_1",
#              "date": "date_1"
#            },
#            "1":
#            {
#              "name": "name_2",
#              "size": "size_2",
#              "date": "date_2"
#            }
#          },
#          "job_errors":
#          [
#            "error_3",
#            "error_4"
#          ]
#        }
#      }
#    }

  # serialization
  if test "${direction}" == "serialization";
  then
    backup_data_in_json=""
    let project_job_index=0
    while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
    do
      job_errors_json_data=""

      let project_error_backup_index=0
      while test "${project_error_backup_index}" -lt "${PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]}";
      do
        escaped_for_json_string="$( escape_chars_for_json "${PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]}" )"
        escaped_for_json_string="$( escape_new_line "${escaped_for_json_string}" )"

        if test -z "${job_errors_json_data}";
        then
          job_errors_json_data="\"${escaped_for_json_string}\""
        else
          job_errors_json_data="${job_errors_json_data}, \"${escaped_for_json_string}\""
        fi

        let project_error_backup_index+=1
      done

      job_archives_json_data=""

      let project_job_last_archive_index=0
      while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
      do
        if test -z "${job_archives_json_data}";
        then
          job_archives_json_data="\"${project_job_last_archive_index}\": { \"name\": \"${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${project_job_last_archive_index}"]}\", \"date\": \"${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\", \"size\":\"${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\" }"
        else
          job_archives_json_data="${job_archives_json_data}, \"${project_job_last_archive_index}\": { \"name\": \"${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${project_job_last_archive_index}"]}\", \"date\": \"${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\", \"size\":\"${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\" }"
        fi

        let project_job_last_archive_index+=1
      done

      if test -z "${backup_data_in_json}";
      then
        backup_data_in_json="\"${project_job_index}\": { \"check_start\": \"${PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]}\", \"archives\": { ${job_archives_json_data} }, \"job_errors\": [ ${job_errors_json_data} ] }"
      else
        backup_data_in_json="${backup_data_in_json}, \"${project_job_index}\": { \"check_start\": \"${PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]}\", \"archives\": { ${job_archives_json_data} }, \"job_errors\": [ ${job_errors_json_data} ] }"
      fi

      let project_job_index+=1
    done

    printf "%s" "{ \"jobs\": { ${backup_data_in_json} } }" > "${json_data_file}"
  fi


  # deserialization
  if test "${direction}" == "deserialization";
  then
    backup_data_in_json="$( < "${json_data_file}" )"
    if test "${?}" -ne 0;
    then
      let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
      let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot get data of backups from json file. Didn't check for late backups!"

      return 1
    fi

    let project_job_index=0
    let deserialization_erros_count=0
    while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
    do
      PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].check_start" )"
      if test "${?}" -ne 0;
      then
        let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
        let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
        PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot parse data (jobs[].check_start) of backups from json file. Didn't check for late backups!"

        let project_job_index+=1
        let deserialization_erros_count+=1
        continue
      fi

      PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].archives | length" )"
      if test "${?}" -ne 0;
      then
        let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
        let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
        PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot parse data (jobs[].archives | length) of backups from json file. Didn't check for late backups!"

        let project_job_index+=1
        let deserialization_erros_count+=1
        continue
      fi

      let project_job_last_archive_index=0
      while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
      do
        PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${project_job_last_archive_index}"]="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].archives[\"${project_job_last_archive_index}\"].name" )"

        PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].archives[\"${project_job_last_archive_index}\"].date" )"

        PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].archives[\"${project_job_last_archive_index}\"].size" )"

        let project_job_last_archive_index+=1
      done


      job_errors_length="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].job_errors | length" )"
      if test "${?}" -ne 0;
      then
        let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
        let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
        PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot parse data (jobs[].job_errors | length) of backups from json file. Didn't check for late backups!"

        let project_job_index+=1
        let deserialization_erros_count+=1
        continue
      fi

      let job_errors_index=0
      let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=job_errors_length
      while test "${project_error_backup_index}" -lt "${PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]}";
      do
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="$( printf "%s" "${backup_data_in_json}" | jq -r ".jobs[\"${project_job_index}\"].job_errors[${job_errors_index}]" )"
        if test "${?}" -ne 0;
        then
          let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
          let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
          PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot parse data (jobs[].job_errors[]) of backups from json file. Didn't check for late backups!"
        fi

        let job_errors_index+=1
        let project_error_backup_index+=1
      done

      let project_job_index+=1
    done

    if test "${deserialization_erros_count}" -ne 0;
    then
      return 1
    fi
  fi
}

# Выполняет проверку что:
#   - (PROJECTS_JOBS_CHECK_START - PROJECTS_JOBS_LAST_ARCHIVE_DATE) не больше PROJECTS_JOBS_THRESHOLD_AGE
#   - (PROJECTS_JOBS_CHECK_START - PROJECTS_JOBS_LAST_ARCHIVE_DATE) не больше PROJECTS_JOBS_STORAGE_LIMIT
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_JOBS
#     - PROJECTS_JOBS_COUNT
#     - PROJECTS_JOBS_STATE
#     - PROJECTS_JOBS_THRESHOLD_AGE
#     - PROJECTS_JOBS_STORAGE_LIMIT
#     - PROJECTS_JOBS_CHECK_START
#     - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#     - CHECK_MODE
#   - RW
#     - PROJECTS_WARNINGS_BACKUP_COUNT
#     - PROJECTS_WARNINGS_BACKUP
#     - PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT
#     - PROJECTS_WARNINGS_BACKUP_DISABLED
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
check_last_backup_archive_date()
{
  local project_index
  project_index="${1}"

  local project_job_index
  local project_job_last_archive_index

  # Залокаливание остальных переменных
  local current_job_last_archive_index
  local current_job_last_archive_date_in_seconds
  local current_job_check_start_in_seconds
  local current_job
  local allowable_project_job_threshold_age
  local allowable_project_job_storage_limit
  local current_project_job_threshold_age
  local current_project_job_storage_limit

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    let current_job_last_archive_index=-1
    let project_job_last_archive_index=0
    while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
    do
      if test "${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}" -gt "${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${current_job_last_archive_index}"]:-0}";
      then
        let current_job_last_archive_index=project_job_last_archive_index
      fi

      let project_job_last_archive_index+=1
    done

    current_job_last_archive_date_in_seconds=""
    current_job_last_archive_date_in_seconds="${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${current_job_last_archive_index}"]}"

    current_job_check_start_in_seconds=""
    current_job_check_start_in_seconds="${PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]}"

    if test -n "${current_job_last_archive_date_in_seconds}";
    then
      current_job=""
      current_job="${PROJECTS_JOBS["${project_index},${project_job_index}"]}"

      allowable_project_job_threshold_age=""
      allowable_project_job_storage_limit=""
      allowable_project_job_threshold_age="${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}"
      allowable_project_job_storage_limit="${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}"

      current_project_job_threshold_age=""
      let current_project_job_threshold_age=current_job_check_start_in_seconds-current_job_last_archive_date_in_seconds
      let current_project_job_threshold_age=current_project_job_threshold_age/60
      let current_project_job_threshold_age=current_project_job_threshold_age/60

      current_project_job_storage_limit=""
      let current_project_job_storage_limit=current_job_check_start_in_seconds-current_job_last_archive_date_in_seconds
      let current_project_job_storage_limit=current_project_job_storage_limit/60
      let current_project_job_storage_limit=current_project_job_storage_limit/60
      let current_project_job_storage_limit=current_project_job_storage_limit/24

      debug_green "INFO: Project: {${PROJECTS["${project_index}"]}}, job: {${current_job}}, last_archive_date: {$( date --date="@${current_job_last_archive_date_in_seconds}" )}, threshold_age: {${current_project_job_threshold_age}}, storage_limit: {${current_project_job_storage_limit}}"

      check_to_non_negative_number_format "${current_project_job_threshold_age}"
      if test "${?}" -eq 0;
      then
        if test "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" != "disable";
        then
          if test "${current_project_job_threshold_age}" -gt "${allowable_project_job_threshold_age}";
          then
            let PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
            let project_warning_backup_index=PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
            PROJECTS_WARNINGS_BACKUP["${project_index},${project_job_index},${project_warning_backup_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${current_job}} is too late. Last run was ${current_project_job_threshold_age} hrs ago. Allowed limit is ${allowable_project_job_threshold_age} hrs!"
          fi
        else
          if test "${CHECK_MODE}" == "check-disabled-backups-storage-limit";
          then
            if test "${current_project_job_storage_limit}" -gt "${allowable_project_job_storage_limit}";
            then
              let PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT["${project_index},${project_job_index}"]+=1
              let project_warning_backup_disabled_index=PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT["${project_index},${project_job_index}"]-1
              PROJECTS_WARNINGS_BACKUP_DISABLED["${project_index},${project_job_index},${project_warning_backup_disabled_index}"]="Attention: backup storage period has expired for job {${current_job}} on borg storage {$(hostname)}. Last run was ${current_project_job_storage_limit} days ago. Allowed storage limit is ${allowable_project_job_storage_limit} days!"
            fi
          fi
        fi
      else
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${current_job}} last backup time is in the future!"
      fi
    fi

    let project_job_index+=1
  done
}

# Выполняет проверку что:
#   - PROJECTS_JOBS_LAST_ARCHIVE_SIZE не меньше PROJECTS_JOBS_MIN_SIZE
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_JOBS
#     - PROJECTS_JOBS_COUNT
#     - PROJECTS_JOBS_STATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
#     - PROJECTS_JOBS_MIN_SIZE
#   - RW
#     - PROJECTS_WARNINGS_BACKUP_COUNT
#     - PROJECTS_WARNINGS_BACKUP
check_last_backup_archive_size()
{
  local project_index
  project_index="${1}"

  local project_job_index
  local project_job_last_archive_index

  # Залокаливание остальных переменных
  local current_job_last_archive_index
  local current_job_last_archive_size
  local current_job_min_size
  local current_job

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    let current_job_last_archive_index=-1
    let project_job_last_archive_index=0
    while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
    do
      if test "${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}" -gt "${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${current_job_last_archive_index}"]:-0}";
      then
        let current_job_last_archive_index=project_job_last_archive_index
      fi

      let project_job_last_archive_index+=1
    done

    current_job_last_archive_size=""
    current_job_last_archive_size="${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${current_job_last_archive_index}"]}"

    current_job_min_size=""
    current_job_min_size="${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}"

    if test -n "${current_job_last_archive_size}";
    then
      current_job=""
      current_job="${PROJECTS_JOBS["${project_index},${project_job_index}"]}"

      if test "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" != "disable";
      then
        debug_green "INFO: Project: {${PROJECTS["${project_index}"]}}, job: {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}, last_archive_size: {${current_job_last_archive_size}}, min_size: {${current_job_min_size}}"

        if test "${current_job_last_archive_size}" -lt "${current_job_min_size}";
        then
          let PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
          let project_warning_backup_index=PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
          PROJECTS_WARNINGS_BACKUP["${project_index},${project_job_index},${project_warning_backup_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${current_job}} last archive size was less than expected. It was $( number_to_string_with_size "${current_job_last_archive_size}" ) (${current_job_last_archive_size} bytes) in archive {${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${current_job_last_archive_index}"]}} and expected size was $( number_to_string_with_size "${current_job_min_size}" ) (${current_job_min_size} bytes) or more!"
        fi
      fi
    fi

    let project_job_index+=1
  done
}

# Выполняет проверку что:
#   -  (1 - last(PROJECTS_JOBS_LAST_ARCHIVE_SIZE)/max(PROJECTS_JOBS_LAST_ARCHIVE_SIZE))*100 не больше PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE
#      где, (1 - last(PROJECTS_JOBS_LAST_ARCHIVE_SIZE)/max(PROJECTS_JOBS_LAST_ARCHIVE_SIZE))*100 - уменьшение размера последнего архива в % по сравнению с размером архива, имеющего максимальный размер в полученном списке архивов
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_JOBS
#     - PROJECTS_JOBS_COUNT
#     - PROJECTS_JOBS_STATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_DATE
#     - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
#     - PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE
#   - RW
#     - PROJECTS_WARNINGS_BACKUP_COUNT
#     - PROJECTS_WARNINGS_BACKUP
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
check_last_backup_archive_size_decrease()
{
  local project_index
  project_index="${1}"

  local project_job_index
  local project_job_last_archive_index

  # Залокаливание остальных переменных
  local current_job_last_archive_index
  local current_job_last_archive_size
  local current_job_archive_with_max_size_index
  local current_job_archive_size_with_max_size
  local current_job_allowable_decrease_size
  local current_job_actual_decrease_size

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    let current_job_last_archive_index=-1
    let current_job_archive_with_max_size_index=-1
    let project_job_last_archive_index=0
    while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
    do
      if test "${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}" -gt "${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${current_job_last_archive_index}"]:-0}";
      then
        let current_job_last_archive_index=project_job_last_archive_index
      fi

      if test "${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]}" -gt "${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${current_job_archive_with_max_size_index}"]:-0}";
      then
        let current_job_archive_with_max_size_index=project_job_last_archive_index
      fi

      let project_job_last_archive_index+=1
    done

    current_job_last_archive_size=""
    current_job_last_archive_size="${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${current_job_last_archive_index}"]}"

    current_job_archive_size_with_max_size=""
    current_job_archive_size_with_max_size="${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${current_job_archive_with_max_size_index}"]}"

    current_job_allowable_decrease_size=""
    current_job_allowable_decrease_size="${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}"

    if test -n "${current_job_last_archive_size}" -a -n "${current_job_archive_size_with_max_size}";
    then
      debug_green "INFO: Project: {${PROJECTS["${project_index}"]}}, job: {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}, last_archive_size: {${current_job_last_archive_size}}, archive_size_with_max_size: {${current_job_archive_size_with_max_size}}"

      current_job_actual_decrease_size="$(( (current_job_archive_size_with_max_size-current_job_last_archive_size)*100/current_job_archive_size_with_max_size ))"
      if test "${?}" -ne 0;
      then
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} can not calculate the actual_decrease_size!"

        let project_job_index+=1
        continue
      fi

      if test "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" != "disable";
      then
        debug_green "INFO: Project: {${PROJECTS["${project_index}"]}}, job: {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}, actual_decrease_size: {${current_job_actual_decrease_size}}, allowable_decrease_size: {${current_job_allowable_decrease_size}}, last_archive_size: {${current_job_last_archive_size}}, archive_size_with_max_size: {${current_job_archive_size_with_max_size}}"

        if test "${current_job_actual_decrease_size}" -gt "${current_job_allowable_decrease_size}";
        then
          let PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
          let project_warning_backup_index=PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
          PROJECTS_WARNINGS_BACKUP["${project_index},${project_job_index},${project_warning_backup_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} last archive size decreased beyond expectation. It decreased by ${current_job_actual_decrease_size}% ( from $( number_to_string_with_size "${current_job_archive_size_with_max_size}" ) in archive {${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${current_job_archive_with_max_size_index}"]}} to $( number_to_string_with_size "${current_job_last_archive_size}" ) in archive {${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${current_job_last_archive_index}"]}} ), but expected no more than ${current_job_allowable_decrease_size}%!"
        fi
      fi
    fi

    let project_job_index+=1
  done
}

# Выполняет получение данных, проверку даты архивов и отправку алертов
# Все действия выполняются последовательно
# Input variables:
#   - ${1} - project index in PROJECTS array
do_check_archive_date()
{
  local project_index
  project_index="${1}"

  # Получение данных о бэкапах
  get_backup_data_handler "${project_index}"

  # Выполнение проверок:
  #   - что (PROJECTS_JOBS_CHECK_START - PROJECTS_JOBS_LAST_ARCHIVE_DATE)
  #     не больше PROJECTS_JOBS_THRESHOLD_AGE и не больше PROJECTS_JOBS_STORAGE_LIMIT
  #     для каждого задания каждого проекта
  check_last_backup_archive_date "${project_index}"

  # Отправка попроектных алертов и создание тикетов
  alerts_about_projects_common_warnings "${project_index}"
  alerts_about_projects_common_erros "${project_index}"

  alerts_about_projects_backup_warnings "${project_index}"
  alerts_about_projects_backup_errors "${project_index}"
  create_tickets_about_disabled_backups "${project_index}"
}

# Выполняет получение данных, проверку размера архивов и отправку алертов
# Все действия выполняются последовательно
# Input variables:
#   - ${1} - project index in PROJECTS array
do_check_archive_size()
{
  local project_index
  project_index="${1}"

  # Получение данных о бэкапах
  get_backup_data_handler "${project_index}"

  # Выполнение проверок:
  #   - что (PROJECTS_JOBS_CHECK_START - PROJECTS_JOBS_LAST_ARCHIVE_DATE)
  #     не больше PROJECTS_JOBS_THRESHOLD_AGE и не больше PROJECTS_JOBS_STORAGE_LIMIT
  #     для каждого задания каждого проекта
  check_last_backup_archive_size "${project_index}"
  check_last_backup_archive_size_decrease "${project_index}"

  # Отправка попроектных алертов и создание тикетов
  alerts_about_projects_common_warnings "${project_index}"
  alerts_about_projects_common_erros "${project_index}"

  alerts_about_projects_backup_warnings "${project_index}"
  alerts_about_projects_backup_errors "${project_index}"
  create_tickets_about_disabled_backups "${project_index}"
}

# Выполняет получение данных, проверку даты архивов и отправку алертов
# Данные об архивах извлекаются параллельно, с распараллеливанием по проектам
# Проверка данных и отправка алертов выполняются последовательно
do_check_archive_date_with_parallel_per_project_data_acquisition()
{
  # Получение данных о бэкапах
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    json_data_file="${TEMP_DIR}/${TEMP_FILE_PREFIX}_backup_data_${PROJECTS["${project_index}"]}.json"

    touch "${json_data_file}"
    if test "${?}" -ne 0;
    then
      let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
      let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot touch json file with data of backups. Didn't check for late backups!"

      let project_index+=1
      continue
    fi

    chmod 0600 "${json_data_file}"
    if test "${?}" -ne 0;
    then
      let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
      let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot chmod json file with data of backups. Didn't check for late backups!"

      let project_index+=1
      continue
    fi

    get_backup_data_handler_wrapper_in_case_of_run_in_new_process "${project_index}" "${json_data_file}" &

    let project_index+=1
  done

  # Ожидание всех запущенных процессов получения данных о бэкапах
  wait > "/dev/null" 2>&1

  # Десериализация данных из json-файлов
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    json_data_file="${TEMP_DIR}/${TEMP_FILE_PREFIX}_backup_data_${PROJECTS["${project_index}"]}.json"

    converting_backup_data "${project_index}" "${json_data_file}" "deserialization"

    unlink "${json_data_file}"

    let project_index+=1
  done

  # Вывод полученных значений:
  #   - PROJECTS
  #   - PROJECTS_DIR
  #   - PROJECTS_JOBS
  #   - PROJECTS_JOBS_DIR
  #   - PROJECTS_JOBS_STATE
  #   - PROJECTS_JOBS_THRESHOLD_AGE
  #   - PROJECTS_JOBS_STORAGE_LIMIT
  #   - PROJECTS_JOBS_MIN_SIZE
  #   - PROJECTS_JOBS_CHECK_START
  #   - PROJECTS_JOBS_LAST_ARCHIVE_NAME
  #   - PROJECTS_JOBS_LAST_ARCHIVE_DATE
  #   - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
  if test "${DEBUG}" == "yes";
  then
    debug_green "projects:"
    let project_index=0
    while test "${project_index}" -lt "${PROJECTS_COUNT}";
    do
      debug_green "  - ${PROJECTS["${project_index}"]}:"
      debug_green "      dir: \"${PROJECTS_DIR["${project_index}"]}\""
      debug_green "      jobs:"

      let project_job_index=0
      while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
      do
        debug_green "        - ${PROJECTS_JOBS["${project_index},${project_job_index}"]}:"
        debug_green "            dir:           \"${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}\""
        debug_green "            state:         \"${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}\""
        debug_green "            max_age:       \"${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}\""
        debug_green "            store_limit:   \"${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}\""
        debug_green "            min_size:      \"${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}\""
        debug_green "            size_decrease: \"${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}\""
        debug_green "            check_start:   \"${PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]}\""
        debug_green "            archives:"

        let project_job_last_archive_index=0
        while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
        do
          debug_green "             - ${project_job_last_archive_index}:"
          debug_green "                 name: \"${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${project_job_last_archive_index}"]}\""
          debug_green "                 date: \"${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\""
          debug_green "                 size: \"${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\""

          let project_job_last_archive_index+=1
        done

        let project_job_index+=1
      done

      let project_index+=1
    done
  fi

  # Выполнение проверок:
  #   - что (PROJECTS_JOBS_CHECK_START - PROJECTS_JOBS_LAST_ARCHIVE_DATE)
  #     не больше PROJECTS_JOBS_THRESHOLD_AGE и не больше PROJECTS_JOBS_STORAGE_LIMIT
  #     для каждого задания каждого проекта
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    check_last_backup_archive_date "${project_index}"

    let project_index+=1
  done

  # Отправка попроектных алертов и создание тикетов
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    alerts_about_projects_common_warnings "${project_index}"
    alerts_about_projects_common_erros "${project_index}"

    alerts_about_projects_backup_warnings "${project_index}"
    alerts_about_projects_backup_errors "${project_index}"
    create_tickets_about_disabled_backups "${project_index}"

    let project_index+=1
  done
}

# Выполняет получение данных, проверку размера архивов и отправку алертов
# Данные об архивах извлекаются параллельно, с распараллеливанием по проектам
# Проверка данных и отправка алертов выполняются последовательно
do_check_archive_size_with_parallel_per_project_data_acquisition()
{
  # Получение данных о бэкапах
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    json_data_file="${TEMP_DIR}/${TEMP_FILE_PREFIX}_backup_data_${PROJECTS["${project_index}"]}.json"

    touch "${json_data_file}"
    if test "${?}" -ne 0;
    then
      let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
      let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot touch json file with data of backups. Didn't check for late backups!"

      let project_index+=1
      continue
    fi

    chmod 0600 "${json_data_file}"
    if test "${?}" -ne 0;
    then
      let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
      let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: cannot chmod json file with data of backups. Didn't check for late backups!"

      let project_index+=1
      continue
    fi

    get_backup_data_handler_wrapper_in_case_of_run_in_new_process "${project_index}" "${json_data_file}" &

    let project_index+=1
  done

  # Ожидание всех запущенных процессов получения данных о бэкапах
  wait > "/dev/null" 2>&1

  # Десериализация данных из json-файлов
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    json_data_file="${TEMP_DIR}/${TEMP_FILE_PREFIX}_backup_data_${PROJECTS["${project_index}"]}.json"

    converting_backup_data "${project_index}" "${json_data_file}" "deserialization"

    unlink "${json_data_file}"

    let project_index+=1
  done

  # Вывод полученных значений:
  #   - PROJECTS
  #   - PROJECTS_DIR
  #   - PROJECTS_JOBS
  #   - PROJECTS_JOBS_DIR
  #   - PROJECTS_JOBS_STATE
  #   - PROJECTS_JOBS_THRESHOLD_AGE
  #   - PROJECTS_JOBS_STORAGE_LIMIT
  #   - PROJECTS_JOBS_MIN_SIZE
  #   - PROJECTS_JOBS_CHECK_START
  #   - PROJECTS_JOBS_LAST_ARCHIVE_NAME
  #   - PROJECTS_JOBS_LAST_ARCHIVE_DATE
  #   - PROJECTS_JOBS_LAST_ARCHIVE_SIZE
  if test "${DEBUG}" == "yes";
  then
    debug_green "projects:"
    let project_index=0
    while test "${project_index}" -lt "${PROJECTS_COUNT}";
    do
      debug_green "  - ${PROJECTS["${project_index}"]}:"
      debug_green "      dir: \"${PROJECTS_DIR["${project_index}"]}\""
      debug_green "      jobs:"

      let project_job_index=0
      while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
      do
        debug_green "        - ${PROJECTS_JOBS["${project_index},${project_job_index}"]}:"
        debug_green "            dir:           \"${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}\""
        debug_green "            state:         \"${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}\""
        debug_green "            max_age:       \"${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}\""
        debug_green "            store_limit:   \"${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}\""
        debug_green "            min_size:      \"${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}\""
        debug_green "            size_decrease: \"${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}\""
        debug_green "            check_start:   \"${PROJECTS_JOBS_CHECK_START["${project_index},${project_job_index}"]}\""
        debug_green "            archives:"

        let project_job_last_archive_index=0
        while test "${project_job_last_archive_index}" -lt "${PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]}";
        do
          debug_green "             - ${project_job_last_archive_index}:"
          debug_green "                 name: \"${PROJECTS_JOBS_LAST_ARCHIVE_NAME["${project_index},${project_job_index},${project_job_last_archive_index}"]}\""
          debug_green "                 date: \"${PROJECTS_JOBS_LAST_ARCHIVE_DATE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\""
          debug_green "                 size: \"${PROJECTS_JOBS_LAST_ARCHIVE_SIZE["${project_index},${project_job_index},${project_job_last_archive_index}"]}\""

          let project_job_last_archive_index+=1
        done

        let project_job_index+=1
      done

      let project_index+=1
    done
  fi

  # Выполнение проверок:
  #   - что PROJECTS_JOBS_LAST_ARCHIVE_SIZE не меньше PROJECTS_JOBS_MIN_SIZE
  #   - что (1 - last(PROJECTS_JOBS_LAST_ARCHIVE_SIZE)/max(PROJECTS_JOBS_LAST_ARCHIVE_SIZE))*100 не больше PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE
  #     для каждого задания каждого проекта
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    check_last_backup_archive_size "${project_index}"
    check_last_backup_archive_size_decrease "${project_index}"

    let project_index+=1
  done

  # Отправка попроектных алертов и создание тикетов
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    alerts_about_projects_common_warnings "${project_index}"
    alerts_about_projects_common_erros "${project_index}"

    alerts_about_projects_backup_warnings "${project_index}"
    alerts_about_projects_backup_errors "${project_index}"
    create_tickets_about_disabled_backups "${project_index}"

    let project_index+=1
  done
}

# Выполняет проверку соответствия фактических и ожидаемых прав на каталоги с
# проектами и бэкапами
# Input variables:
#   - ${1} - project index in PROJECTS array
# Global variables:
#   - RO
#     - PROJECTS
#     - PROJECTS_DIR
#     - PROJECTS_JOBS
#     - PROJECTS_JOBS_COUNT
#     - PROJECTS_JOBS_DIR
#     - ONE_PROJECT
#     - ONE_PROJECT_USER
#   - RW
#     - PROJECTS_ERRORS_COMMON_COUNT
#     - PROJECTS_ERRORS_COMMON
#     - PROJECTS_ERRORS_BACKUP_COUNT
#     - PROJECTS_ERRORS_BACKUP
check_backups_access_rights()
{
  local project_index
  project_index="${1}"

  local project_job_index

  local expected_owner_user
  local expected_owner_group
  local expected_access_rights_dir
  local expected_access_rights_dir_octal
  local expected_access_rights_file
  local expected_access_rights_file_octal

  local current_project_dir_owner_user
  local current_project_dir_owner_group
  local current_project_dir_access_rights

  local current_job_dir_owner_user
  local current_job_dir_owner_group
  local current_job_dir_access_rights

  local find_out
  local find_out_count

  if test -z "${ONE_PROJECT}";
  then
    expected_owner_user="${PROJECTS["${project_index}"]}"
    expected_owner_group="${PROJECTS["${project_index}"]}"
  else
    expected_owner_user="${ONE_PROJECT_USER:-${ONE_PROJECT}}"
    expected_owner_group="${ONE_PROJECT_USER:-${ONE_PROJECT}}"
  fi
  expected_access_rights_dir="drwx------"
  expected_access_rights_dir_octal="0700"
  expected_access_rights_file="-rw-------"
  expected_access_rights_file_octal="0600"

  current_project_dir_owner_user=""
  current_project_dir_owner_user="$( stat --printf "%U" "${PROJECTS_DIR["${project_index}"]}" )"

  current_project_dir_owner_group=""
  current_project_dir_owner_group="$( stat --printf "%G" "${PROJECTS_DIR["${project_index}"]}" )"

  current_project_dir_access_rights=""
  current_project_dir_access_rights="$( stat --printf "%A" "${PROJECTS_DIR["${project_index}"]}" )"

  if test "${current_project_dir_owner_user}" != "${expected_owner_user}";
  then
    let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
    let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
    PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: actual owner user {${current_project_dir_owner_user}} for project directory {${PROJECTS_DIR["${project_index}"]}} do not match expected {${expected_owner_user}}!"
  fi

  if test "${current_project_dir_owner_group}" != "${expected_owner_group}";
  then
    let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
    let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
    PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: actual owner group {${current_project_dir_owner_group}} for project directory {${PROJECTS_DIR["${project_index}"]}} do not match expected {${expected_owner_group}}!"
  fi

  if test "${current_project_dir_access_rights}" != "${expected_access_rights_dir}";
  then
    let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
    let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
    PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: actual access rights {${current_project_dir_access_rights}} for project directory {${PROJECTS_DIR["${project_index}"]}} do not match expected {${expected_access_rights_dir}}!"
  fi

  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    current_job_dir_owner_user=""
    current_job_dir_owner_user="$( stat --printf "%U" "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" )"

    current_job_dir_owner_group=""
    current_job_dir_owner_group="$( stat --printf "%G" "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" )"

    current_job_dir_access_rights=""
    current_job_dir_access_rights="$( stat --printf "%A" "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" )"

    if test "${current_job_dir_owner_user}" != "${expected_owner_user}";
    then
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
      let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
      PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} actual owner user {${current_job_dir_owner_user}} for job directory {${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}} do not match expected {${expected_owner_user}}!"
    else
      find_out=""
      find_out="$( find "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" \! -path "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" \! -user "${expected_owner_user}" 2>/dev/null  | head -n 2 )"
      if test -n "${find_out}";
      then
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} owner user for some directories or files in job directory {${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}} do not match expected {${expected_owner_user}}!"
      fi
    fi

    if test "${current_job_dir_owner_group}" != "${expected_owner_group}";
    then
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
      let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
      PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} actual owner group {${current_job_dir_owner_group}} for job directory {${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}} do not match expected {${expected_owner_group}}!"
    else
      find_out=""
      find_out="$( find "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" \! -path "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" \! -group "${expected_owner_group}" 2>/dev/null | head -n 2 )"
      if test -n "${find_out}";
      then
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} owner group for some directories or files in job directory {${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}} do not match expected {${expected_owner_group}}!"
      fi
    fi

    if test "${current_job_dir_access_rights}" != "${expected_access_rights_dir}";
    then
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
      let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
      PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} actual access rights {${current_job_dir_access_rights}} for job directory {${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}} do not match expected {${expected_access_rights_dir}}!"
    else
      let find_out_count=0

      find_out=""
      find_out="$( find "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" \! -path "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" -type f \! -perm "${expected_access_rights_file_octal}" 2>/dev/null | head -n 2 )"
      if test -n "${find_out}";
      then
        let find_out_count+=1
      fi

      find_out=""
      find_out="$( find "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" \! -path "${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}" -type d \! -perm "${expected_access_rights_dir_octal}" 2>/dev/null  | head -n 2 )"
      if test -n "${find_out}";
      then
        let find_out_count+=1
      fi

      if test  "${find_out_count}" -ne 0;
      then
        let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]+=1
        let project_error_backup_index=PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]-1
        PROJECTS_ERRORS_BACKUP["${project_index},${project_job_index},${project_error_backup_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}} access rights for some directories or files in job directory {${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}} do not match expected (for directories - {${expected_access_rights_dir}}, for files - {${expected_access_rights_file}})!"
      fi
    fi

    let project_job_index+=1
  done
}

# Выполняет проверку соответствия фактических и ожидаемых прав на корневой
# каталог с бэкапами
# Global variables:
#   - RO
#     - BACKUP_DIRECTORY
#     - BACKUP_DIRECTORY_EXPECTED_OWNER_USER
#     - BACKUP_DIRECTORY_EXPECTED_OWNER_GROUP
#     - BACKUP_DIRECTORY_EXPECTED_ACCESS_RIGHTS
check_backup_directory_access_rights()
{
  local current_backup_directory_owner_user
  local current_backup_directory_owner_group
  local current_backup_directory_access_rights

  current_backup_directory_owner_user=""
  current_backup_directory_owner_user="$( stat --printf "%U" "${BACKUP_DIRECTORY}" )"

  current_backup_directory_owner_group=""
  current_backup_directory_owner_group="$( stat --printf "%G" "${BACKUP_DIRECTORY}" )"

  current_backup_directory_access_rights=""
  current_backup_directory_access_rights="$( stat --printf "%A" "${BACKUP_DIRECTORY}" )"

  if test "${current_backup_directory_owner_user}" != "${BACKUP_DIRECTORY_EXPECTED_OWNER_USER}";
  then
    let COMMON_ERRORS_COUNT+=1
    let common_errors_index=COMMON_ERRORS_COUNT-1

    COMMON_ERRORS["${common_errors_index}"]="ERROR: actual owner user {${current_backup_directory_owner_user}} for root directory of backups {${BACKUP_DIRECTORY}} do not match expected {${BACKUP_DIRECTORY_EXPECTED_OWNER_USER}}!"
  fi

  if test "${current_backup_directory_owner_group}" != "${BACKUP_DIRECTORY_EXPECTED_OWNER_GROUP}";
  then
    let COMMON_ERRORS_COUNT+=1
    let common_errors_index=COMMON_ERRORS_COUNT-1

    COMMON_ERRORS["${common_errors_index}"]="ERROR: actual owner group {${current_backup_directory_owner_group}} for root directory of backups {${BACKUP_DIRECTORY}} do not match expected {${BACKUP_DIRECTORY_EXPECTED_OWNER_GROUP}}!"
  fi

  if test "${current_backup_directory_access_rights}" != "${BACKUP_DIRECTORY_EXPECTED_ACCESS_RIGHTS}";
  then
    let COMMON_ERRORS_COUNT+=1
    let common_errors_index=COMMON_ERRORS_COUNT-1

    COMMON_ERRORS["${common_errors_index}"]="ERROR: actual access rights {${current_backup_directory_access_rights}} for root directory of backups {${BACKUP_DIRECTORY}} do not match expected {${BACKUP_DIRECTORY_EXPECTED_ACCESS_RIGHTS}}!"
  fi
}

# Отображает версию скрипта
print_version()
{
  printf "%s\n" "${VERSION}"

  return 0
}

# Отображает справку по использованию скрипта
print_reference()
{
  cat <<EOF
usage:
  $( basename "${0}" ) {-d|--backup-dir=<root_directory_of_backups>}
  [-c|--config=<path_to_config_file>]
  [-t|--threshold-age=<threshold_age_by_default>]
  [-p|--one-project=<project_name>]
  [   --one-project-user=<user_under_which_backups_are_stored>]
  [   --check-disabled-backups-storage-limit]
  [   --check-access-rights]
  [   --check-archive-size=<check_run_period>]
  [-o|--message-out=<message_output_direction>]
  [   --attempts-max-time=<max_time_for_attempts>]
  [   --attempts-pause=<pause_beetwen_attempts>]
  [   --stop]
  [   --unstop]
  [   --debug]
  [-v|--version]
  [-h|--help]

Mandatory arguments:
  -d, --backup-dir                            defines path to root directory of backups

Optional arguments:
  -c, --config                                defines path to configuration file

  -t, --threshold-age                         defines default threshold backup age value

  -p, --one-project                           change mode to 'one project' - disables the
                                              processing of projects in the configuration file
                                              and defines name of the single project

      --one-project-user                      define user under which backups are stored in
                                              'one project' mode. if not specified, will be
                                              used the project name defined in --one-project option

      --check-disabled-backups-storage-limit  enables the mode in which the limit of storage for
                                              disabled backups is checked, in this mode a ticket
                                              is created and other checks are not made

      --check-access-rights                   enables the mode in which the checks access rights
                                              for project and jobs directories, in this mode
                                              other checks are not made

      --check-archive-size                    enables the mode in which the checks archives size,
                                              in this mode other checks are not made. As a value,
                                              you must specify the period of the check run in hours.
                                              Based on this period, will be calculated the number
                                              of archives for which need to get data. This period
                                              can be specified more than real for deeper data analysis

      --parallelize-all-operations            in normal mode only data extraction operations from
                                              Borg-repositories are parallelized (per project).
                                              This option also allows to parallelize the data check
                                              operations and send alerts operations

  -o, --message-out                           defines message output direction of the script, if
                                              set to 'stdout' then messages will be send to
                                              standard output, otherwise messages will be send to
                                              the alert backend and/or ticketing

      --attempts-max-time                     maximum time in seconds for all attempts to get data
                                              about backups (per project) in case of correctable
                                              errors (lock timeout and etc)

      --attempts-pause                        pause in seconds beetwen attempts to get data about
                                              backups (per project) in case of correctable errors
                                              (lock timeout and etc)

      --stop                                  create directory that signals stop borg repositories
                                              processing, processing will not be stopped immediately,
                                              already started processes of extracting data from
                                              repositories will be completed to the end, data will
                                              not be extracted from the following repositories and
                                              the process will be completed

      --unstop                                remove stop directory created by --stop

      --debug                                 enables print internal data and actions

  -v, --version                               show version
  -h, --help                                  print this usage reference
EOF
  return 0
}

################################################################################
# Точка входа

# Объявления и определения переменных
BACKUP_DIRECTORY=""
CONFIG_FILE_PATH=""
ONE_PROJECT=""
ONE_PROJECT_USER=""
CHECK_MODE=""
OUTPUT_DIRECTION=""
# Период выполнения проверки размера архивов, единица измерения - часы
CHECK_ARCHIVE_SIZE_PERIOD=""
PARALLELIZE_ALL_OPERATIONS=""

CONFIG_FILE_CONTENT=""

TEMP_DIR_NAME=""
TEMP_DIR=""

# Итерируются через "${project_index}"
let PROJECTS_COUNT=0
declare -a PROJECTS
declare -a PROJECTS_DIR
declare -a PROJECTS_JOBS_COUNT

# Итерируются через "${project_index},${project_job_index}"
declare -A PROJECTS_JOBS
declare -A PROJECTS_JOBS_DIR
declare -A PROJECTS_JOBS_CHECK_START
declare -A PROJECTS_JOBS_STATE
declare -A PROJECTS_JOBS_THRESHOLD_AGE
declare -A PROJECTS_JOBS_STORAGE_LIMIT
declare -A PROJECTS_JOBS_MIN_SIZE
declare -A PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE

# Массивы с датами создания и размерами последних архивов резервных копий
# Итерируется через "${project_index},${project_job_index}"
declare -A PROJECTS_JOBS_LAST_ARCHIVE_COUNT
# Итерируются через "${project_index},${project_job_index},${project_job_last_archive_index}"
declare -A PROJECTS_JOBS_LAST_ARCHIVE_NAME
declare -A PROJECTS_JOBS_LAST_ARCHIVE_DATE
declare -A PROJECTS_JOBS_LAST_ARCHIVE_SIZE

# Массивы с сообщениями о попроектных проблемах
# Итерируются через "${project_index},${project_warning_common_index}"
declare -a PROJECTS_WARNINGS_COMMON_COUNT
declare -A PROJECTS_WARNINGS_COMMON

# Итерируются через "${project_index},${project_error_common_index}"
declare -a PROJECTS_ERRORS_COMMON_COUNT
declare -A PROJECTS_ERRORS_COMMON

# Итерируются через "${project_index},${project_job_index},${project_warning_backup_index}"
declare -a PROJECTS_WARNINGS_BACKUP_COUNT
declare -A PROJECTS_WARNINGS_BACKUP
# Итерируются через "${project_index},${project_job_index},${project_warning_backup_disabled_index}"
declare -a PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT
declare -A PROJECTS_WARNINGS_BACKUP_DISABLED
# Итерируются через "${project_index},${project_job_index},${project_error_backup_index}"
declare -a PROJECTS_ERRORS_BACKUP_COUNT
declare -A PROJECTS_ERRORS_BACKUP

# Массивы с сообщениями об общих проблемах
# Итерируются через "${common_warnings_index}
let COMMON_WARNINGS_COUNT=0
declare -a COMMON_WARNINGS

# Итерируются через "${common_errors_index}
let COMMON_ERRORS_COUNT=0
declare -a COMMON_ERRORS

# Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options d:c:t:p:o:vh --longoptions ,backup-dir:,config:,threshold-age:,one-project:,one-project-user:,check-disabled-backups-storage-limit,check-access-rights,check-archive-size:,parallelize-all-operations,message-out:,attempts-max-time:,attempts-pause:,stop,unstop,debug,version,help -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  send_alert "shop-app" "catastrophic" "ERROR: Script {borg_jobs_monitoring} received unknown arguments. Didn't check for late backups!"
  send_alert "shop-app" "catastrophic" "ERROR: Script {borg_jobs_monitoring} received unknown arguments. Didn't check for late backups!" "stdout"
  exit 0
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -d|--backup-dir)                           BACKUP_DIRECTORY="${2}";                                           shift 2;;
    -c|--config)                               CONFIG_FILE_PATH="${2}";                                           shift 2;;
    -t|--threshold-age)                        THRESHOLD_AGE_BY_DEFAULT="${2}";                                   shift 2;;
    -p|--one-project)                          ONE_PROJECT="${2}";                                                shift 2;;
       --one-project-user)                     ONE_PROJECT_USER="${2}";                                           shift 2;;
       --check-disabled-backups-storage-limit) CHECK_MODE="check-disabled-backups-storage-limit";                 shift 1;;
       --check-access-rights)                  CHECK_MODE="check-access-rights";                                  shift 1;;
       --check-archive-size)                   CHECK_MODE="check-archive-size"; CHECK_ARCHIVE_SIZE_PERIOD="${2}"; shift 2;;
       --parallelize-all-operations)           PARALLELIZE_ALL_OPERATIONS="yes";                                  shift 1;;
    -o|--message-out)                          OUTPUT_DIRECTION="${2}";                                           shift 2;;
       --attempts-max-time)                    ATTEMPTS_MAX_TIME="${2}";                                          shift 2;;
       --attempts-pause)                       ATTEMPTS_PAUSE="${2}";                                             shift 2;;
       --stop)                                 mkdir "${STOP_BORG_REPO_PROCESSING_DIR}";                          exit  0;;
       --unstop)                               rmdir "${STOP_BORG_REPO_PROCESSING_DIR}";                          exit  0;;
       --debug)                                DEBUG="yes";                                                       shift 1;;
    -v|--version)                              print_version;                                                     exit  0;;
    -h|--help)                                 print_reference;                                                   exit  0;;
    *) break ;;
  esac
done

# Обработка и проверка данных, поступивших через командную строку
BACKUP_DIRECTORY="$( trim_trailing_spaces "${BACKUP_DIRECTORY}" )"
CONFIG_FILE_PATH="$( trim_trailing_spaces "${CONFIG_FILE_PATH}" )"
THRESHOLD_AGE_BY_DEFAULT="$( trim_trailing_spaces "${THRESHOLD_AGE_BY_DEFAULT}" )"
ONE_PROJECT="$( trim_trailing_spaces "${ONE_PROJECT}" )"
OUTPUT_DIRECTION="$( trim_trailing_spaces "${OUTPUT_DIRECTION}" )"
ATTEMPTS_MAX_TIME="$( trim_trailing_spaces "${ATTEMPTS_MAX_TIME}" )"
ATTEMPTS_PAUSE="$( trim_trailing_spaces "${ATTEMPTS_PAUSE}" )"

if test -z "${CHECK_MODE}";
then
  CHECK_MODE="check-archive-age"
fi

if test -z "${BACKUP_DIRECTORY}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Root directory of backup jobs is not defined. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi
if test ! -d "${BACKUP_DIRECTORY}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Root directory of backup jobs does not exist. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi
if test ! -r "${BACKUP_DIRECTORY}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Root directory of backup jobs does not readable by this user. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi
if test ! -x "${BACKUP_DIRECTORY}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Root directory of backup jobs does not executable by this user. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

if test -n "${CONFIG_FILE_PATH}";
then
  if test ! -f "${CONFIG_FILE_PATH}";
  then
    send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: {borg_jobs_monitoring} config {${CONFIG_FILE_PATH}} does not exist. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
    exit 0
  fi
  if test ! -r "${CONFIG_FILE_PATH}";
  then
    send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: {borg_jobs_monitoring} config {${CONFIG_FILE_PATH}} is not readable by this user. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
    exit 0
  fi
  CONFIG_FILE_CONTENT="$( clear_yaml_of_comments "$( cat "${CONFIG_FILE_PATH}" )" )"
fi

if test -n "$( clear_yaml_of_insignificant_words "${CONFIG_FILE_CONTENT}" )";
then
  printf "%s" "${CONFIG_FILE_CONTENT}" | yq -r "to_entries[]" > /dev/null 2>&1
  if test "${?}" -ne 0;
  then
    send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: {borg_jobs_monitoring} config {${CONFIG_FILE_PATH}} is not correct. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
    exit 0
  fi
fi

CONFIG_FILE_CONTENT="$( printf "%s" "${CONFIG_FILE_CONTENT}" | yq -r "." )"

check_to_positive_number_format "${THRESHOLD_AGE_BY_DEFAULT}"
if test "${?}" -ne 0;
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Default threshold age is not numeric or less than 1. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

if test "${CHECK_MODE}" == "check-archive-size";
then
  check_to_positive_number_format "${CHECK_ARCHIVE_SIZE_PERIOD}"
  if test "${?}" -ne 0;
  then
    send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Check period in --check-archive-size mode is not numeric or less than 1. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
    exit 0
  fi
fi

check_to_positive_number_format "${ATTEMPTS_MAX_TIME}"
if test "${?}" -ne 0;
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: max time of all attempts for project is not numeric or less than 1. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

check_to_positive_number_format "${ATTEMPTS_PAUSE}"
if test "${?}" -ne 0;
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: pause beetwen attempts is not numeric or less than 1. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

if test "${ATTEMPTS_MAX_TIME}" -le "${ATTEMPTS_PAUSE}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: (max time of all attempts for project) could not be less (pause beetwen attempts). Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

if test -d "${STOP_BORG_REPO_PROCESSING_DIR}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Cannot start checks because exist directory {${STOP_BORG_REPO_PROCESSING_DIR}} that signals stop borg repositories processing. Didn't check for late backups! Please run { \"${SCRIPT_PATH}\" --unstop } or { rmdir \"${STOP_BORG_REPO_PROCESSING_DIR}\" } for unblock start monitoring" "${OUTPUT_DIRECTION}"
  exit 0
fi

IFS=$'\n'

# Определение действующих значений ограничений на количество попыток доступа к Borg-репозиториям
# Условие - время выполнения не больше ATTEMPTS_MAX_TIME

# Основая проверка, по разнице текущего времени и времени старта
# При ATTEMPTS_MAX_TIME=20 и ATTEMPTS_PAUSE=5, выполнение следущей попытки с предшествующей ей паузой в 5 при текущей длительности в 16 не должно произойти
let ATTEMPTS_MAX_TIME=ATTEMPTS_MAX_TIME-ATTEMPTS_PAUSE

# На случай смещения времени, по количеству попыток
# При ATTEMPTS_MAX_TIME=20 и ATTEMPTS_PAUSE=5 выполнение после 4 попытки не имеет смысла - оно точно превысит 20 т.к. сама проверка не моментальна
let ATTEMPTS_MAX_ATTEMPTS=ATTEMPTS_MAX_TIME/ATTEMPTS_PAUSE

# Создание временного каталога в котором будут хранится данные о бэкапах и логи borg (только на время работы скрипта)
TEMP_DIR_NAME="$( uuidgen )"
if test -z "${TEMP_DIR_NAME}";
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Cannot generate name of temporary directory used for store data about backups. May be uuidgen is not installed on the host. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

TEMP_DIR="${SCRIPT_DIR}/${TEMP_DIR_NAME}"

mkdir "${TEMP_DIR}"
if test "${?}" -ne 0;
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Cannot create temporary directory '${TEMP_DIR}' used for store data about backups. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

# Формирование списка проектов
if test -n "${ONE_PROJECT}";
then
  let PROJECTS_COUNT=1
  let project_index=PROJECTS_COUNT-1

  PROJECTS["${project_index}"]="${ONE_PROJECT}"
  PROJECTS_DIR["${project_index}"]="${BACKUP_DIRECTORY}"

  let PROJECTS_JOBS_COUNT["${project_index}"]=0
  let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]=0
  let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]=0
else
  for file in $( ls "${BACKUP_DIRECTORY}" );
  do
    file_path=""
    file_path="$( remove_repeating_vfs_divider "${BACKUP_DIRECTORY}/${file}" )"

    if test -d "${file_path}";
    then
      let non_project_dir=0
      for exception in ${NON_PROJECT_DIRECTORIES};
      do
        if test "${file}" == "${exception}";
        then
          let non_project_dir+=1
          break
        fi
      done

      if test ${non_project_dir} -eq 0;
      then
        current_project=""
        current_project="${file}"

        let PROJECTS_COUNT+=1
        let project_index=PROJECTS_COUNT-1

        PROJECTS["${project_index}"]="${current_project}"
        PROJECTS_DIR["${project_index}"]="${file_path}"

        let PROJECTS_JOBS_COUNT["${project_index}"]=0
        let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]=0
        let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]=0
      fi
    fi
  done
fi

if test ${PROJECTS_COUNT} -lt 1;
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: the project list was empty. Didn't check for late backups!" "${OUTPUT_DIRECTION}"
  exit 0
fi

# Формирование списка заданий проектов
let project_index=0
while test "${project_index}" -lt "${PROJECTS_COUNT}";
do
  current_project_dir="${PROJECTS_DIR["${project_index}"]}"
  current_project_dir_alt=""

  if test -z "${ONE_PROJECT}";
  then
    # Проверка наличия каталога borg в каталоге проекта, если он присутствует,
    # то считаем этот каталог каталогом с резервными копиями проекта
    current_project_dir_alt="$( remove_repeating_vfs_divider "${current_project_dir}/borg" )"
    if test -d "${current_project_dir_alt}";
    then
      current_project_dir="${current_project_dir_alt}"
    fi
  fi

  if test ! -d "${current_project_dir}";
  then
    let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
    let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
    PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: directory {${current_project_dir}} with backups for this project doesn't exist. Didn't check for late backups!"

    let project_index+=1
    continue
  fi

  if test ! -r "${current_project_dir}";
  then
    let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
    let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
    PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: directory {${current_project_dir}} with backups for this project is not readable by this user. Didn't check for late backups!"

    let project_index+=1
    continue
  fi

  if test ! -x "${current_project_dir}";
  then
    let PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]+=1
    let project_error_common_index=PROJECTS_ERRORS_COMMON_COUNT["${project_index}"]-1
    PROJECTS_ERRORS_COMMON["${project_index},${project_error_common_index}"]="ERROR: {${PROJECTS["${project_index}"]}}: directory {${current_project_dir}} with backups for this project is not executable by this user. Didn't check for late backups!"

    let project_index+=1
    continue
  fi

  for file in $( ls "${current_project_dir}" );
  do
    file_path=""
    file_path="${current_project_dir}/${file}"
    if test -d "${file_path}";
    then
      let PROJECTS_JOBS_COUNT["${project_index}"]+=1
      let project_job_index=PROJECTS_JOBS_COUNT["${project_index}"]-1
      PROJECTS_JOBS["${project_index},${project_job_index}"]="${file}"
      PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]="${file_path}"

      let PROJECTS_WARNINGS_BACKUP_COUNT["${project_index},${project_job_index}"]=0
      let PROJECTS_WARNINGS_BACKUP_DISABLED_COUNT["${project_index},${project_job_index}"]=0
      let PROJECTS_ERRORS_BACKUP_COUNT["${project_index},${project_job_index}"]=0
      let PROJECTS_JOBS_LAST_ARCHIVE_COUNT["${project_index},${project_job_index}"]=0
    fi
  done

  let project_index+=1
done

# Получение параметров проверки из конфигурационного файла
projects_list=""

if test -n "${ONE_PROJECT}";
then
  projects_list="${PROJECTS["0"]}"
  if test -n "${CONFIG_FILE_CONTENT}";
  then
    CONFIG_FILE_CONTENT="{ \"${PROJECTS["0"]}\": ${CONFIG_FILE_CONTENT} }"
  fi
else
  projects_list="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r "to_entries[].key" )"
fi

for project in ${projects_list};
do
  let project_found=0
  let project_found_index=0
  while test "${project_found_index}" -lt "${PROJECTS_COUNT}";
  do
    if test "${project}" == "${PROJECTS["${project_found_index}"]}";
    then
      let project_found+=1
      break
    fi
    let project_found_index+=1
  done

  if test ${project_found} -gt 0;
  then
    let project_index=project_found_index
  else
    let project_index=-1

    let COMMON_WARNINGS_COUNT+=1
    let common_warnings_index=COMMON_WARNINGS_COUNT-1

    COMMON_WARNINGS["${common_warnings_index}"]="WARNING: project {${project}} defined in configuration file, but not found in file system!"

    continue
  fi

  jobs_list=""
  jobs_list="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r ".\"${project}\" | to_entries[].key" )"

  for job in ${jobs_list};
  do
    let project_job_found=0
    let project_job_found_index=0

    while test "${project_job_found_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
    do
      if test "${job}" == "${PROJECTS_JOBS["${project_index},${project_job_found_index}"]}";
      then
        let project_job_found+=1
        break
      fi
      let project_job_found_index+=1
    done

    if test ${project_job_found} -gt 0;
    then
      let project_job_index=project_job_found_index
    else
      let project_job_index=-1

      let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]+=1
      let project_warning_common_index=PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]="WARNING: job {${job}} of project {${project}} defined in configuration file, but not found in file system!"

      continue
    fi

    PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r ".\"${project}\".\"${job}\".state" )"
    PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r ".\"${project}\".\"${job}\".age" )"
    PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r ".\"${project}\".\"${job}\".disable_limit" )"
    PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r ".\"${project}\".\"${job}\".size" )"
    PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]="$( printf "%s" "${CONFIG_FILE_CONTENT}" | jq -r ".\"${project}\".\"${job}\".size_decrease" )"
  done
done

# Постобработка параметров проверки
let project_index=0
while test "${project_index}" -lt "${PROJECTS_COUNT}";
do
  let project_job_index=0
  while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
  do
    project_job_type=""
    project_job_type="$( get_backup_job_type "${PROJECTS_JOBS["${project_index},${project_job_index}"]}" )"


    # PROJECTS_JOBS_STATE
    # Присвоение значения по умолчанию для PROJECTS_JOBS_STATE (если задание или значение не определены в конфигурационном файле)
    if test -z "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}";
    then
      PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]="enable"
    fi
    if test "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" == "null";
    then
      PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]="enable"
    fi

    # Проверка корректности PROJECTS_JOBS_STATE
    let job_state_correctly=0

    if test "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" == "enable";
    then
      let job_state_correctly+=1
    fi

    if test "${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}" == "disable";
    then
      let job_state_correctly+=1
    fi

    if test ${job_state_correctly} -eq 0;
    then
      let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]+=1
      let project_warning_common_index=PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}. State of the job in config is not correct, used default value ('enable')!"

      PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]="enable"
    fi


    # PROJECTS_JOBS_THRESHOLD_AGE
    # Присвоение значения по умолчанию для PROJECTS_JOBS_THRESHOLD_AGE (если задание или значение не определены в конфигурационном файле)
    if test -z "${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}";
    then
      PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]="${THRESHOLD_AGE_BY_DEFAULT}"
    fi
    if test "${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}" == "null";
    then
      PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]="${THRESHOLD_AGE_BY_DEFAULT}"
    fi
    # Знак ~ - значение по умолчанию
    if test "${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}" == "~";
    then
      PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]="${THRESHOLD_AGE_BY_DEFAULT}"
    fi

    # Проверка корректности PROJECTS_JOBS_THRESHOLD_AGE
    let threshold_age_correctly=0

    check_to_positive_number_format "${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}"
    if test "${?}" -eq 0;
    then
      let threshold_age_correctly+=1
    fi

    if test ${threshold_age_correctly} -eq 0;
    then
      let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]+=1
      let project_warning_common_index=PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}. Threshold age in config is not correct, used default value (${THRESHOLD_AGE_BY_DEFAULT})!"

      PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]="${THRESHOLD_AGE_BY_DEFAULT}"
    fi

    # Для SYSTEM-бэкапов threshold_age больше в два раза
    if test "${project_job_type,,}" == "system";
    then
      let PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]*=2
    fi


    # PROJECTS_JOBS_STORAGE_LIMIT
    # Присвоение значения по умолчанию для PROJECTS_JOBS_STORAGE_LIMIT (если задание или значение не определены в конфигурационном файле)
    if test -z "${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}";
    then
      PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]="${DISABLED_BACKUPS_STORAGE_LIMIT}"
    fi
    if test "${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}" == "null";
    then
      PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]="${DISABLED_BACKUPS_STORAGE_LIMIT}"
    fi

    # Проверка корректности PROJECTS_JOBS_STORAGE_LIMIT
    let storage_limit_correctly=0

    check_to_positive_number_format "${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}"
    if test "${?}" -eq 0;
    then
      let storage_limit_correctly+=1
    fi

    if test ${storage_limit_correctly} -eq 0;
    then
      let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]+=1
      let project_warning_common_index=PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}. Storage limit in config is not correct, used default value (${DISABLED_BACKUPS_STORAGE_LIMIT})!"

      PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]="${DISABLED_BACKUPS_STORAGE_LIMIT}"
    fi


    # PROJECTS_JOBS_MIN_SIZE
    # Присвоение значения по умолчанию для PROJECTS_JOBS_MIN_SIZE (если задание или значение не определены в конфигурационном файле)
    if test -z "${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}";
    then
      PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]="${LAST_ARCHIVE_MIN_SIZE}"
    fi
    if test "${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}" == "null";
    then
      PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]="${LAST_ARCHIVE_MIN_SIZE}"
    fi

    # Преобразование числа с приставками в обычное число
    PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]="$( string_with_size_to_number "${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}" )"

    # Проверка корректности PROJECTS_JOBS_MIN_SIZE
    let min_size_correctly=0

    check_to_positive_number_format "${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}"
    if test "${?}" -eq 0;
    then
      let min_size_correctly+=1
    fi

    if test ${min_size_correctly} -eq 0;
    then
      let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]+=1
      let project_warning_common_index=PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}. Minimum size of last archive in config is not correct, used default value (${LAST_ARCHIVE_MIN_SIZE})!"

      PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]="${LAST_ARCHIVE_MIN_SIZE}"
    fi


    # PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE
    # Присвоение значения по умолчанию для PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE (если задание или значение не определены в конфигурационном файле)
    if test -z "${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}";
    then
      PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]="${LAST_ARCHIVE_ALLOWABLE_DECREASE_SIZE}"
    fi
    if test "${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}" == "null";
    then
      PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]="${LAST_ARCHIVE_ALLOWABLE_DECREASE_SIZE}"
    fi

    # Проверка корректности PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE
    let allowable_decrease_size_correctly=0

    check_to_positive_number_format "${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}"
    if test "${?}" -eq 0;
    then
      if test "${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}" -ge 1 -a ${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]} -le 100;
      then
        let allowable_decrease_size_correctly+=1
      fi
    fi

    if test ${allowable_decrease_size_correctly} -eq 0;
    then
      let PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]+=1
      let project_warning_common_index=PROJECTS_WARNINGS_COMMON_COUNT["${project_index}"]-1
      PROJECTS_WARNINGS_COMMON["${project_index},${project_warning_common_index}"]="WARNING: {${PROJECTS["${project_index}"]}}: job {${PROJECTS_JOBS["${project_index},${project_job_index}"]}}. Allowable decrease size of last archive in config is not correct, used default value (${LAST_ARCHIVE_ALLOWABLE_DECREASE_SIZE})!"

      PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]="${LAST_ARCHIVE_ALLOWABLE_DECREASE_SIZE}"
    fi

    let project_job_index+=1
  done

  let project_index+=1
done

# Вывод полученных значений:
#   - PROJECTS
#   - PROJECTS_DIR
#   - PROJECTS_JOBS
#   - PROJECTS_JOBS_DIR
#   - PROJECTS_JOBS_STATE
#   - PROJECTS_JOBS_THRESHOLD_AGE
#   - PROJECTS_JOBS_STORAGE_LIMIT
#   - PROJECTS_JOBS_MIN_SIZE
if test "${DEBUG}" == "yes";
then
  debug_green "projects:"
  let project_index=0
  while test "${project_index}" -lt "${PROJECTS_COUNT}";
  do
    debug_green "  - ${PROJECTS["${project_index}"]}:"
    debug_green "      dir: \"${PROJECTS_DIR["${project_index}"]}\""
    debug_green "      jobs:"

    let project_job_index=0
    while test "${project_job_index}" -lt "${PROJECTS_JOBS_COUNT["${project_index}"]}";
    do
      debug_green "        - ${PROJECTS_JOBS["${project_index},${project_job_index}"]}:"
      debug_green "            dir:           \"${PROJECTS_JOBS_DIR["${project_index},${project_job_index}"]}\""
      debug_green "            state:         \"${PROJECTS_JOBS_STATE["${project_index},${project_job_index}"]}\""
      debug_green "            max_age:       \"${PROJECTS_JOBS_THRESHOLD_AGE["${project_index},${project_job_index}"]}\""
      debug_green "            store_limit:   \"${PROJECTS_JOBS_STORAGE_LIMIT["${project_index},${project_job_index}"]}\""
      debug_green "            min_size:      \"${PROJECTS_JOBS_MIN_SIZE["${project_index},${project_job_index}"]}\""
      debug_green "            size_decrease: \"${PROJECTS_JOBS_ALLOWABLE_DECREASE_SIZE["${project_index},${project_job_index}"]}\""

      let project_job_index+=1
    done

    let project_index+=1
  done
fi

# Выполнение проверок
case "${CHECK_MODE}"
in
  check-archive-age|check-disabled-backups-storage-limit)
    if test "${PARALLELIZE_ALL_OPERATIONS}" != "yes";
    then
      do_check_archive_date_with_parallel_per_project_data_acquisition
    else
      let project_index=0
      while test "${project_index}" -lt "${PROJECTS_COUNT}";
      do
        do_check_archive_date "${project_index}" &

        let project_index+=1
      done

      # Ожидание всех запущенных процессов
      wait > "/dev/null" 2>&1
    fi
  ;;

  check-access-rights)

    # Выполнение проверок соответствия прав для корневого каталога бэкапов
    if test -z "${ONE_PROJECT}";
    then
      check_backup_directory_access_rights
    fi

    # Выполнение проверок соответствия прав для каталогов проектов и каталогов
    # заданий резервного копирования
    let project_index=0
    while test "${project_index}" -lt "${PROJECTS_COUNT}";
    do
      check_backups_access_rights "${project_index}"

      let project_index+=1
    done

    # Отправка попроектных алертов и создание тикетов
    let project_index=0
    while test "${project_index}" -lt "${PROJECTS_COUNT}";
    do
      alerts_about_projects_common_warnings "${project_index}"
      alerts_about_projects_common_erros "${project_index}"

      alerts_about_projects_backup_warnings "${project_index}"
      alerts_about_projects_backup_errors "${project_index}"
      create_tickets_about_disabled_backups "${project_index}"

      let project_index+=1
    done
  ;;

  check-archive-size)

    if test "${PARALLELIZE_ALL_OPERATIONS}" != "yes";
    then
      do_check_archive_size_with_parallel_per_project_data_acquisition
    else
      let project_index=0
      while test "${project_index}" -lt "${PROJECTS_COUNT}";
      do
        do_check_archive_size "${project_index}" &

        let project_index+=1
      done

      # Ожидание всех запущенных процессов
      wait > "/dev/null" 2>&1
    fi
  ;;
esac

# Отправка общих алертов
alerts_about_common_warnings
alerts_about_common_errors

# Удаление временного каталога в котором хранились данные о бэкапах и логи borg
#find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type f -delete
#if test "${?}" -ne 0;
#then
#  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Cannot clean temporary directory '${TEMP_DIR}' used for store data about backups. Please remove her" "${OUTPUT_DIRECTION}"
#  exit 0
#fi

rmdir "${TEMP_DIR}"
if test "${?}" -ne 0;
then
  send_alert "${ONE_PROJECT}" "catastrophic" "ERROR: Cannot remove temporary directory '${TEMP_DIR}' used for store data about backups. Please remove her" "${OUTPUT_DIRECTION}"
  exit 0
fi

exit 0


#!/usr/bin/env bash

# Этот скрипт предназначен не для создания резервных копий Sentry, а для
# разъяснения приниципа их создания

# Использовать отдельный скрипт для бэкапа Sentry не требуется по следующим причинам:
#   - большинство данных Sentry, которые имеет смысл резервировать находятся в
#     PostgreSQL ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185287966 )
#   - остальные данные - данные графиков и временных рядов -  находятся в Redis
#     ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185287966 )
#   - встроенная команда Sentry - 'sentry export' экспортирует данные только
#     из PostgreSQL ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185287966 )
#     и вместо нее рекомендуется использовать обычные способы резервного копирования PostgreSQL
#     ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185290496

# В итоге, резервное копирование Sentry состоит из:
#   - резервного копирования баз PostgreSQL, с помощью уже имеющихся в этом
#     репозитории скриптов 'borg_backup_postgres.sh' и 'borg_backup_postgres_stdout.sh'
#   - и, при необходимости, резервного копирования баз Redis, которое можно
#     осуществить с помощью скрипта 'borg_backup_redis.sh'

################################################################################

NAMEOFBACKUP_DEFAULT='SENTRY'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

alert "Cannot backup Sentry. See contents of the script '$( basename "${0}" )' for more information"

exit 1

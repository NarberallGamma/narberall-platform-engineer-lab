#!/usr/bin/env bash

# This script does not create Sentry backups; it explains
# how they are created.

# A dedicated Sentry backup script is not required because:
#   - most Sentry data worth backing up lives in
#     PostgreSQL ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185287966 )
#   - the rest — charts and time series — lives in Redis
#     ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185287966 )
#   - the built-in Sentry command 'sentry export' exports data only
#     from PostgreSQL ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185287966 )
#     and ordinary PostgreSQL backup methods are recommended instead
#     ( https://github.com/getsentry/sentry/issues/2698#issuecomment-185290496 )

# So a Sentry backup consists of:
#   - backing up PostgreSQL databases with the existing
#     'borg_backup_postgres.sh' and 'borg_backup_postgres_stdout.sh' scripts
#   - and, if needed, backing up Redis databases with
#     'borg_backup_redis.sh'

################################################################################

NAMEOFBACKUP_DEFAULT='SENTRY'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

alert "Cannot backup Sentry. See contents of the script '$( basename "${0}" )' for more information"

exit 1

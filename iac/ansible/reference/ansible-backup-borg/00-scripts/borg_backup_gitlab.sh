#!/usr/bin/env bash

# Primary way to back up GitLab

# How it works:
#   - create a GitLab backup with 'gitlab-rake gitlab:backup:create SKIP=registry'
#     in /var/opt/gitlab/backups
#   - back up /etc/gitlab and /var/opt/gitlab/backups with borg_backup_files.sh
#   - delete old GitLab backups from /var/opt/gitlab/backups

# Supported options:
# -k|--prune      - retention options in Borg format, for
#                   example '--keep-hourly 72 --keep-within=30d'
#                   Optional; if omitted,
#                   ${CUSTOMPRUNE_DEFAULT} is used

# Positional arguments:
# ${1} - job name, Borg repository name suffix; if omitted,
#        ${NAMEOFBACKUP_DEFAULT} is used

# Schedule usage examples:
# borg_run_on.sh 10.0.0.1 borg_backup_gitlab.sh
# borg_run_on.sh 10.0.0.1 borg_backup_gitlab.sh 'GITLAB'
# borg_run_on.sh 10.0.0.1 borg_backup_gitlab.sh 'GITLAB --prune "--keep-hourly 3 --keep-within=30d"'

################################################################################

NAMEOFBACKUP_DEFAULT="GITLAB"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

################################################################################

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

################################################################################

CUSTOMPRUNE=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options k: --longoptions ,prune: -- "${@}" 2>/dev/null )"
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
    *) break ;;
  esac
done

NAME="${2}"

gitlab-rake gitlab:backup:create SKIP=registry || alert "gitlab-rake failed"

00-scripts/borg_backup_files.sh "${NAME:-${NAMEOFBACKUP_DEFAULT}}" "/etc/gitlab,/var/opt/gitlab/backups" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --dont-ignore-missing-files

find /var/opt/gitlab/backups -type f -mtime +1 -ls -delete

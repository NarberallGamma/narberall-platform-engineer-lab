#!/bin/bash
# Удаление в app_data/export файлов старше RETENTION_DAYS суток (по mtime).
# Переопределение: RETENTION_DAYS=45 EXPORT_DIR=... LOG_FILE=... /path/to/cleanup_jira_export.sh
#
# Crontab (root), ежедневно в 04:00, ретенция 30 дней (отдельно на каждом хосте):
#
# app-02 / Service Desk lab:
#   0 4 * * * RETENTION_DAYS=30 /bin/bash /docker/servicedesk.example.com/scripts/cleanup_jira_export.sh
#
# sd-prod.example.com / servicedesk.example.com (обязательно EXPORT_DIR и LOG_FILE):
#   0 4 * * * RETENTION_DAYS=30 EXPORT_DIR=/docker/apps/servicedesk.example.com/Volumes/app_data/export LOG_FILE=/var/log/jira-servicedesk-export-cleanup.log /bin/bash /docker/apps/servicedesk.example.com/scripts/cleanup_jira_export.sh
set -u

EXPORT_DIR="${EXPORT_DIR:-/docker/servicedesk.example.com/Volumes/app_data/export}"
LOG_FILE="${LOG_FILE:-/var/log/jira-servicedesk-export-cleanup.log}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

if [[ ! -d "$EXPORT_DIR" ]]; then
  log "ERROR missing directory: $EXPORT_DIR"
  exit 1
fi

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ "$RETENTION_DAYS" -lt 1 ]]; then
  log "ERROR invalid RETENTION_DAYS=$RETENTION_DAYS"
  exit 1
fi

log "start export_dir=$EXPORT_DIR retention=${RETENTION_DAYS}d mtime (delete files older)"

N=$(find "$EXPORT_DIR" -type f -mtime +"${RETENTION_DAYS}" 2>/dev/null | wc -l)
N=$(echo "$N" | tr -d '[:space:]')
log "files_to_delete=$N"

if [[ "${N:-0}" -gt 0 ]]; then
  find "$EXPORT_DIR" -type f -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || log "WARN find -delete returned non-zero"
fi

find "$EXPORT_DIR" -type d -empty -delete 2>/dev/null || true
log "end"

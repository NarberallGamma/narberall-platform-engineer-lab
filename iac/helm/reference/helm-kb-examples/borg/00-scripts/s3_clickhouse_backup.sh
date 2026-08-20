#!/bin/bash

# script settings

source "$(dirname ${0})/../vars"

CLICKHOUSE_BACKUP_VER="2.3.2"
CLICKHOUSE_BACKUP_URL="https://github.com/Altinity/clickhouse-backup/releases/download/v${CLICKHOUSE_BACKUP_VER}/clickhouse-backup-linux-amd64.tar.gz"

# clickhouse-backup general settings

export NAMEOFBACKUP="CLCKHS"
export CLICKHOUSE_USERNAME=${CLICKHOUSE_USERNAME}
export REMOTE_STORAGE="s3"
export S3_BUCKET=${S3_BUCKET} 
export S3_REGION=${S3_REGION}

# BACKUPS_TO_KEEP_LOCAL, how many latest local backup should be kept, 0 means all created backups will be stored on local disk
# -1 means backup will keep after `create` but will delete after `create_remote` command
# You shall run `clickhouse-backup delete local <backup_name>` command to remove temporary backup files from the local disk

export BACKUPS_TO_KEEP_LOCAL=${BACKUPS_TO_KEEP_LOCAL}

# BACKUPS_TO_KEEP_REMOTE, how many latest backup should be kept on remote storage, 0 means all uploaded backups will be stored on remote storage.
# If old backups are required for newer incremental backup then it won't be deleted. Be careful with long incremental backup sequences.
  
export BACKUPS_TO_KEEP_REMOTE=${BACKUPS_TO_KEEP_REMOTE}

function install_clickhouse_backup {
  rm -f /usr/local/bin/clickhouse-backup 
  wget "${CLICKHOUSE_BACKUP_URL}" -P /tmp/clickhouse-backup
  tar xvzf /tmp/clickhouse-backup/clickhouse-backup-linux-amd64.tar.gz -C /tmp/clickhouse-backup
  cp /tmp/clickhouse-backup/build/linux/amd64/clickhouse-backup /usr/local/bin/clickhouse-backup
  rm -r /tmp/clickhouse-backup
  test -s /usr/local/bin/clickhouse-backup || { echo '### Failed to install clickhouse-backup!'; exit 1 ; }

  chown root:root /usr/local/bin/clickhouse-backup
  chmod 755 /usr/local/bin/clickhouse-backup
}

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}

  MSG="${1}"
  FULL_MSG="${2}"

  echo "ERROR: ${MSG} (details: ${FULL_MSG:--})"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MSG}" "${FULL_MSG}"
  exit 1
}

function full {
  readarray -t arr2 < <(clickhouse-client -u backup --query "SELECT database, table FROM system.tables" | grep -v "system\|information_schema\|INFORMATION_SCHEMA" | awk '{ print $1"."$2 }')
  echo clickhouse-backup create_remote $(date "+%F-%H-%M") tables -t $(printf '%s,' "${arr2[@]}")
  clickhouse-backup create_remote $(date "+%F-%H-%M") tables -t $(printf '%s,' "${arr2[@]}") || alert "'s3-clickhouse-backup create' failed"
}

function incremental {
  GET_LAST=$(clickhouse-backup list remote latest | grep -v "info")
  readarray -t arr2 < <(clickhouse-client -u backup --query "SELECT database, table FROM system.tables" | grep -v "system\|information_schema\|INFORMATION_SCHEMA" | awk '{ print $1"."$2 }')
  echo clickhouse-backup create_remote $(date "+%F-%H-%M")  --diff-from-remote=$GET_LAST tables -t $(printf '%s,' "${arr2[@]}")
  clickhouse-backup create_remote $(date "+%F-%H-%M")  --diff-from-remote=$GET_LAST tables -t $(printf '%s,' "${arr2[@]}") || alert "'s3-clickhouse-backup create' failed"
}

# script main section 

if (( $# != 1 ))
then
        echo “USAGE: $0 BACKUP_TYPE“
        echo "Use FULL or INCREMENTAL. Example: $0 FULL"
        exit
fi

# Install clickhouse-backup if not found

if [ -f /usr/local/bin/clickhouse-backup ] ;
then 
  echo "Clickhouse-backup found"
else
  echo "No clickhouse-backup found. Installing"
  install_clickhouse_backup
fi

# Update clickhouse-backup version

CLCKHS_CHK=$(clickhouse-backup --version | grep Version | awk '{print  $2}' 2>/dev/null) 
[[ "${CLCKHS_CHK}" =~ "${CLICKHOUSE_BACKUP_VER}" ]] && echo "clickhouse-backup version is $CLICKHOUSE_BACKUP_VER" || install_clickhouse_backup

# RUN backup 

BACKUP_TYPE=${1}

if [ "$BACKUP_TYPE" == "FULL" ];
then
  full
elif [ "$BACKUP_TYPE" == "INCREMENTAL" ];
then
  incremental
else
  echo "Wrong backup type. Use FULL or INCREMENTAL. Example: $0 FULL" 
  alert "'s3-clickhouse-backup create' failed"
  exit 1
fi

exit 0


#!/bin/bash

# Этот скрипт - запасной способ бэкапа PostgreSQL

source /app/vars
NAMEOFBACKUP=${2}
TYPEOFBACKUP='psql'
TEMPLOG=$(mktemp)
TEMPLOGPRUNE=$(mktemp)

USAGE="Usage: $0 <bucket> <backupname> <host> <user> <pass> <database> <keep>"

if [ -z "$NAMEOFBACKUP" ] ; then
  echo "<nameofbackup> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

BUCKET=$1
if [ -z "$BUCKET" ] ; then
  echo "<bucket> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

host=$3
if [ -z "$host" ] ; then
  echo "<host> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

user=$4
if [ -z "$user" ] ; then
  echo "<user> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

password=$5
if [ -z "$password" ] ; then
  echo "<pass> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

database=$6
if [ -z "$database" ] ; then
  echo "<database> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

keep=$7
if [ -z "$keep" ] ; then
  echo "<keep> param will set to default 65d!" 1>&2
  keep="30d"
fi

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

restic_repository_var="RESTIC_REPOSITORY_${BUCKET}"
restic_password_var="RESTIC_PASSWORD_${BUCKET}"
aws_access_key_id_var="AWS_ACCESS_KEY_ID_${BUCKET}"
aws_secret_access_key="AWS_SECRET_ACCESS_KEY_${BUCKET}"

export RESTIC_REPOSITORY=${!restic_repository_var}
export RESTIC_PASSWORD=${!restic_password_var}
export AWS_ACCESS_KEY_ID=${!aws_access_key_id_var}
export AWS_SECRET_ACCESS_KEY=${!aws_secret_access_key}

restic init || echo "skip initialization."

export PGPASSWORD="$password"
{ pg_dump -h ${host} -U ${user} -d ${database} -Fc -b \
      || alert "pg_dump failed $?"; exit 1; } \
      | restic backup --verbose --tag ${NAMEOFBACKUP} --stdin --stdin-filename ${NAMEOFBACKUP}.dump \
      &> ${TEMPLOG} \
      || { alert "restic create failed $?" "$(cat ${TEMPLOG} | tail -n 20 | perl -pe 's/\n/\\n/g')"; exit 1; }
cat ${TEMPLOG}

#prune
restic forget --tag ${NAMEOFBACKUP} --keep-within ${keep} --prune &> ${TEMPLOGPRUNE} || \
      alert "restic prune failed" "$(cat ${TEMPLOGPRUNE} | tail -n 20 | perl -pe 's/\n/\\n/g')"
cat ${TEMPLOGPRUNE}

rm ${TEMPLOG} ${TEMPLOGPRUNE}

#!/bin/bash

source /app/vars
NAMEOFBACKUP=${1}
TYPEOFBACKUP='elasticsearch'
TEMPLOG=$(mktemp)
TEMPLOGPRUNE=$(mktemp)

USAGE="Usage: $0 <backupname> <host> <port> <index>"

if [ -z "$NAMEOFBACKUP" ] ; then
  echo "<nameofbackup> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

host=$2
if [ -z "$host" ] ; then
  echo "<host> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

port=$3
if [ -z "$port" ] ; then
  echo "<port> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

index=$4
if [ -z "$index" ] ; then
  echo "<index> param required!" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

restic init || echo "skip initialization."

{ elasticdump \
    --input=http://${host}:${port}/${index} \
    --output=$ \
    --type=analyzer \
    || alert "elasticdump data failed $?"; exit 1; } \
    | restic backup --verbose --tag ${NAMEOFBACKUP} --stdin --stdin-filename ${NAMEOFBACKUP}-${index}-analyzer.json \
    &> ${TEMPLOG} \
    || { alert "restic create failed $?" "$(cat ${TEMPLOG} | tail -n 20 | perl -pe 's/\n/\\n/g')"; exit 1; }
cat ${TEMPLOG}

{ elasticdump \
    --input=http://${host}:${port}/${index} \
    --output=$ \
    --type=mapping \
    || alert "elasticdump mapping failed $?"; exit 1; } \
    | restic backup --verbose --tag ${NAMEOFBACKUP} --stdin --stdin-filename ${NAMEOFBACKUP}-${index}-mapping.json \
    &> ${TEMPLOG} \
    || { alert "restic create failed $?" "$(cat ${TEMPLOG} | tail -n 20 | perl -pe 's/\n/\\n/g')"; exit 1; }
cat ${TEMPLOG}

{ elasticdump \
    --input=http://${host}:${port}/${index} \
    --output=$ \
    --type=data \
    || alert "elasticdump data failed $?"; exit 1; } \
    | restic backup --verbose --tag ${NAMEOFBACKUP} --stdin --stdin-filename ${NAMEOFBACKUP}-${index}-data.json \
    &> ${TEMPLOG} \
    || { alert "restic create failed $?" "$(cat ${TEMPLOG} | tail -n 20 | perl -pe 's/\n/\\n/g')"; exit 1; }
cat ${TEMPLOG}

#prune
restic forget --tag ${NAMEOFBACKUP} --keep-within 30d --prune &> ${TEMPLOGPRUNE} || \
      alert "restic prune failed" "$(cat ${TEMPLOGPRUNE} | tail -n 20 | perl -pe 's/\n/\\n/g')"
cat ${TEMPLOGPRUNE}

rm ${TEMPLOG} ${TEMPLOGPRUNE}

{% raw %}#!/bin/sh
set -e

CONTAINER_NAME=kafka
FILE=/docker/kafka/certs/eip.pem
CONTAINER_START_SEC=$(date -d "$(docker inspect -f '{{.State.StartedAt}}' $CONTAINER_NAME | sed -E 's/T/ /; s/\.[0-9]+Z$//' )" +%s)
FILE_MOD=$(stat -c %Y "$FILE")

if [ "$FILE_MOD" -gt "$CONTAINER_START_SEC" ]; then
  echo "$(date) File $FILE $FILE_MOD is newer than container $CONTAINER_NAME $CONTAINER_START_SEC start, restarting container..."
  docker compose -f /docker/kafka/docker-compose.yml restart -t 120 "$CONTAINER_NAME"
else
  echo "$(date) Container $CONTAINER_NAME is up-to-date. No restart needed.(File $FILE modified date:$FILE_MOD, container start date: $CONTAINER_START_SEC"
fi
{% endraw %}

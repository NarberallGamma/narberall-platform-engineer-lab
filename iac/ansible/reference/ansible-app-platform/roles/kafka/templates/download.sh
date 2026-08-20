{% raw %}#!/bin/sh
set -e
while true; do
  NEW_CERT=$(vault kv get -field=eip.pem secret/$SECRET_NAME)
  CURRENT_CERT=$(cat /certs/eip.pem)

  if [ "$CURRENT_CERT" != "$NEW_CERT" ]; then
    echo $(date) updating certs/eip.pem file...
    echo "$NEW_CERT" >/certs/eip.pem
    echo "File updated"
  else
    echo "No changes, skipping file update"
  fi
  echo $(date) sleeping 1d..
  sleep 1d
done
{% endraw %}

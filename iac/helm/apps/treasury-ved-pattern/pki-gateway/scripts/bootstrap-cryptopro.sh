#!/usr/bin/env bash
# Vendor base-chart 0.2.1 bootstrap: PREGEN generates dgtry_mk_* on empty PVC; GENKEY skips.
set -e

USER_ID=10001
GROUP_ID=10001
MODE=700

chown -R cprouser:cprouser /var/opt/cprocsp/keys/cprouser
chmod 700 /var/opt/cprocsp/keys/cprouser

KEYS_DIR="/var/opt/cprocsp/keys/cprouser"

MODE_ENV="$(echo "${TREASURY_DGTRY_MODE:-$(printenv treasury.policy-gateway.dgtry.mode || echo GENKEY)}" | tr '[:lower:]' '[:upper:]')"

echo "Detected mode: $MODE_ENV"

if [ "$MODE_ENV" = "PREGEN" ]; then
  result=$(find "$KEYS_DIR" -maxdepth 1 -type d -name 'dgtry_mk_*' -print -quit)
  echo "Result: '$result'"
  if [ -n "$result" ]; then
    echo "Keys already exist, skipping generation"
  else
    echo "PREGEN mode and no keys found: generating keys"
    su -s /bin/bash -c "/var/opt/cprocsp/cpro_genkeys.sh" cprouser
  fi
else
  echo "Mode is $MODE_ENV, skipping generation"
fi

for dir in keys; do
  TARGET="/var/opt/cprocsp/$dir"
  echo "Applying chown/chmod to $TARGET"
  chown -R $USER_ID:$GROUP_ID "$TARGET"
  chmod -R $MODE "$TARGET"

  echo "Permissions after chown:"
  ls -ld "$TARGET"
  find "$TARGET" -type d -exec ls -ld {} \;
done

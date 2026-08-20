#!/bin/sh
# Unified CryptoPro bootstrap: optional keys import from archive + vendor PREGEN/GENKEY logic.
set -e

USER_ID=10001
GROUP_ID=10001
MODE=700
KEYS_DIR="/var/opt/cprocsp/keys/cprouser"
KEYS_ARCHIVE="${KEYS_ARCHIVE:-/archives/keys.tar.gz}"

keys_exist() {
  result=$(find "$KEYS_DIR" -maxdepth 1 -type d -name 'dgtry_mk_*' -print -quit 2>/dev/null || true)
  [ -n "$result" ]
}

echo "=== CryptoPro bootstrap (import + PREGEN) ==="
echo "KEYS_IMPORT_ENABLED=${KEYS_IMPORT_ENABLED:-false}"
echo "KEYS_IMPORT_FORCE=${KEYS_IMPORT_FORCE:-false}"
echo "KEYS_ARCHIVE=${KEYS_ARCHIVE}"

# --- Phase 1: import keys from hsm-bootstrap image archive (optional) ---
if [ "$(echo "${KEYS_IMPORT_ENABLED}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  if [ "$(echo "${KEYS_IMPORT_FORCE}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
    echo "Force import: extracting keys from ${KEYS_ARCHIVE}"
    if [ ! -f "${KEYS_ARCHIVE}" ]; then
      echo "ERROR: archive not found: ${KEYS_ARCHIVE}" >&2
      exit 1
    fi
    mkdir -p "${KEYS_DIR}"
    rm -rf "${KEYS_DIR:?}"/*
    tar -xzf "${KEYS_ARCHIVE}" -C "${KEYS_DIR}"
  elif keys_exist; then
    echo "Keys already present on PVC, skipping import"
  else
    echo "PVC keys empty, importing from ${KEYS_ARCHIVE}"
    if [ ! -f "${KEYS_ARCHIVE}" ]; then
      echo "ERROR: archive not found: ${KEYS_ARCHIVE}" >&2
      exit 1
    fi
    mkdir -p "${KEYS_DIR}"
    tar -xzf "${KEYS_ARCHIVE}" -C "${KEYS_DIR}"
  fi
else
  echo "Keys import disabled, skipping archive extraction"
fi

# --- Phase 2: vendor base-chart 0.2.1 bootstrap (PREGEN / GENKEY) ---
if id cprouser >/dev/null 2>&1; then
  chown -R cprouser:cprouser "${KEYS_DIR}" 2>/dev/null || chown -R "${USER_ID}:${GROUP_ID}" "${KEYS_DIR}"
else
  chown -R "${USER_ID}:${GROUP_ID}" "${KEYS_DIR}"
fi
chmod 700 "${KEYS_DIR}"

MODE_ENV="$(echo "${TREASURY_DGTRY_MODE:-$(printenv treasury.policy-gateway.dgtry.mode 2>/dev/null || echo GENKEY)}" | tr '[:lower:]' '[:upper:]')"
echo "Detected mode: ${MODE_ENV}"

if [ "${MODE_ENV}" = "PREGEN" ]; then
  if keys_exist; then
    echo "Keys already exist, skipping generation"
  elif [ -x /var/opt/cprocsp/cpro_genkeys.sh ]; then
    echo "PREGEN mode and no keys found: generating keys"
    su -s /bin/sh -c "/var/opt/cprocsp/cpro_genkeys.sh" cprouser
  else
    echo "PREGEN mode, no keys, cpro_genkeys.sh unavailable (import-only image?)"
    echo "Enable keysImport or use cryptopro image for auto-generation"
    exit 1
  fi
else
  echo "Mode is ${MODE_ENV}, skipping generation"
fi

TARGET="/var/opt/cprocsp/keys"
echo "Applying chown/chmod to ${TARGET}"
chown -R "${USER_ID}:${GROUP_ID}" "${TARGET}"
chmod -R "${MODE}" "${TARGET}"

echo "Permissions after chown:"
ls -ld "${TARGET}"
find "${TARGET}" -maxdepth 2 -type d -exec ls -ld {} \; 2>/dev/null | head -20

echo "=== CryptoPro bootstrap finished ==="

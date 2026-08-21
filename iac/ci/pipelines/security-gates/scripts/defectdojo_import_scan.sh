#!/bin/sh
set -e

# ---------- defaults ----------------------------------------------------------
DEFECTDOJO_SCAN_MINIMUM_SEVERITY="${DEFECTDOJO_SCAN_MINIMUM_SEVERITY:-Low}"
DEFECTDOJO_SCAN_ACTIVE="${DEFECTDOJO_SCAN_ACTIVE:-true}"
DEFECTDOJO_SCAN_VERIFIED="${DEFECTDOJO_SCAN_VERIFIED:-false}"
DEFECTDOJO_SCAN_CLOSE_OLD_FINDINGS="${DEFECTDOJO_SCAN_CLOSE_OLD_FINDINGS:-true}"
DEFECTDOJO_SCAN_CLOSE_OLD_FINDINGS_PRODUCT_SCOPE="${DEFECTDOJO_SCAN_CLOSE_OLD_FINDINGS_PRODUCT_SCOPE:-true}"
DEFECTDOJO_SCAN_PUSH_TO_JIRA="${DEFECTDOJO_SCAN_PUSH_TO_JIRA:-false}"
DEFECTDOJO_SCAN_ENVIRONMENT="${DEFECTDOJO_SCAN_ENVIRONMENT:-Default}"

# ---------- required variables ------------------------------------------------
_required_vars="DEFECTDOJO_URL DEFECTDOJO_TOKEN DEFECTDOJO_ENGAGEMENTID \
                DEFECTDOJO_SCAN_FILE DEFECTDOJO_SCAN_TYPE"

for _var in $_required_vars; do
    eval "_val=\$$_var"
    if [ -z "$_val" ]; then
        echo "ERROR: Required variable '$_var' is not set." >&2
        exit 1
    fi
done

# ---------- scan file must exist ---------------------------------------------
if [ ! -f "${DEFECTDOJO_SCAN_FILE}" ]; then
    echo "ERROR: Scan file '${DEFECTDOJO_SCAN_FILE}' not found." >&2
    exit 1
fi

# ---------- import results ----------------------------------------------------
TODAY=$(date +%Y-%m-%d)

echo "==> Importing scan results to DefectDojo..."
echo "    File:        ${DEFECTDOJO_SCAN_FILE}"
echo "    Scan type:   ${DEFECTDOJO_SCAN_TYPE}"
echo "    Engagement:  ${DEFECTDOJO_ENGAGEMENTID}"

curl -k --fail --silent --show-error \
    --location \
    --request POST "${DEFECTDOJO_URL}/import-scan/" \
    --header "Authorization: Token ${DEFECTDOJO_TOKEN}" \
    --form "scan_date=${TODAY}" \
    --form "minimum_severity=${DEFECTDOJO_SCAN_MINIMUM_SEVERITY}" \
    --form "active=${DEFECTDOJO_SCAN_ACTIVE}" \
    --form "verified=${DEFECTDOJO_SCAN_VERIFIED}" \
    --form "scan_type=${DEFECTDOJO_SCAN_TYPE}" \
    --form "engagement=${DEFECTDOJO_ENGAGEMENTID}" \
    --form "file=@${DEFECTDOJO_SCAN_FILE}" \
    --form "close_old_findings=${DEFECTDOJO_SCAN_CLOSE_OLD_FINDINGS}" \
    --form "close_old_findings_product_scope=${DEFECTDOJO_SCAN_CLOSE_OLD_FINDINGS_PRODUCT_SCOPE}" \
    --form "push_to_jira=${DEFECTDOJO_SCAN_PUSH_TO_JIRA}" \
    --form "environment=${DEFECTDOJO_SCAN_ENVIRONMENT}"

echo "==> Scan results successfully imported to DefectDojo."

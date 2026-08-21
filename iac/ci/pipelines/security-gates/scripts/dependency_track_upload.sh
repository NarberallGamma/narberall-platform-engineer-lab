#!/bin/sh
# dependency_track_upload.sh
#
# 1. Find or create a project in Dependency-Track
# 2. Upload the SBOM (bom.json)
# 3. Wait for analysis
# 4. Download a CycloneDX report
# 5. Upload the report to DefectDojo
#
# Required environment:
#   DT_API_KEY               -  Dependency-Track API key
#   DT_URL                   -  Dependency-Track base URL (no trailing slash)
#   CI_PROJECT_NAME          -  project name in Dependency-Track
#   DEFECTDOJO_URL           -  DefectDojo base URL
#   DEFECTDOJO_TOKEN         -  DefectDojo API token
#   DEFECTDOJO_ENGAGEMENTID  -  Engagement id (from defectdojo.env)
#
# Optional (defaults exist):
#   BOM_FILE                          -  SBOM path ("bom.json")
#   DEFECTDOJO_SCAN_FILE              -  DT report path ("dependency-report.json")
#   DEFECTDOJO_SCAN_TYPE              -  DefectDojo scan type
#   PROJECT_VERSION                   -  DT project version ("1.0.0")
#   DT_ANALYSIS_WAIT_SECONDS          -  pause after SBOM upload (20)
#   DEFECTDOJO_SCAN_MINIMUM_SEVERITY  -  minimum severity ("Low")

set -e

# ---------- defaults ----------------------------------------------------------
BOM_FILE="${BOM_FILE:-bom.json}"
DEFECTDOJO_SCAN_FILE="${DEFECTDOJO_SCAN_FILE:-dependency-report.json}"
DEFECTDOJO_SCAN_TYPE="${DEFECTDOJO_SCAN_TYPE:-Dependency Track Finding Packaging Format (FPF) Export}"
PROJECT_VERSION="${PROJECT_VERSION:-1.0.0}"
DT_ANALYSIS_WAIT_SECONDS="${DT_ANALYSIS_WAIT_SECONDS:-20}"
DEFECTDOJO_SCAN_MINIMUM_SEVERITY="${DEFECTDOJO_SCAN_MINIMUM_SEVERITY:-Low}"

# ---------- required variables ------------------------------------------------
_required_vars="DT_API_KEY DT_URL CI_PROJECT_NAME \
                DEFECTDOJO_URL DEFECTDOJO_TOKEN DEFECTDOJO_ENGAGEMENTID"

for _var in $_required_vars; do
    eval "_val=\$$_var"
    if [ -z "$_val" ]; then
        echo "ERROR: Required variable '$_var' is not set." >&2
        exit 1
    fi
done

# ---------- SBOM must exist ---------------------------------------------------
if [ ! -f "${BOM_FILE}" ]; then
    echo "ERROR: BOM file '${BOM_FILE}' not found." >&2
    exit 1
fi

# 1. Find or create a project in Dependency-Track
echo "==> Fetching project list from Dependency-Track..."

PROJECT_ID=$(curl -k -s \
    -H "X-Api-Key: ${DT_API_KEY}" \
    "${DT_URL}/api/v1/project" \
    | jq -r --arg NAME "$CI_PROJECT_NAME" \
        '.[] | select(.name==$NAME) | .uuid')

if [ -z "$PROJECT_ID" ]; then
    echo "==> Project '${CI_PROJECT_NAME}' not found. Creating..."
    curl -k -s \
        -X PUT "${DT_URL}/api/v1/project" \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: ${DT_API_KEY}" \
        -d "{
            \"name\": \"${CI_PROJECT_NAME}\",
            \"version\": \"${PROJECT_VERSION}\",
            \"description\": \"Project created automatically by GitLab CI pipeline\",
            \"active\": true
        }" > /dev/null

    echo "==> Waiting for the project to appear..."
    sleep 5

    PROJECT_ID=$(curl -k -s \
        -H "X-Api-Key: ${DT_API_KEY}" \
        "${DT_URL}/api/v1/project" \
        | jq -r --arg NAME "$CI_PROJECT_NAME" \
            '.[] | select(.name==$NAME) | .uuid')
fi

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: Failed to create or find project '${CI_PROJECT_NAME}'." >&2
    exit 1
fi

echo "==> Project UUID: ${PROJECT_ID}"

# 2. Upload SBOM
echo "==> Uploading SBOM to Dependency-Track..."

curl -k -s \
    -X POST "${DT_URL}/api/v1/bom" \
    -H "X-Api-Key: ${DT_API_KEY}" \
    -H "Content-Type: multipart/form-data" \
    -F "project=${PROJECT_ID}" \
    -F "bom=@${BOM_FILE}"

echo "==> SBOM uploaded successfully."

# 3. Wait for analysis
echo "==> Waiting ${DT_ANALYSIS_WAIT_SECONDS}s for Dependency-Track analysis..."
sleep "${DT_ANALYSIS_WAIT_SECONDS}"

# 4. Download CycloneDX report
echo "==> Downloading CycloneDX report from Dependency-Track..."

curl -k -s \
    -H "X-Api-Key: ${DT_API_KEY}" \
    "${DT_URL}/api/v1/bom/cyclonedx/project/${PROJECT_ID}" \
    -o "${DEFECTDOJO_SCAN_FILE}"

if [ ! -s "${DEFECTDOJO_SCAN_FILE}" ]; then
    echo "ERROR: Failed to fetch report from Dependency-Track (file is empty)." >&2
    exit 1
fi

echo "==> Report saved as '${DEFECTDOJO_SCAN_FILE}'."

# 5. Upload report to DefectDojo
echo "==> Uploading Dependency-Track results to DefectDojo..."

TODAY=$(date +%Y-%m-%d)

curl -k --fail --silent --show-error \
    --location \
    --request POST "${DEFECTDOJO_URL}/import-scan/" \
    --header "Authorization: Token ${DEFECTDOJO_TOKEN}" \
    --form "scan_date=${TODAY}" \
    --form "minimum_severity=${DEFECTDOJO_SCAN_MINIMUM_SEVERITY}" \
    --form "active=true" \
    --form "verified=false" \
    --form "scan_type=${DEFECTDOJO_SCAN_TYPE}" \
    --form "engagement=${DEFECTDOJO_ENGAGEMENTID}" \
    --form "file=@${DEFECTDOJO_SCAN_FILE}" \
    --form "close_old_findings=true" \
    --form "close_old_findings_product_scope=true" \
    --form "push_to_jira=false" \
    --form "environment=Default"

echo "==> Dependency-Track results uploaded to DefectDojo successfully."

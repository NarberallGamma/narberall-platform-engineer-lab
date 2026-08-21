#!/bin/sh
set -e

# ---------- defaults ----------------------------------------------------------
DEFECTDOJO_ENGAGEMENT_PERIOD="${DEFECTDOJO_ENGAGEMENT_PERIOD:-0}"
DEFECTDOJO_ENGAGEMENT_STATUS="${DEFECTDOJO_ENGAGEMENT_STATUS:-Not Started}"
DEFECTDOJO_ENGAGEMENT_BUILD_SERVER="${DEFECTDOJO_ENGAGEMENT_BUILD_SERVER:-null}"
DEFECTDOJO_ENGAGEMENT_SOURCE_CODE_MANAGEMENT_SERVER="${DEFECTDOJO_ENGAGEMENT_SOURCE_CODE_MANAGEMENT_SERVER:-null}"
DEFECTDOJO_ENGAGEMENT_ORCHESTRATION_ENGINE="${DEFECTDOJO_ENGAGEMENT_ORCHESTRATION_ENGINE:-null}"
DEFECTDOJO_ENGAGEMENT_DEDUPLICATION_ON_ENGAGEMENT="${DEFECTDOJO_ENGAGEMENT_DEDUPLICATION_ON_ENGAGEMENT:-false}"
DEFECTDOJO_ENGAGEMENT_THREAT_MODEL="${DEFECTDOJO_ENGAGEMENT_THREAT_MODEL:-false}"
DEFECTDOJO_ENGAGEMENT_API_TEST="${DEFECTDOJO_ENGAGEMENT_API_TEST:-true}"
DEFECTDOJO_ENGAGEMENT_PEN_TEST="${DEFECTDOJO_ENGAGEMENT_PEN_TEST:-false}"
DEFECTDOJO_ENGAGEMENT_CHECK_LIST="${DEFECTDOJO_ENGAGEMENT_CHECK_LIST:-true}"

# ---------- required variables ------------------------------------------------
_required_vars="DEFECTDOJO_URL DEFECTDOJO_TOKEN DEFECTDOJO_PRODUCTID \
                CI_PIPELINE_ID CI_COMMIT_REF_NAME CI_PROJECT_URL \
                CI_COMMIT_SHORT_SHA CI_COMMIT_SHA"

for _var in $_required_vars; do
    eval "_val=\$$_var"
    if [ -z "$_val" ]; then
        echo "ERROR: Required variable '$_var' is not set." >&2
        exit 1
    fi
done

# ---------- dates -------------------------------------------------------------
TODAY=$(date +%Y-%m-%d)
ENDDAY=$(date -d "+${DEFECTDOJO_ENGAGEMENT_PERIOD} days" +%Y-%m-%d)

# ---------- JSON via jq (safe escaping of commit description) -----------------
PAYLOAD=$(jq -n \
    --arg name "${CI_PIPELINE_ID}" \
    --arg description "${CI_COMMIT_DESCRIPTION}" \
    --arg version "${CI_COMMIT_REF_NAME}" \
    --arg target_start "${TODAY}" \
    --arg target_end "${ENDDAY}" \
    --arg tracker "${CI_PROJECT_URL}/-/issues" \
    --arg status "${DEFECTDOJO_ENGAGEMENT_STATUS}" \
    --arg commit_hash "${CI_COMMIT_SHORT_SHA}" \
    --arg branch_tag "${CI_COMMIT_REF_NAME}" \
    --arg source_code_management_uri "${CI_PROJECT_URL}/-/tree/${CI_COMMIT_SHA}" \
    --argjson product "${DEFECTDOJO_PRODUCTID}" \
    --argjson threat_model "${DEFECTDOJO_ENGAGEMENT_THREAT_MODEL}" \
    --argjson api_test "${DEFECTDOJO_ENGAGEMENT_API_TEST}" \
    --argjson pen_test "${DEFECTDOJO_ENGAGEMENT_PEN_TEST}" \
    --argjson check_list "${DEFECTDOJO_ENGAGEMENT_CHECK_LIST}" \
    --argjson deduplication_on_engagement "${DEFECTDOJO_ENGAGEMENT_DEDUPLICATION_ON_ENGAGEMENT}" \
    --argjson build_server "${DEFECTDOJO_ENGAGEMENT_BUILD_SERVER}" \
    --argjson source_code_management_server "${DEFECTDOJO_ENGAGEMENT_SOURCE_CODE_MANAGEMENT_SERVER}" \
    --argjson orchestration_engine "${DEFECTDOJO_ENGAGEMENT_ORCHESTRATION_ENGINE}" \
    '{
        tags: ["GITLAB-CI"],
        name: $name,
        description: $description,
        version: $version,
        first_contacted: $target_start,
        target_start: $target_start,
        target_end: $target_end,
        reason: "string",
        tracker: $tracker,
        threat_model: $threat_model,
        api_test: $api_test,
        pen_test: $pen_test,
        check_list: $check_list,
        status: $status,
        engagement_type: "CI/CD",
        build_id: $name,
        commit_hash: $commit_hash,
        branch_tag: $branch_tag,
        deduplication_on_engagement: $deduplication_on_engagement,
        product: $product,
        source_code_management_uri: $source_code_management_uri,
        build_server: $build_server,
        source_code_management_server: $source_code_management_server,
        orchestration_engine: $orchestration_engine
    }')

# ---------- create Engagement -------------------------------------------------
echo "==> Creating DefectDojo engagement for pipeline ${CI_PIPELINE_ID}..."

# Split body and HTTP status so jq does not parse them together.
HTTP_STATUS=$(curl --insecure --silent --show-error \
    --location \
    --request POST "${DEFECTDOJO_URL}/engagements/" \
    --header "Authorization: Token ${DEFECTDOJO_TOKEN}" \
    --header "Content-Type: application/json" \
    --data-raw "${PAYLOAD}" \
    --output /tmp/dd_response.json \
    --write-out "%{http_code}")

RESPONSE=$(cat /tmp/dd_response.json)

echo "=== DefectDojo Response (HTTP ${HTTP_STATUS}) ==="
echo "${RESPONSE}"
echo "==========================="

if [ "${HTTP_STATUS}" -ge 400 ]; then
    echo "ERROR: DefectDojo API returned HTTP ${HTTP_STATUS}" >&2
    exit 1
fi

# ---------- extract id --------------------------------------------------------
ENGAGEMENTID=$(echo "${RESPONSE}" | jq -r '.id')

if [ -z "${ENGAGEMENTID}" ] || [ "${ENGAGEMENTID}" = "null" ]; then
    echo "ERROR: Failed to get engagement ID from response." >&2
    exit 1
fi

echo "==> Engagement created successfully. ID=${ENGAGEMENTID}"
echo "DEFECTDOJO_ENGAGEMENTID=${ENGAGEMENTID}" >> defectdojo.env

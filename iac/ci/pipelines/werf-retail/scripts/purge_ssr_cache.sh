#!/bin/sh

CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL}"
CLOUDFLARE_API_KEY="${CLOUDFLARE_API_KEY}"
ZONE_IDS="CHANGE_ME_ZONE_A CHANGE_ME_ZONE_B"
CACHE_TAG="web-ui-shop-ssr-${WERF_ENV}"

missing_vars=""

[ -z "${CLOUDFLARE_EMAIL}" ] && missing_vars="${missing_vars} CLOUDFLARE_EMAIL"
[ -z "${CLOUDFLARE_API_KEY}" ] && missing_vars="${missing_vars} CLOUDFLARE_API_KEY"
[ -z "${WERF_ENV}" ] && missing_vars="${missing_vars} WERF_ENV"

if [ -n "${missing_vars}" ]; then
  echo "Error: environment variables${missing_vars} are not set."
  exit 1
fi

purge_cache() {
  zone_id=$1
  url="https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache"
  data='{"tags":["'"${CACHE_TAG}"'"]}'
  response=$(curl -s -X POST \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${data}" \
    "${url}")

  if echo "${response}" | grep -q '"success":true'; then
    echo "Result: $(echo "${response}" | grep -o '"result":[^,]*')"
    return 0
  else
    echo "Error response from API: ${response}"
    return 1
  fi
}

echo "Purging cache for tag: ${CACHE_TAG}."

for zone_id in ${ZONE_IDS}; do
  if purge_cache "${zone_id}"; then
    echo "Cache successfully purged in zone ${zone_id}!"
  else
    echo "Error purging cache in zone ${zone_id}."
    exit 1
  fi
done

echo "Cache successfully purged in all zones!"

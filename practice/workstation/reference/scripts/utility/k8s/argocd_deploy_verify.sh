#!/usr/bin/env bash
# estate: ArgoCD sync wait + optional rollout restart + status verify.
# Usage: see --help. Script-first: run via wsl bash /path/to/argocd_deploy_verify.sh
set -euo pipefail

CLUSTER=""
NS_APP=argocd
NS_WORK=apps
APPS=()
RESTARTS=()
OUT=""
WAIT_SYNC=1
WAIT_HEALTH=1
MAX_WAIT=90
SLEEP=10
RESTART_AFTER=1

usage() {
  cat <<'EOF'
argocd_deploy_verify.sh - ArgoCD sync, rollout restart, verify

Options:
  --cluster NAME          preprod | prod (required)
  --app NAME              ArgoCD Application name (repeatable)
  --restart DEPLOY        deployment or statefulset/name to rollout restart (repeatable)
  --namespace NS          workload namespace (default: apps)
  --out FILE              tee log path
  --no-restart            skip rollout restart (only wait ArgoCD)
  --no-wait               skip ArgoCD wait loop
  -h, --help

Examples:
  ... --cluster preprod --app app-adapter \
      --restart deploy/app-adapter-application

  ... --cluster prod --app id-service \
      --restart statefulset/keycloak --no-restart
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --app) APPS+=("$2"); shift 2 ;;
    --restart) RESTARTS+=("$2"); shift 2 ;;
    --namespace) NS_WORK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --no-restart) RESTART_AFTER=0; shift ;;
    --no-wait) WAIT_SYNC=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$CLUSTER" ]] || { echo "error: --cluster required"; exit 1; }
[[ ${#APPS[@]} -gt 0 ]] || { echo "error: at least one --app required"; exit 1; }

K8S_DIR="${HOME}/scripts/k8s"
[[ -d "$K8S_DIR" ]] || { echo "error: $K8S_DIR not found"; exit 1; }

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  exec > >(tee "$OUT") 2>&1
fi

cd "$K8S_DIR"
./kube_switch.sh "$CLUSTER" >/dev/null

echo "=== argocd_deploy_verify cluster=$CLUSTER $(date -Is) ==="

for APP in "${APPS[@]}"; do
  echo "--- refresh $APP ---"
  kubectl -n "$NS_APP" annotate application "$APP" argocd.argoproj.io/refresh=hard --overwrite
done

if [[ "$WAIT_SYNC" -eq 1 ]]; then
  sleep 15
  for APP in "${APPS[@]}"; do
    echo "--- wait ArgoCD $APP ---"
    for i in $(seq 1 "$MAX_WAIT"); do
      SYNC=$(kubectl -n "$NS_APP" get application "$APP" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "?")
      HEALTH=$(kubectl -n "$NS_APP" get application "$APP" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "?")
      REV=$(kubectl -n "$NS_APP" get application "$APP" -o jsonpath='{.status.sync.revision}' 2>/dev/null || echo "?")
      echo "  t=$i sync=$SYNC health=$HEALTH rev=${REV:0:8}"
      ok_sync=0 ok_health=0
      [[ "$SYNC" == "Synced" ]] && ok_sync=1
      if [[ "$WAIT_HEALTH" -eq 1 ]]; then
        [[ "$HEALTH" == "Healthy" ]] && ok_health=1
      else
        ok_health=1
      fi
      if [[ $ok_sync -eq 1 && $ok_health -eq 1 ]]; then break; fi
      if (( i % 6 == 0 )); then
        kubectl -n "$NS_APP" annotate application "$APP" argocd.argoproj.io/refresh=hard --overwrite
      fi
      sleep "$SLEEP"
    done
    kubectl -n "$NS_APP" get application "$APP" -o wide
  done
fi

if [[ "$RESTART_AFTER" -eq 1 && ${#RESTARTS[@]} -gt 0 ]]; then
  echo "--- rollout restart (required for new env in secret/configmap) ---"
  for R in "${RESTARTS[@]}"; do
    kind=${R%%/*}
    name=${R#*/}
    case "$kind" in
      deploy|deployment)
        kubectl -n "$NS_WORK" rollout restart "deploy/$name"
        kubectl -n "$NS_WORK" rollout status "deploy/$name" --timeout=600s
        ;;
      sts|statefulset)
        kubectl -n "$NS_WORK" rollout restart "statefulset/$name"
        kubectl -n "$NS_WORK" rollout status "statefulset/$name" --timeout=600s
        ;;
      *)
        echo "unsupported restart kind: $kind (use deploy/NAME or statefulset/NAME)"
        exit 1
        ;;
    esac
  done
fi

echo "--- workload pods (recent) ---"
for APP in "${APPS[@]}"; do
  kubectl -n "$NS_WORK" get pod -l "app.kubernetes.io/instance=$APP" -o wide 2>/dev/null \
    || kubectl -n "$NS_WORK" get pod | grep -i "$APP" || true
done

echo "=== done ==="

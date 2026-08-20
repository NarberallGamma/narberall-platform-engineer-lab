#!/usr/bin/env bash
# Vendor official External Secrets Operator Helm chart into external-secrets/charts/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHARTS_DIR="$ESO_DIR/charts"
ESO_VERSION="${ESO_VERSION:-2.9.0}"
ESO_REPO="${ESO_REPO:-https://charts.external-secrets.io}"

helm repo add external-secrets "$ESO_REPO" 2>/dev/null || true
helm repo update external-secrets

rm -rf "$CHARTS_DIR/external-secrets"
mkdir -p "$CHARTS_DIR"

helm pull external-secrets/external-secrets --version "$ESO_VERSION" --untar -d "$CHARTS_DIR"

echo "Vendored External Secrets ${ESO_VERSION}:"
grep -E '^(name|version|appVersion):' "$CHARTS_DIR/external-secrets/Chart.yaml"

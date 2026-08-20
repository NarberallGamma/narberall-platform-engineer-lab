#!/usr/bin/env bash
# Vendor official Istio Helm charts into istio/charts/ (one-time or on version bump).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISTIO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHARTS_DIR="$ISTIO_DIR/charts"
ISTIO_VERSION="${ISTIO_VERSION:-1.30.3}"
ISTIO_REPO="${ISTIO_REPO:-https://istio-release.storage.googleapis.com/charts}"

helm repo add istio "$ISTIO_REPO" 2>/dev/null || true
helm repo update istio

rm -rf "$CHARTS_DIR/base" "$CHARTS_DIR/istiod"
mkdir -p "$CHARTS_DIR"

helm pull istio/base --version "$ISTIO_VERSION" --untar -d "$CHARTS_DIR"
helm pull istio/istiod --version "$ISTIO_VERSION" --untar -d "$CHARTS_DIR"

echo "Vendored Istio ${ISTIO_VERSION}:"
grep -E '^(name|version|appVersion):' "$CHARTS_DIR/base/Chart.yaml" "$CHARTS_DIR/istiod/Chart.yaml"

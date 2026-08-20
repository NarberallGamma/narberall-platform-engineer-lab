#!/usr/bin/env bash
# Build ansible-runner. Run from this directory.
set -euo pipefail

IMAGE_REPO="${IMAGE_REPO:-example/ansible-runner}"
IMAGE_TAG="${IMAGE_TAG:-1.1}"
FULL_IMAGE="${IMAGE_REPO}:${IMAGE_TAG}"
BUILD_EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cache) BUILD_EXTRA+=(--no-cache); shift ;;
    -t|--tag)   FULL_IMAGE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: build_ansible_runner.sh [--no-cache] [-t image:tag]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

CONTEXT="$(cd "$(dirname "$0")" && pwd)"
echo "Context:    $CONTEXT"
echo "Image:      $FULL_IMAGE"

docker build "${BUILD_EXTRA[@]}" \
  -t "$FULL_IMAGE" \
  -f "$CONTEXT/Dockerfile" \
  "$CONTEXT"

echo
echo "Done: $FULL_IMAGE"
echo "For run scripts: export ANSIBLE_IMAGE=$FULL_IMAGE"

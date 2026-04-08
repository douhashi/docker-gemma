#!/bin/bash
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-douhashi/docker-gemma}"
TAG="${TAG:-latest}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "==> Building image: ${FULL_IMAGE}"
docker build --platform linux/amd64 -t "${FULL_IMAGE}" .

echo "==> Pushing image: ${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

echo "==> Done: ${FULL_IMAGE}"

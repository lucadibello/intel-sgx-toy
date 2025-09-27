#!/usr/bin/env bash
set -euo pipefail

[ -f ".devcontainer.env" ] && source ".devcontainer.env"

IMAGE_NAME=${IMAGE_NAME:-my-devcontainer}
DOCKERFILE=${DOCKERFILE:-.devcontainer/Dockerfile}
DEV_USERNAME=${DEV_USERNAME:-dev}
DEV_UID=${DEV_UID:-1000}
DEV_GID=${DEV_GID:-1000}

[ -f "$DOCKERFILE" ] || { echo "Missing $DOCKERFILE"; exit 1; }

# Single-line build to avoid buildx arg parsing quirks
docker build -t "$IMAGE_NAME" \
  --build-arg USER_NAME="$DEV_USERNAME" \
  --build-arg USER_UID="$DEV_UID" \
  --build-arg USER_GID="$DEV_GID" \
  -f "$DOCKERFILE" .

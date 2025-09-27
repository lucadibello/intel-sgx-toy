#!/usr/bin/env bash
set -euo pipefail

[ -f ".devcontainer.env" ] && source ".devcontainer.env"

CONTAINER_NAME=${CONTAINER_NAME:-devcontainer}

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
echo "Removed $CONTAINER_NAME (if it existed)."

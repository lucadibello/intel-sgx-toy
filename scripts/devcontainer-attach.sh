#!/usr/bin/env bash
set -euo pipefail

[ -f ".devcontainer.env" ] && source ".devcontainer.env"

CONTAINER_NAME=${CONTAINER_NAME:-devcontainer}

docker exec -it "$CONTAINER_NAME" bash || docker exec -it "$CONTAINER_NAME" sh

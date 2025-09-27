#!/usr/bin/env bash
set -euo pipefail

[ -f ".devcontainer.env" ] && source ".devcontainer.env"

CONTAINER_NAME=${CONTAINER_NAME:-devcontainer}
SSH_BIND_HOST=${SSH_BIND_HOST:-127.0.0.1}
SSH_PORT=${SSH_PORT:-2222}
LOCAL_TUNNEL_PORT=${LOCAL_TUNNEL_PORT:-8022}
USERNAME=${USERNAME:-${USER:-dev}}
WORKDIR=${WORKDIR:-/workspaces/project}

echo
echo "=== Cluster side (running) ==="
echo "Container:                ${CONTAINER_NAME}"
echo "SSH exposed (cluster):    ${SSH_BIND_HOST}:${SSH_PORT}  -> container :22"
echo "Workspace mounted at:     ${WORKDIR}"
echo
echo "=== From your laptop, create the tunnel ==="
echo "ssh -N -L ${LOCAL_TUNNEL_PORT}:127.0.0.1:${SSH_PORT} <cluster_user>@<cluster_host>"
echo
echo "Then connect your IDE/SSH client to:"
echo "  Host: localhost"
echo "  Port: ${LOCAL_TUNNEL_PORT}"
echo "  User: ${USERNAME}"
echo
echo "CLI example:"
echo "  ssh -p ${LOCAL_TUNNEL_PORT} ${USERNAME}@127.0.0.1"
echo

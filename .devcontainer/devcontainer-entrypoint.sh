#!/usr/bin/env bash
set -euo pipefail

# Defaults match Dockerfile ARGs (can be overridden via env)
DEVUSER="${DEVUSER:-${USER_NAME:-dev}}"
DEVUID="${DEVUID:-${USER_UID:-1000}}"
DEVGID="${DEVGID:-${USER_GID:-1000}}"

# Ensure ssh runtime dir
mkdir -p /var/run/sshd

# Generate host keys if missing (idempotent)
if ! ls /etc/ssh/ssh_host_* >/dev/null 2>&1; then
  ssh-keygen -A
fi

# If the user got recreated with different IDs via env, ensure it exists (idempotent best-effort)
if ! id -u "$DEVUSER" >/dev/null 2>&1; then
  groupadd -g "$DEVGID" "$DEVUSER" || true
  useradd -m -u "$DEVUID" -g "$DEVGID" -s /bin/bash "$DEVUSER" || true
  usermod -aG sudo "$DEVUSER" || true
fi

# Configure authorized_keys from either:
#  - env SSH_PUBKEY (single key string)
#  - mounted file /ssh/authorized_keys (one or more keys)
USER_HOME="$(getent passwd "$DEVUSER" | cut -d: -f6)"
SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTH_KEYS"
chown -R "$DEVUSER:$DEVGID" "$SSH_DIR"

if [ -n "${SSH_PUBKEY:-}" ]; then
  # Append (dedup later)
  echo "$SSH_PUBKEY" >> "$AUTH_KEYS"
fi
if [ -f /ssh/authorized_keys ]; then
  cat /ssh/authorized_keys >> "$AUTH_KEYS"
fi
# Deduplicate keys
sort -u "$AUTH_KEYS" -o "$AUTH_KEYS" || true
chown "$DEVUSER:$DEVGID" "$AUTH_KEYS"

# Helpful: print how to connect (once)
if [ -n "${PRINT_SSH_HINTS:-1}" ]; then
  echo "SSHD ready. Example:"
  echo "  docker run -d -p 2222:22 -e SSH_PUBKEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" <image>"
  echo "  ssh -p 2222 ${DEVUSER}@127.0.0.1"
fi

# Exec original CMD (sshd -D -e by default)
exec "$@"

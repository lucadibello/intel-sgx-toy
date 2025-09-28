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

# Ensure group/user exist and match requested IDs
if getent group "$DEVGID" >/dev/null; then
  EXIST_GRP="$(getent group "$DEVGID" | cut -d: -f1)"
  [ "$EXIST_GRP" = "$DEVUSER" ] || groupmod -n "$DEVUSER" "$EXIST_GRP"
elif getent group "$DEVUSER" >/dev/null; then
  groupmod -g "$DEVGID" "$DEVUSER"
else
  groupadd -g "$DEVGID" "$DEVUSER"
fi

if id -u "$DEVUSER" >/dev/null 2>&1; then
  CUR_UID="$(id -u "$DEVUSER")"
  CUR_GID="$(id -g "$DEVUSER")"
  [ "$CUR_GID" = "$DEVGID" ] || groupmod -g "$DEVGID" "$DEVUSER" || true
  if [ "$CUR_UID" != "$DEVUID" ]; then
    usermod -u "$DEVUID" -g "$DEVGID" "$DEVUSER" || true
    USER_HOME="$(getent passwd "$DEVUSER" | cut -d: -f6)"
    chown -R "$DEVUID:$DEVGID" "$USER_HOME" 2>/dev/null || true
  fi
else
  useradd -m -s /bin/bash -u "$DEVUID" -g "$DEVGID" "$DEVUSER"
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

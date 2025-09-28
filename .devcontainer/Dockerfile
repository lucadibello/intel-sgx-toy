# Ubuntu 22.04 + OpenEnclave
FROM openenclavedockerregistry.azurecr.io/oetools-22.04:2025.03.13148

# --- Dev user setup (override via build args if needed) ---
ARG USER_NAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Install SSH server + sudo + tini (to be a sane PID 1)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openssh-server sudo tini ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create dev user matching host UID/GID to avoid permission issues
RUN set -eux; \
  if getent group "${USER_GID}" >/dev/null; then \
    EXIST_GRP="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    [ "${EXIST_GRP}" = "${USER_NAME}" ] || groupmod -n "${USER_NAME}" "${EXIST_GRP}"; \
  elif getent group "${USER_NAME}" >/dev/null; then \
    groupmod -g "${USER_GID}" "${USER_NAME}"; \
  else \
    groupadd -g "${USER_GID}" "${USER_NAME}"; \
  fi; \
  if getent passwd "${USER_UID}" >/dev/null; then \
    EXIST_USER="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
    if [ "${EXIST_USER}" != "${USER_NAME}" ]; then \
      usermod -l "${USER_NAME}" "${EXIST_USER}"; \
      usermod -d "/home/${USER_NAME}" -m "${USER_NAME}"; \
    fi; \
    usermod -u "${USER_UID}" -g "${USER_GID}" "${USER_NAME}" || true; \
  elif id -u "${USER_NAME}" >/dev/null 2>&1; then \
    usermod -u "${USER_UID}" -g "${USER_GID}" "${USER_NAME}" || true; \
  else \
    useradd -m -s /bin/bash -u "${USER_UID}" -g "${USER_GID}" "${USER_NAME}"; \
  fi; \
  usermod -aG sudo "${USER_NAME}"; \
  echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-"${USER_NAME}"; \
  chmod 0440 /etc/sudoers.d/90-"${USER_NAME}"

# SSHD config: key-only, no root password login
RUN mkdir -p /var/run/sshd /etc/ssh/sshd_config.d && \
    printf '%s\n' \
    'PasswordAuthentication no' \
    'PermitRootLogin prohibit-password' \
    'PubkeyAuthentication yes' \
    'ChallengeResponseAuthentication no' \
    'UsePAM yes' \
    > /etc/ssh/sshd_config.d/devcontainer.conf

# copy override entrypoint script (see below)
COPY .devcontainer/devcontainer-entrypoint.sh /usr/local/bin/devcontainer-entrypoint
RUN chmod +x /usr/local/bin/devcontainer-entrypoint

# Runtime init script: set authorized_keys from env or mORKDIR ${WORKSPACE}
EXPOSE 22

# tini as PID 1, then our entrypoint will exec sshd (or any CMD you pass)
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devcontainer-entrypoint"]
CMD ["/usr/sbin/sshd", "-D", "-e"]

# Ubuntu 22.04 + OpenEnclave
FROM openenclavedockerregistry.azurecr.io/oetools-22.04:2025.03.13148

# --- Dev user setup (override via build args if needed) ---
ARG USER_NAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG OE_SDK_VERSION=0.19.13 # latest version

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

# add dev user in `sgx` group to access sgx device without sudo. Create the group first if it doesn't exist
RUN if ! getent group sgx >/dev/null; then groupadd sgx; fi && \
    usermod -aG sgx ${USER_NAME}

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

# download and install Open Enclave SDK
WORKDIR /tmp
RUN wget -q https://github.com/openenclave/openenclave/releases/download/v0.19.13/Ubuntu_2204_open-enclave_${OE_SDK_VERSION}_amd64.deb && \
    dpkg -i Ubuntu_2204_open-enclave_${OE_SDK_VERSION}_amd64.deb && \
    rm Ubuntu_2204_open-enclave_${OE_SDK_VERSION}_amd64.deb

WORKDIR /workspaces/project

# ensure open-enclave environment variables are set
RUN echo 'export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/opt/openenclave/share/pkgconfig"' >> /etc/profile.d/openenclave.sh && \
    echo 'export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/openenclave/lib/openenclave/cmake"' >> /etc/profile.d/openenclave.sh && \
    echo 'export PATH="${PATH}:/opt/openenclave/bin"' >> /etc/profile.d/openenclave.sh && \
    echo 'export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/openenclave/lib"' >> /etc/profile.d/openenclave.sh && \
    chmod +x /etc/profile.d/openenclave.sh

# generate new ssh key to authenticate with git repo
RUN mkdir -p /home/${USER_NAME}/.ssh && \
    ssh-keygen -t ed25519 -f /home/${USER_NAME}/.ssh/id_ed25519 -N '' -C 'devcontainer-key' && \
    chmod 700 /home/${USER_NAME}/.ssh && \
    chmod 600 /home/${USER_NAME}/.ssh/id_ed25519 && \
    echo "==== Generated SSH Public Key ====" && \
    cat /home/${USER_NAME}/.ssh/id_ed25519.pub && \
    echo "================================="

# Expose ssh port
EXPOSE 22

# tini as PID 1, then our entrypoint will exec sshd (or any CMD you pass)
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devcontainer-entrypoint"]
CMD ["/usr/sbin/sshd", "-D", "-e"]

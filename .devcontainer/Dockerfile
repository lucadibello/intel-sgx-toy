# Base (your Open Enclave image)
FROM openenclavedockerregistry.azurecr.io/openenclave-base-ubuntu-22.04:2025.03.13148

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
RUN groupadd --gid ${USER_GID} ${USER_NAME} \
    && useradd -m -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} ${USER_NAME} \
    && usermod -aG sudo ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-${USER_NAME} \
    && chmod 0440 /etc/sudoers.d/90-${USER_NAME}

# SSHD config: key-only, no root password login
RUN mkdir -p /var/run/sshd /etc/ssh/sshd_config.d && \
    printf '%s\n' \
    'PasswordAuthentication no' \
    'PermitRootLogin prohibit-password' \
    'PubkeyAuthentication yes' \
    'ChallengeResponseAuthentication no' \
    'UsePAM yes' \
    > /etc/ssh/sshd_config.d/devcontainer.conf

# Runtime init script: set authorized_keys from env or mORKDIR ${WORKSPACE}

EXPOSE 22

# tini as PID 1, then our entrypoint will exec sshd (or any CMD you pass)
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devcontainer-entrypoint"]
CMD ["/usr/sbin/sshd", "-D", "-e"]

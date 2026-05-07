# --------------------------------------------------------------
#  Ubuntu 22.04 base
# --------------------------------------------------------------
FROM ubuntu:22.04

# ------------------------------------------------------------------
#  Core packages (locale, openssh, wget, unzip, ca‑certificates)
# ------------------------------------------------------------------
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        locales \
        openssh-server \
        wget \
        unzip \
        ca-certificates \
        tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------
#  Locale (required for many tools)
# --------------------------------------------------------------
RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# --------------------------------------------------------------
#  Install ngrok (latest v3 stable)
# --------------------------------------------------------------
ARG NGROK_VERSION=3.5.0               # bump if a newer version appears
ENV NGROK_VERSION=${NGROK_VERSION}
ENV NGROK_URL=https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-v3-stable-linux-amd64.zip

RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# --------------------------------------------------------------
#  SSH configuration – allow root login with password
# --------------------------------------------------------------
RUN mkdir -p /var/run/sshd && \
    # Disable PAM (simpler on Ubuntu 22.04) \
    sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    # Generate host keys (ssh-keygen is now present) \
    ssh-keygen -A

# ------------------------------------------------------------------
#  Runtime environment variables (set via Railway “Variables” UI)
# ------------------------------------------------------------------
ENV NGROK_TOKEN=''          # ← you must provide this
ENV ROOT_PASSWORD='morning' # ← change if you wish

# ------------------------------------------------------------------
#  Create entrypoint script (saved as /usr/local/bin/entrypoint.sh)
# ------------------------------------------------------------------
RUN echo '#!/usr/bin/env bash' > /usr/local/bin/entrypoint.sh && \
    echo 'set -euo pipefail' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 1️⃣  Set root password (only once per container start)' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [[ -n "${ROOT_PASSWORD:-}" ]]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '    echo "root:${ROOT_PASSWORD}" | chpasswd' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 2️⃣  Configure ngrok – needs a valid token' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [[ -z "${NGROK_TOKEN:-}" ]]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '    echo "❌ NGROK_TOKEN env‑var not set – aborting."' >> /usr/local/bin/entrypoint.sh && \
    echo '    exit 1' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# Add the token (ngrok ignores repeats)' >> /usr/local/bin/entrypoint.sh && \
    echo 'ngrok config add-authtoken "${NGROK_TOKEN}" >/dev/null' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 3️⃣  Start ngrok in background, forwarding TCP 22 (SSH)' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'ngrok tcp 22 --log=stdout &' >> /usr/local/bin/entrypoint.sh && \
    echo 'NGROK_PID=$!' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# Give ngrok a few seconds to obtain the public URL' >> /usr/local/bin/entrypoint.sh && \
    echo 'sleep 5' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "===== ngrok tunnel info ====="' >> /usr/local/bin/entrypoint.sh && \
    echo 'ngrok tunnels list | grep tcp || true' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "============================="' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 4️⃣  Run the SSH daemon in foreground (keeps Docker alive)' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'exec /usr/sbin/sshd -D -e' >> /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# ------------------------------------------------------------------
#  Ports we expose (SSH + optional ngrok web UI)
# ------------------------------------------------------------------
EXPOSE 22    # SSH (ngrok forwards to this)
EXPOSE 4040  # ngrok web UI (optional)

# ------------------------------------------------------------------
#  Container start command
# ------------------------------------------------------------------
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

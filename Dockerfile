# --------------------------------------------------------------
#  Ubuntu 22.04 base
# --------------------------------------------------------------
FROM ubuntu:22.04

# ------------------------------------------------------------------
#  Core packages (locale, openssh, wget, curl, unzip, ca‑certificates, tzdata)
# ------------------------------------------------------------------
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        locales \
        openssh-server \
        wget \
        curl \
        unzip \
        ca-certificates \
        tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------
#  Locale (required for many tools)
# --------------------------------------------------------------
RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --------------------------------------------------------------
#  Install ngrok (latest v3 stable)
# --------------------------------------------------------------
# Generic stable URL (always points to newest ngrok v3)
ENV NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip

RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# --------------------------------------------------------------
#  SSH configuration – allow root login with password
# --------------------------------------------------------------
RUN mkdir -p /var/run/sshd && \
    # Disable PAM (simpler on Ubuntu 22.04)
    sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    # Generate host keys
    ssh-keygen -A

# ------------------------------------------------------------------
#  Runtime environment variables (set via Railway “Variables” UI)
# ------------------------------------------------------------------
ENV NGROK_TOKEN=''          # Must be set in Railway UI
ENV ROOT_PASSWORD='morning' # Change this in production

# ------------------------------------------------------------------
#  Create entrypoint script
# ------------------------------------------------------------------
RUN echo '#!/usr/bin/env bash' > /usr/local/bin/entrypoint.sh && \
    echo 'set -euo pipefail' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 1️⃣  Set root password' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [[ -n "${ROOT_PASSWORD:-}" ]]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '    echo "root:${ROOT_PASSWORD}" | chpasswd' >> /usr/local/bin/entrypoint.sh && \
    echo '    if [[ "${ROOT_PASSWORD}" == "morning" ]]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '        echo "⚠️  Using default root password (morning) – please change it!"' >> /usr/local/bin/entrypoint.sh && \
    echo '    fi' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 2️⃣  Configure ngrok' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [[ -z "${NGROK_TOKEN:-}" ]]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '    echo "❌ NGROK_TOKEN env var not set – aborting."' >> /usr/local/bin/entrypoint.sh && \
    echo '    exit 1' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo 'ngrok config add-authtoken "${NGROK_TOKEN}" >/dev/null' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 3️⃣  Start ngrok (TCP on port 22) and wait for public URL' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'ngrok tcp 22 --log=stdout &' >> /usr/local/bin/entrypoint.sh && \
    echo 'NGROK_PID=$!' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# Wait for ngrok API to become available' >> /usr/local/bin/entrypoint.sh && \
    echo 'for i in {1..10}; do' >> /usr/local/bin/entrypoint.sh && \
    echo '    if curl -s http://localhost:4040/api/tunnels > /dev/null 2>&1; then' >> /usr/local/bin/entrypoint.sh && \
    echo '        break' >> /usr/local/bin/entrypoint.sh && \
    echo '    fi' >> /usr/local/bin/entrypoint.sh && \
    echo '    sleep 1' >> /usr/local/bin/entrypoint.sh && \
    echo 'done' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# Extract public TCP URL from ngrok API' >> /usr/local/bin/entrypoint.sh && \
    echo 'TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"'"'tcp://[^"]*'"'"' | head -1)' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [[ -z "$TUNNEL_URL" ]]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '    echo "❌ Failed to obtain ngrok tunnel URL"' >> /usr/local/bin/entrypoint.sh && \
    echo '    exit 1' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "===== ngrok tunnel ready ====="' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "ssh root@${TUNNEL_URL#tcp://}"' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "==============================="' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo '# 4️⃣  Run SSH daemon in foreground' >> /usr/local/bin/entrypoint.sh && \
    echo '# ------------------------------------------------------------' >> /usr/local/bin/entrypoint.sh && \
    echo 'exec /usr/sbin/sshd -D -e' >> /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# ------------------------------------------------------------------
#  Ports (SSH + ngrok web UI)
# ------------------------------------------------------------------
EXPOSE 22 4040

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# --------------------------------------------------------------
#  Ubuntu 22.04 – SSH over ngrok (no PAM, no privilege separation)
# --------------------------------------------------------------
FROM ubuntu:22.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        locales \
        openssh-server \
        wget \
        curl \
        unzip \
        ca-certificates \
        tzdata \
        bash \
        procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install ngrok
ENV NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# Configure SSH – disable everything that can cause issues in containers
RUN mkdir -p /var/run/sshd && \
    # Remove any existing configuration that might interfere
    sed -i 's/^#\?UsePAM.*/UsePAM no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?UsePrivilegeSeparation.*/UsePrivilegeSeparation no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config && \
    # Force listening on all interfaces
    echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# Ensure a valid shell and pseudo‑terminal directory
RUN test -x /bin/bash || (apt-get update && apt-get install -y bash) && \
    sed -i 's|^root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd && \
    mkdir -p /dev/pts && chmod 755 /dev/pts

ENV NGROK_TOKEN=''
ENV ROOT_PASSWORD='morning'

# Entrypoint script – no extra options, just clean sshd
RUN <<'EOF' cat > /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
    if [[ "${ROOT_PASSWORD}" == "morning" ]]; then
        echo "⚠️  Using default root password – please change it!"
    fi
fi

if [[ -z "${NGROK_TOKEN:-}" ]]; then
    echo "❌ NGROK_TOKEN env var not set – aborting."
    exit 1
fi

ngrok config add-authtoken "${NGROK_TOKEN}" >/dev/null
ngrok tcp 22 --log=stdout &
NGROK_PID=$!

for i in {1..10}; do
    if curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'tcp://[^"]*' | head -1)
if [[ -z "$TUNNEL_URL" ]]; then
    echo "❌ Failed to obtain ngrok tunnel URL"
    exit 1
fi

echo "===== ngrok tunnel ready ====="
echo "ssh root@${TUNNEL_URL#tcp://}"
echo "==============================="

# Start sshd with no extra options (configuration file already set)
exec /usr/sbin/sshd -D -e
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 4040
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

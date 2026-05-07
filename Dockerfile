# --------------------------------------------------------------
#  Ubuntu 22.04 base
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
        tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ngrok install (generic stable URL)
ENV NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# SSH configuration
RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PrintLastLog no' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# FIX: Create utmp/wtmp/lastlog files to avoid "logout() returned an error"
RUN touch /var/log/wtmp /var/log/btmp /var/log/lastlog && \
    chown root:utmp /var/log/wtmp /var/log/btmp && \
    chmod 664 /var/log/wtmp /var/log/btmp && \
    chmod 644 /var/log/lastlog

ENV NGROK_TOKEN=''
ENV ROOT_PASSWORD='morning'

# Entrypoint script (heredoc style - safe and clean)
RUN <<'EOF' cat > /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
    if [[ "${ROOT_PASSWORD}" == "morning" ]]; then
        echo "⚠️  Using default root password – change it!"
    fi
fi

if [[ -z "${NGROK_TOKEN:-}" ]]; then
    echo "❌ NGROK_TOKEN env var not set – aborting."
    exit 1
fi

ngrok config add-authtoken "${NGROK_TOKEN}" >/dev/null
ngrok tcp 22 --log=stdout &
NGROK_PID=$!

# Wait for ngrok API (max 10 retries)
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

exec /usr/sbin/sshd -D -e
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 4040
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# --------------------------------------------------------------
#  Ubuntu 22.04 base
# --------------------------------------------------------------
FROM ubuntu:22.04

# --------------------------------------------------------------
#  Core packages (locale, openssh, curl, wget, unzip, ca‑certs, tzdata)
# --------------------------------------------------------------
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
ENV NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# --------------------------------------------------------------
#  SSH configuration – allow root login with password
# --------------------------------------------------------------
RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PrintLastLog no' >> /etc/ssh/sshd_config && \
    echo 'LogLevel DEBUG3' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# --------------------------------------------------------------
#  Fix: Create utmp/wtmp/lastlog files to avoid logout errors
# --------------------------------------------------------------
RUN touch /var/log/wtmp /var/log/btmp /var/log/lastlog && \
    chown root:utmp /var/log/wtmp /var/log/btmp && \
    chmod 664 /var/log/wtmp /var/log/btmp && \
    chmod 644 /var/log/lastlog

# --------------------------------------------------------------
#  Fix: Ensure root has a valid shell and /dev/pts exists
# --------------------------------------------------------------
RUN test -x /bin/bash || (apt-get update && apt-get install -y bash) && \
    sed -i 's|^root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd && \
    mkdir -p /dev/pts && \
    chmod 755 /dev/pts

# --------------------------------------------------------------
#  Runtime environment variables (set via Railway UI)
# --------------------------------------------------------------
ENV NGROK_TOKEN=''
ENV ROOT_PASSWORD='morning'

# --------------------------------------------------------------
#  Entrypoint script (heredoc – clean and safe)
# --------------------------------------------------------------
RUN <<'EOF' cat > /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

# 1. Set root password
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
    if [[ "${ROOT_PASSWORD}" == "morning" ]]; then
        echo "⚠️  Using default root password – please change it!"
    fi
fi

# 2. Check ngrok token
if [[ -z "${NGROK_TOKEN:-}" ]]; then
    echo "❌ NGROK_TOKEN env var not set – aborting."
    exit 1
fi

# 3. Configure ngrok and start tunnel
ngrok config add-authtoken "${NGROK_TOKEN}" >/dev/null
ngrok tcp 22 --log=stdout &
NGROK_PID=$!

# Wait for ngrok API (max 10 seconds)
for i in {1..10}; do
    if curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Extract public URL
TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'tcp://[^"]*' | head -1)
if [[ -z "$TUNNEL_URL" ]]; then
    echo "❌ Failed to obtain ngrok tunnel URL"
    exit 1
fi

echo "===== ngrok tunnel ready ====="
echo "ssh root@${TUNNEL_URL#tcp://}"
echo "==============================="

# 4. Start SSH daemon in foreground
exec /usr/sbin/sshd -D -e
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

# --------------------------------------------------------------
#  Expose ports (SSH + ngrok web UI)
# --------------------------------------------------------------
EXPOSE 22 4040

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

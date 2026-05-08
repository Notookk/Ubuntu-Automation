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
        tzdata \
        bash \
        procps \
        libpam-modules \
        libpam-runtime \
        libpam0g \
        login && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install ngrok (latest v3 stable)
ENV NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# SSH configuration – allow root, disable sandbox to avoid audit errors
RUN mkdir -p /var/run/sshd /var/log && \
    sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PrintLastLog no' >> /etc/ssh/sshd_config && \
    echo 'PrintMotd no' >> /etc/ssh/sshd_config && \
    echo 'LogLevel DEBUG3' >> /etc/ssh/sshd_config && \
    echo 'Sandbox no' >> /etc/ssh/sshd_config && \
    echo 'UsePrivilegeSeparation no' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# Create log files for utmp/wtmp
RUN touch /var/log/wtmp /var/log/btmp /var/log/lastlog && \
    chown root:utmp /var/log/wtmp /var/log/btmp && \
    chmod 664 /var/log/wtmp /var/log/btmp && \
    chmod 644 /var/log/lastlog

# Ensure valid shell and /dev/pts
RUN test -x /bin/bash || (apt-get update && apt-get install -y bash) && \
    sed -i 's|^root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd && \
    mkdir -p /dev/pts && chmod 755 /dev/pts

# Minimal PAM config
RUN cat > /etc/pam.d/sshd <<EOF
auth       required     pam_unix.so     nullok
account    required     pam_unix.so
session    required     pam_unix.so
session    required     pam_loginuid.so
EOF

ENV NGROK_TOKEN=''
ENV ROOT_PASSWORD='morning'

# Entrypoint script
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

exec /usr/sbin/sshd -D -e
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 4040
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

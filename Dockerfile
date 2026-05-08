FROM ubuntu:22.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        locales \
        dropbear \
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

ENV NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN wget -qO /tmp/ngrok.zip "${NGROK_URL}" && \
    unzip -q /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

# Generate all host key types (including DSS to silence warning)
RUN mkdir -p /etc/dropbear && \
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key && \
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key && \
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key && \
    dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key 2>/dev/null || true

ENV NGROK_TOKEN=''
ENV ROOT_PASSWORD='morning'

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

# Start Dropbear:
# -p 22      port
# -F         foreground
# -E         log to stderr
# -s         disable public key auth (force password)
# -r keys    specify host keys
exec /usr/sbin/dropbear -p 22 -F -E -s \
    -r /etc/dropbear/dropbear_rsa_host_key \
    -r /etc/dropbear/dropbear_ecdsa_host_key \
    -r /etc/dropbear/dropbear_ed25519_host_key \
    -r /etc/dropbear/dropbear_dss_host_key
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 4040
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y \
    locales \
    dropbear \
    wget \
    curl \
    unzip \
    ca-certificates \
    tzdata \
    bash \
    procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Locale
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

# Generate Dropbear host keys
RUN mkdir -p /etc/dropbear && \
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key && \
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key && \
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

# Default password
ENV ROOT_PASSWORD=morning

# Set password during build too
RUN echo "root:${ROOT_PASSWORD}" | chpasswd

# Ngrok token (SET THIS IN RAILWAY VARIABLES)
ENV NGROK_TOKEN=""

# Entrypoint
RUN cat > /usr/local/bin/entrypoint.sh << 'EOF'
#!/usr/bin/env bash

set -e

echo "================================="
echo "Starting SSH VPS..."
echo "================================="

# Update password at runtime
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
fi

# Check ngrok token
if [ -z "$NGROK_TOKEN" ]; then
    echo "NGROK_TOKEN is missing!"
    exit 1
fi

# Configure ngrok
ngrok config add-authtoken "$NGROK_TOKEN"

# Start Dropbear SSH server
/usr/sbin/dropbear \
    -p 22 \
    -R \
    -F \
    -E \
    -r /etc/dropbear/dropbear_rsa_host_key \
    -r /etc/dropbear/dropbear_ecdsa_host_key \
    -r /etc/dropbear/dropbear_ed25519_host_key &

sleep 3

# Start ngrok tunnel
ngrok tcp 22 --log=stdout > /tmp/ngrok.log 2>&1 &

echo "Waiting for ngrok tunnel..."

for i in $(seq 1 30); do
    sleep 2

    TUNNEL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'tcp://[^"]*' | head -n 1)

    if [ ! -z "$TUNNEL" ]; then
        break
    fi
done

if [ -z "$TUNNEL" ]; then
    echo "Failed to get ngrok tunnel!"
    cat /tmp/ngrok.log
    exit 1
fi

HOST=$(echo $TUNNEL | sed 's/tcp:\/\///' | cut -d: -f1)
PORT=$(echo $TUNNEL | sed 's/tcp:\/\///' | cut -d: -f2)

echo ""
echo "================================="
echo "SSH VPS READY"
echo "================================="
echo ""
echo "SSH Command:"
echo "ssh root@$HOST -p $PORT"
echo ""
echo "Password:"
echo "$ROOT_PASSWORD"
echo ""
echo "================================="

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
EXPOSE 4040

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

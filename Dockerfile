FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y \
    dropbear \
    curl \
    wget \
    unzip \
    bash \
    procps \
    ca-certificates \
    tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /tmp/ngrok.zip && \
    unzip /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm -f /tmp/ngrok.zip

ENV ROOT_PASSWORD=morning
ENV NGROK_TOKEN=""

RUN echo "root:${ROOT_PASSWORD}" | chpasswd

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

set -e

echo "================================="
echo "Starting SSH VPS..."
echo "================================="

if [ ! -z "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
fi

if [ -z "$NGROK_TOKEN" ]; then
    echo ""
    echo "ERROR: NGROK_TOKEN not set!"
    echo ""
    exit 1
fi

# Configure ngrok
ngrok config add-authtoken "$NGROK_TOKEN"

# Start SSH
/usr/sbin/dropbear -R -F -E -p 22 &

sleep 5

# Start ngrok
ngrok tcp 22 --log=stdout > /tmp/ngrok.log 2>&1 &

echo ""
echo "Waiting for ngrok tunnel..."
echo ""

for i in $(seq 1 30); do
    sleep 2

    TUNNEL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'tcp://[^"]*' | head -n 1)

    if [ ! -z "$TUNNEL" ]; then
        break
    fi
done

if [ -z "$TUNNEL" ]; then
    echo "Failed to create ngrok tunnel!"
    echo ""
    cat /tmp/ngrok.log
    exit 1
fi

HOST=$(echo $TUNNEL | sed 's/tcp:\/\///' | cut -d: -f1)
PORT=$(echo $TUNNEL | sed 's/tcp:\/\///' | cut -d: -f2)

echo ""
echo "================================="
echo "VPS READY"
echo "================================="
echo ""
echo "SSH Command:"
echo "ssh root@$HOST -p $PORT"
echo ""
echo "Password:"
echo "$ROOT_PASSWORD"
echo ""
echo "================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 22
EXPOSE 4040

CMD ["/bin/bash", "/start.sh"]

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    curl \
    wget \
    unzip \
    bash && \
    mkdir /var/run/sshd && \
    echo 'root:morning' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /tmp/ngrok.zip && \
    unzip /tmp/ngrok.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm /tmp/ngrok.zip

ENV NGROK_TOKEN=""

RUN cat > /start.sh << 'EOF'
#!/bin/bash

service ssh start

ngrok config add-authtoken "$NGROK_TOKEN"

ngrok tcp 22 --log=stdout > /tmp/ngrok.log 2>&1 &

sleep 8

TUNNEL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'tcp://[^"]*' | head -n 1)

echo ""
echo "================================="
echo "SSH VPS READY"
echo "================================="
echo ""
echo "ssh root@$(echo $TUNNEL | sed 's/tcp:\/\///' | cut -d: -f1) -p $(echo $TUNNEL | sed 's/tcp:\/\///' | cut -d: -f2)"
echo ""
echo "Password: morning"
echo ""
echo "================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 22

CMD ["/bin/bash", "/start.sh"]

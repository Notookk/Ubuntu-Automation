FROM ubuntu:latest

RUN apt update -y > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1 && apt install locales -y \
&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8

ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

# Added curl (IMPORTANT)
RUN apt install ssh wget unzip curl -y > /dev/null 2>&1

RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip > /dev/null 2>&1
RUN unzip ngrok.zip

# 🔥 NEW SCRIPT WITH IP OUTPUT
RUN echo '#!/bin/bash\n\
./ngrok config add-authtoken ${NGROK_TOKEN}\n\
./ngrok tcp 22 > /ngrok.log &\n\
sleep 5\n\
URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o "tcp://[^\"]*")\n\
HOST=$(echo $URL | cut -d/ -f3 | cut -d: -f1)\n\
PORT=$(echo $URL | cut -d: -f3)\n\
echo ""\n\
echo "========== SSH CONNECTION =========="\n\
echo "Host: $HOST"\n\
echo "Port: $PORT"\n\
echo "User: morning"\n\
echo "Password: morning123"\n\
echo "===================================="\n\
echo ""\n\
/usr/sbin/sshd -D' > /morning.sh

RUN mkdir /run/sshd

RUN echo 'PermitRootLogin yes' >>  /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# User setup
RUN useradd -m morning && echo "morning:morning123" | chpasswd

RUN chmod 755 /morning.sh

EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

CMD /morning.sh

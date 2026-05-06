FROM ubuntu:22.04

RUN apt update && apt install -y openssh-server wget unzip locales

RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip \
 && unzip ngrok.zip \
 && chmod +x ngrok

RUN mkdir -p /run/sshd

RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
 && echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

RUN echo 'root:morning' | chpasswd
RUN echo '#!/bin/bash\n\
./ngrok config add-authtoken ${NGROK_TOKEN}\n\
./ngrok tcp 22 &\n\
/usr/sbin/sshd -D\n\
' > /start.sh

RUN chmod +x /start.sh

EXPOSE 22

CMD ["/start.sh"]

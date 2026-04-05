FROM ubuntu:latest
RUN apt update -y > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1 && apt install locales -y \
&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8

ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

RUN apt install ssh wget unzip -y > /dev/null 2>&1

RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip > /dev/null 2>&1
RUN unzip ngrok.zip

# Changed script name from daxx.sh -> morning.sh
RUN echo "./ngrok config add-authtoken ${NGROK_TOKEN} &&" >>/morning.sh
RUN echo "./ngrok tcp 22 &>/dev/null &" >>/morning.sh

RUN mkdir /run/sshd

RUN echo '/usr/sbin/sshd -D' >>/morning.sh

RUN echo 'PermitRootLogin yes' >>  /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Updated user and password
RUN useradd -m morning && echo "morning:morning123" | chpasswd

RUN service ssh start

RUN chmod 755 /morning.sh

EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

CMD  /morning.sh

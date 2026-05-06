FROM ubuntu:22.04

RUN apt update -y > /dev/null 2>&1 && \
    apt upgrade -y > /dev/null 2>&1 && \
    apt install locales ssh wget unzip bash -y > /dev/null 2>&1 && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG=en_US.utf8
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}

RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip > /dev/null 2>&1 && \
    unzip ngrok.zip && \
    chmod +x ngrok

RUN mkdir -p /run/sshd && \
    chmod 755 /run/sshd && \
    ssh-keygen -A

# Fix: Disable PAM audit and setup login environment
RUN sed -i 's/use_pam yes/use_pam no/g' /etc/ssh/sshd_config && \
    sed -i 's/^session\s\+required\s\+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:morning' | chpasswd && \
    chsh -s /bin/bash root

RUN echo "#!/bin/bash" > /morning.sh && \
    echo "./ngrok config add-authtoken ${NGROK_TOKEN}" >> /morning.sh && \
    echo "./ngrok tcp 22 &" >> /morning.sh && \
    echo "sleep 5" >> /morning.sh && \
    echo "/usr/sbin/sshd -D -e" >> /morning.sh && \
    chmod 755 /morning.sh

EXPOSE 22 80 443

CMD ["/bin/bash", "/morning.sh"]

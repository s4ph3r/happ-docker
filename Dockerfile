FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN groupadd -g 1000 ubuntu 2>/dev/null || true && \
    (id -u ubuntu > /dev/null 2>&1 || useradd -m -u 1000 -g 1000 -s /bin/bash -G sudo ubuntu) && \
    echo "ubuntu:ubuntu" | chpasswd && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN apt-get update && apt-get install -y --no-install-recommends \
    xserver-xorg-core xvfb x11-utils x11-xserver-utils \
    openbox lxqt-session lxqt-panel lxqt-config \
    fonts-noto-color-* fonts-wqy-zenhei \
    dbus dbus-x11 \
    pipewire pipewire-pulse wireplumber \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-libav \
    gir1.2-gstreamer-1.0 \
    wget curl ca-certificates gnupg \
    libxcb-cursor0 libxkbcommon-x11-0 \
    gcc python3-dev libevdev-dev python3-pip \
    libgl1 libopengl0 libglu1-mesa \
    nginx openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/happ
COPY Happ.linux.x64.deb /tmp/Happ.linux.x64.deb
RUN dpkg-deb -x /tmp/Happ.linux.x64.deb /tmp/happ_extract/ && \
    rm -rf /opt/happ/* && \
    cp -a /tmp/happ_extract/opt/happ/* /opt/happ/ && \
    chmod +x /opt/happ/bin/Happ /opt/happ/bin/happd /opt/happ/bin/happ-tcping /opt/happ/bin/happ-diag && \
    rm -rf /tmp/Happ.linux.x64.deb /tmp/happ_extract

RUN mkdir -p /root/.config/lxqt /root/.config/pipewire /root/.config/wireplumber && \
    chown -R root:root /root/.config
COPY --chown=root:root lxqt.conf /root/.config/lxqt/lxqt.conf

RUN mkdir -p /var/lib/happd && \
    mkdir -p /root/.config/happ && \
    mkdir -p /root/.local/share/happ && \
    chown -R root:root /root/.config/happ /root/.local/share/happ

# Генерируем самоподписанный SSL-сертификат для HTTPS
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/happ.key \
        -out /etc/nginx/ssl/happ.crt \
        -subj "/C=RU/ST=Home/L=Home/O=Happ/CN=localhost" 2>/dev/null

RUN pip3 install --no-cache-dir --break-system-packages selkies

COPY --chown=root:root start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh


EXPOSE 443 10809 10808

# Happ config and data volumes
VOLUME ["/root/.config/happ", "/root/.local/share/happ", "/var/lib/happd"]

CMD ["/usr/local/bin/start.sh"]

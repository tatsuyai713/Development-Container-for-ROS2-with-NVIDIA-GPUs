# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Ubuntu release versions 22.04, 20.04, and 18.04 are supported
ARG UBUNTU_RELEASE=22.04
ARG CUDA_VERSION=11.7.1
FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_RELEASE}

LABEL maintainer "https://github.com/ehfd,https://github.com/danisla"

ARG UBUNTU_RELEASE
ARG CUDA_VERSION
# Make all NVIDIA GPUs visible by default
ARG NVIDIA_VISIBLE_DEVICES=all
# Use noninteractive mode to skip confirmation when installing packages
ARG DEBIAN_FRONTEND=noninteractive
# All NVIDIA driver capabilities should preferably be used, check `NVIDIA_DRIVER_CAPABILITIES` inside the container if things do not work
ENV NVIDIA_DRIVER_CAPABILITIES all
# Enable AppImage execution in a container
ENV APPIMAGE_EXTRACT_AND_RUN 1
# System defaults that should not be changed
ENV DISPLAY :0
ENV XDG_RUNTIME_DIR /tmp/runtime-user
ENV PULSE_SERVER unix:/run/pulse/native
ENV LD_LIBRARY_PATH /usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

# Default environment variables (password is "mypasswd")
ENV SIZEW 1920
ENV SIZEH 1080
ENV REFRESH 60
ENV DPI 96
ENV CDEPTH 24
ENV VGL_DISPLAY egl
ENV PASSWD mypasswd
ENV NOVNC_ENABLE true

# Set versions for components that should be manually checked before upgrading, other component versions are automatically determined by fetching the version online
ARG VIRTUALGL_VERSION=3.1
ARG NOVNC_VERSION=1.3.0

RUN sed -i.bak -e "s%http://[^ ]\+%http://ftp.riken.go.jp/Linux/ubuntu/%g" /etc/apt/sources.list

# Install locales to prevent X11 errors
RUN apt-get clean && \
    apt-get update && apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8

ENV TZ UTC
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install Xvfb and other important libraries or packages
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    software-properties-common \
    alsa-base \
    alsa-utils \
    apt-transport-https \
    apt-utils \
    build-essential \
    ca-certificates \
    cups-filters \
    cups-common \
    cups-pdf \
    curl \
    file \
    wget \
    bzip2 \
    gzip \
    p7zip-full \
    xz-utils \
    zip \
    unzip \
    zstd \
    gcc \
    git \
    jq \
    make \
    python3 \
    python3-cups \
    python3-numpy \
    python3-pip \
    mlocate \
    nano \
    vim \
    htop \
    fonts-dejavu-core \
    fonts-freefont-ttf \
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-noto-color-emoji \
    fonts-noto-hinted \
    fonts-noto-mono \
    fonts-opensymbol \
    fonts-symbola \
    fonts-ubuntu \
    libpulse0 \
    pulseaudio \
    supervisor \
    net-tools \
    libglvnd-dev \
    libglvnd-dev:i386 \
    libgl1-mesa-dev \
    libgl1-mesa-dev:i386 \
    libegl1-mesa-dev \
    libegl1-mesa-dev:i386 \
    libgles2-mesa-dev \
    libgles2-mesa-dev:i386 \
    libglvnd0 \
    libglvnd0:i386 \
    libgl1 \
    libgl1:i386 \
    libglx0 \
    libglx0:i386 \
    libegl1 \
    libegl1:i386 \
    libgles2 \
    libgles2:i386 \
    libglu1 \
    libglu1:i386 \
    libsm6 \
    libsm6:i386 \
    vainfo \
    vdpauinfo \
    pkg-config \
    mesa-utils \
    mesa-utils-extra \
    va-driver-all \
    xserver-xorg-input-all \
    xserver-xorg-video-all \
    mesa-vulkan-drivers \
    libvulkan-dev \
    libvulkan-dev:i386 \
    libxau6 \
    libxau6:i386 \
    libxdmcp6 \
    libxdmcp6:i386 \
    libxcb1 \
    libxcb1:i386 \
    libxext6 \
    libxext6:i386 \
    libx11-6 \
    libx11-6:i386 \
    libxv1 \
    libxv1:i386 \
    libxtst6 \
    libxtst6:i386 \
    xdg-utils \
    dbus-x11 \
    libdbus-c++-1-0v5 \
    xkb-data \
    x11-xkb-utils \
    x11-xserver-utils \
    x11-utils \
    x11-apps \
    xauth \
    xbitmaps \
    xinit \
    xfonts-base \
    libxrandr-dev \
    # Install Xvfb, packages above this line should be the same between docker-nvidia-glx-desktop and docker-nvidia-egl-desktop
    xvfb && \
    # Install Vulkan utilities
    if [ "${UBUNTU_RELEASE}" \< "20.04" ]; then apt-get install -y vulkan-utils; else apt-get install -y vulkan-tools; fi && \
    rm -rf /var/lib/apt/lists/* && \
    # Configure EGL manually
    mkdir -p /usr/share/glvnd/egl_vendor.d/ && \
    echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
    \"library_path\": \"libEGL_nvidia.so.0\"\n\
    }\n\
    }" > /usr/share/glvnd/egl_vendor.d/10_nvidia.json

# Configure Vulkan manually
RUN VULKAN_API_VERSION=$(dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)') && \
    mkdir -p /etc/vulkan/icd.d/ && \
    echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
    \"library_path\": \"libGLX_nvidia.so.0\",\n\
    \"api_version\" : \"${VULKAN_API_VERSION}\"\n\
    }\n\
    }" > /etc/vulkan/icd.d/nvidia_icd.json

# Install VirtualGL and make libraries available for preload
ARG VIRTUALGL_URL="https://sourceforge.net/projects/virtualgl/files"
RUN curl -fsSL -O "${VIRTUALGL_URL}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" && \
    curl -fsSL -O "${VIRTUALGL_URL}/virtualgl32_${VIRTUALGL_VERSION}_amd64.deb" && \
    apt-get update && apt-get install -y ./virtualgl_${VIRTUALGL_VERSION}_amd64.deb ./virtualgl32_${VIRTUALGL_VERSION}_amd64.deb && \
    rm -f "virtualgl_${VIRTUALGL_VERSION}_amd64.deb" "virtualgl32_${VIRTUALGL_VERSION}_amd64.deb" && \
    rm -rf /var/lib/apt/lists/* && \
    chmod u+s /usr/lib/libvglfaker.so && \
    chmod u+s /usr/lib/libdlfaker.so && \
    chmod u+s /usr/lib32/libvglfaker.so && \
    chmod u+s /usr/lib32/libdlfaker.so && \
    chmod u+s /usr/lib/i386-linux-gnu/libvglfaker.so && \
    chmod u+s /usr/lib/i386-linux-gnu/libdlfaker.so

# Anything below this line should be always kept the same between docker-nvidia-glx-desktop and docker-nvidia-egl-desktop

# Install KDE and other GUI packages
ENV XDG_CURRENT_DESKTOP KDE
ENV KWIN_COMPOSE N
# Use sudoedit to change protected files instead of using sudo on kate
ENV SUDO_EDITOR kate
RUN apt-get update && apt-get install -y \
        kde-plasma-desktop \
        kwin-addons \
        kwin-x11 \
        kdeadmin \
        akregator \
        ark \
        baloo-kf5 \
        breeze-cursor-theme \
        breeze-icon-theme \
        debconf-kde-helper \
        colord-kde \
        desktop-file-utils \
        filelight \
        gwenview \
        hspell \
        kaddressbook \
        kaffeine \
        kate \
        kcalc \
        kcharselect \
        kdeconnect \
        kde-spectacle \
        kde-config-screenlocker \
        kde-config-updates \
        kdf \
        kget \
        kgpg \
        khelpcenter \
        khotkeys \
        kimageformat-plugins \
        kinfocenter \
        kio-extras \
        kleopatra \
        kmail \
        kmenuedit \
        kmix \
        knotes \
        kontact \
        kopete \
        korganizer \
        krdc \
        ktimer \
        kwalletmanager \
        librsvg2-common \
        okular \
        okular-extra-backends \
        plasma-dataengines-addons \
        plasma-discover \
        plasma-runners-addons \
        plasma-wallpapers-addons \
        plasma-widgets-addons \
        plasma-workspace-wallpapers \
        qtvirtualkeyboard-plugin \
        sonnet-plugins \
        sweeper \
        systemsettings \
        xdg-desktop-portal-kde \
        kubuntu-restricted-extras \
        kubuntu-wallpapers \
        kubuntu-desktop \
        pavucontrol-qt \
        transmission-qt && \
    apt-get install --install-recommends -y \
        libreoffice \
        libreoffice-style-breeze && \
    rm -rf /var/lib/apt/lists/* && \
    # Fix KDE startup permissions issues in containers
    cp -f /usr/lib/x86_64-linux-gnu/libexec/kf5/start_kdeinit /tmp/ && \
    rm -f /usr/lib/x86_64-linux-gnu/libexec/kf5/start_kdeinit && \
    cp -r /tmp/start_kdeinit /usr/lib/x86_64-linux-gnu/libexec/kf5/start_kdeinit && \
    rm -f /tmp/start_kdeinit

RUN add-apt-repository ppa:mozillateam/ppa

RUN { \
      echo 'Package: firefox*'; \
      echo 'Pin: release o=LP-PPA-mozillateam'; \
      echo 'Pin-Priority: 1001'; \
      echo ' '; \
      echo 'Package: firefox*'; \
      echo 'Pin: release o=Ubuntu*'; \
      echo 'Pin-Priority: -1'; \
    } > /etc/apt/preferences.d/99mozilla-firefox

RUN apt-get -y update \
 && apt-get install -y firefox

# Wine, Winetricks, Lutris, and PlayOnLinux, this process must be consistent with https://wiki.winehq.org/Ubuntu
ARG WINE_BRANCH=staging
RUN if [ "${UBUNTU_RELEASE}" \< "20.04" ]; then add-apt-repository -y ppa:cybermax-dexter/sdl2-backport; fi && \
    mkdir -pm755 /etc/apt/keyrings && curl -fsSL -o /etc/apt/keyrings/winehq-archive.key "https://dl.winehq.org/wine-builds/winehq.key" && \
    curl -fsSL -o "/etc/apt/sources.list.d/winehq-$(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2).sources" "https://dl.winehq.org/wine-builds/ubuntu/dists/$(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2)/winehq-$(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2).sources" && \
    apt-get update && apt-get install --install-recommends -y \
        winehq-${WINE_BRANCH} && \
    apt-get install -y \
        q4wine \
        playonlinux && \
    LUTRIS_VERSION=$(curl -fsSL "https://api.github.com/repos/lutris/lutris/releases/latest" | jq -r '.tag_name' | sed 's/[^0-9\.\-]*//g') && \
    curl -fsSL -O "https://github.com/lutris/lutris/releases/download/v${LUTRIS_VERSION}/lutris_${LUTRIS_VERSION}_all.deb" && \
    apt-get install -y ./lutris_${LUTRIS_VERSION}_all.deb && rm -f "./lutris_${LUTRIS_VERSION}_all.deb" && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL -o /usr/bin/winetricks "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" && \
    chmod 755 /usr/bin/winetricks && \
    curl -fsSL -o /usr/share/bash-completion/completions/winetricks "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion"

# Install the noVNC web interface and the latest x11vnc for fallback
RUN apt-get update && apt-get install -y \
        autoconf \
        automake \
        autotools-dev \
        chrpath \
        debhelper \
        git \
        jq \
        python3 \
        python3-numpy \
        libc6-dev \
        libcairo2-dev \
        libjpeg-turbo8-dev \
        libssl-dev \
        libv4l-dev \
        libvncserver-dev \
        libtool-bin \
        libxdamage-dev \
        libxinerama-dev \
        libxrandr-dev \
        libxss-dev \
        libxtst-dev \
        libavahi-client-dev && \
    rm -rf /var/lib/apt/lists/* && \
    # Build the latest x11vnc source to avoid various errors
    git clone "https://github.com/LibVNC/x11vnc.git" /tmp/x11vnc && \
    cd /tmp/x11vnc && autoreconf -fi && ./configure && make install && cd / && rm -rf /tmp/* && \
    git clone https://github.com/tatsuyai713/noVNC.git -b add_clipboard_support /opt/noVNC && \
    ln -snf /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    # Use the latest Websockify source to expose noVNC
    pip3 install git+https://github.com/novnc/websockify.git@v0.10.0


# install package
RUN apt-get update && apt-get install -y \
        build-essential \
        curl \
        sudo \
        less \
        apt-utils \
        tzdata \
        git \
        tmux \
        bash-completion \
        command-not-found \
        libglib2.0-0 \
        vim \
        emacs \
        ssh \
        rsync \
        python3 \
        python3-pip \
        python3-dev \
        sed \
        ca-certificates \
        wget \
        gpg \
        gpg-agent \
        gpgconf \
        gpgv \
        locales \
        unzip \
        net-tools \
        software-properties-common \
        apt-transport-https \
        lsb-release \
        autoconf \
        gnupg \
        lsb-release \
        less \
        emacs \
        tmux \
        bash-completion \
        command-not-found \
        software-properties-common \
        xdg-user-dirs \
        iproute2 \
        init \
        systemd \
        locales \
        net-tools \
        iputils-ping \
        curl \
        wget \
        telnet \
        less \
        vim \
        sudo \
        tzdata \
        locales \
        g++ \
        cmake \
        libdbus-1-dev && \
    rm -rf /var/lib/apt/lists/*

# install ROS2 Humble
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN apt-get update && apt-get install -y \
    ros-humble-desktop-full \
    ros-dev-tools

# install colcon and rosdep
RUN apt-get update && apt-get install -y \
    python3-colcon-common-extensions \
    python3-rosdep

RUN rosdep init 

# install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list

RUN apt-get update && apt-get install -y \
    google-chrome-stable && rm /etc/apt/sources.list.d/google.list

# install nodejs 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get update && apt-get install -y nodejs

# XRDP Setup
COPY xrdp_0.9.17-2ubuntu2_amd64.deb /tmp/xrdp_0.9.17-2ubuntu2_amd64.deb
RUN apt update && apt install -y /tmp/xrdp_0.9.17-2ubuntu2_amd64.deb
RUN apt-mark hold xrdp
RUN apt install -y git libpulse-dev autoconf m4 intltool build-essential dpkg-dev libtool libsndfile1-dev libspeexdsp-dev libudev-dev

RUN cp /etc/apt/sources.list /etc/apt/sources.list.org
RUN sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
RUN apt-get update

RUN apt build-dep pulseaudio -y
RUN cd /tmp && apt source pulseaudio && ln -s /tmp/pulseaudio-1* /tmp/pulseaudio-src

RUN cd /tmp/pulseaudio-1* && meson build && meson compile -C build ; exit 0 
RUN cd /tmp/pulseaudio-1* && build/src/daemon/pulseaudio -n -F build/src/daemon/default.pa -p $(pwd)/build/src/; exit 0 

RUN cd /tmp && git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git && cd pulseaudio-module-xrdp 
#     scripts/install_pulseaudio_sources_apt_wrapper.sh; exit 0 
RUN apt install -y sudo lsb-release
RUN cd /tmp/pulseaudio-module-xrdp && \
    ./bootstrap && \
    ./configure PULSE_DIR=/tmp/pulseaudio-src/ && \
    make install
RUN total_lines=$(wc -l < /etc/xrdp/startwm.sh) && insert_line=$((total_lines - 2)) && sed -i "${insert_line}i /bin/bash -c '/usr/bin/pulseaudio --start'" /etc/xrdp/startwm.sh
RUN rm /etc/apt/sources.list
RUN mv /etc/apt/sources.list.org /etc/apt/sources.list 

RUN mkdir -p /run/xrdp
RUN chown xrdp:xrdp /run/xrdp
RUN chmod 755 /run/xrdp

RUN chmod 640 /etc/xrdp/key.pem
RUN chown root:xrdp /etc/xrdp/key.pem

RUN adduser xrdp ssl-cert

RUN awk 'BEGIN{keep=1} /^\[.*\]/{if($0~/^\[(Globals|Channels|Logging)\]/){keep=1}else{keep=0}} keep{print}' /etc/xrdp/xrdp.ini > /etc/xrdp/xrdp.ini.tmp && \
    mv /etc/xrdp/xrdp.ini.tmp /etc/xrdp/xrdp.ini && \
    echo "[xrdp1]" >> /etc/xrdp/xrdp.ini && \
    echo "name=Plasma on Xvfb via x11vnc" >> /etc/xrdp/xrdp.ini && \
    echo "lib=libvnc.so" >> /etc/xrdp/xrdp.ini && \
    echo "ip=127.0.0.1" >> /etc/xrdp/xrdp.ini && \
    echo "port=5900" >> /etc/xrdp/xrdp.ini && \
    echo "username=na" >> /etc/xrdp/xrdp.ini && \
    echo "password=na" >> /etc/xrdp/xrdp.ini

RUN echo '#!/bin/sh' > /etc/xrdp/startwm.sh && \
    echo '/usr/sbin/xrdp-chansrv &' >> /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

RUN sed -i '/<head>/a <script>if (window.location.search === "" || window.location.search === "?") { window.location.replace(window.location.pathname + "?autoconnect=1&resize=scale"); }</script>' /opt/noVNC/vnc.html


# Copy scripts and configurations used to start the container
COPY entrypoint.sh /etc/entrypoint.sh
RUN chmod 755 /etc/entrypoint.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

RUN apt autoremove -y
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN rm /etc/apt/apt.conf.d/docker-clean


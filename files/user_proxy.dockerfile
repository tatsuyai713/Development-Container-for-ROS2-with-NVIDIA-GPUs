
FROM ghcr.io/tatsuyai713/development-container-for-ros-2-with-nvidia-gpus:20.04

ARG IN_LOCALE="JP"
ARG IN_TZ="Asia/Tokyo"
ARG IN_LANG="ja_JP.UTF-8"
ARG IN_LANGUAGE="ja_JP:ja"

ARG UID=9001
ARG GID=9001
ARG UNAME=nvidia
ARG HOSTNAME=docker

ARG NEW_HOSTNAME=${HOSTNAME}-Docker

ARG USERNAME=$UNAME
ARG HOME=/home/$USERNAME


ARG HTTP_PROXY
ARG HTTPS_PROXY

RUN : "apt Proxy" \
 && { \
  echo 'Acquire::http::proxy "'${HTTP_PROXY}'";'; \
  echo 'Acquire::https::proxy "'${HTTPS_PROXY}'";'; \
    } | tee /etc/apt/apt.conf
RUN : "apt Proxy" \
 && { \
  echo 'Acquire::http::proxy "'${HTTP_PROXY}'";'; \
  echo 'Acquire::https::proxy "'${HTTPS_PROXY}'";'; \
    } | tee /etc/apt/apt.conf.d/proxy.conf

RUN echo "http_proxy=${HTTP_PROXY}" >> /etc/environment && \
    echo "https_proxy=${HTTPS_PROXY}" >> /etc/environment

RUN useradd -u $UID -m $USERNAME && \
    echo "$USERNAME:$USERNAME" | chpasswd && \
    usermod --shell /bin/bash $USERNAME && \
    usermod -aG sudo $USERNAME && \
    mkdir /etc/sudoers.d -p && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,input,lp,lpadmin,plugdev,pulse-access,scanner,sudo,tape,tty,video,voice $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    usermod  --uid $UID $USERNAME && \
    groupmod --gid $GID $USERNAME && \
    chown -R $USERNAME:$USERNAME $HOME

RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone

RUN if [ "${IN_LOCALE}" = "JP" ]; then \
    apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install  -y \
        language-pack-ja-base \
        language-pack-ja \
        fcitx-mozc \
        fcitx-libs-dev \
        fcitx-module-dbus \
        kde-config-fcitx \
        fcitx \
        fcitx-frontend-gtk2 \
        fcitx-frontend-gtk3 \
        fcitx-frontend-qt5 \
        fcitx-ui-classic \
        mozc-utils-gui && \
    rm -rf /var/lib/apt/lists/* \
    && locale-gen ja_JP.UTF-8 \
    && dbus-launch --sh-syntax --exit-with-session > /dev/null \
    ; \
    fi

ENV TZ ${IN_TZ}
ENV LANG ${IN_LANG}
ENV LANGUAGE ${IN_LANGUAGE}

USER $USERNAME
RUN mkdir /home/${USERNAME}/.config/
RUN touch /home/${USERNAME}/.config/user-dirs.dirs
RUN if [ "${IN_LOCALE}" = "JP" ]; then \
    { \
    echo 'XDG_DESKTOP_DIR="$HOME/Desktop"'; \
    echo 'XDG_DOWNLOAD_DIR="$HOME/Downloads"'; \
    echo 'XDG_TEMPLATES_DIR="$HOME/Templates"'; \
    echo 'XDG_PUBLICSHARE_DIR="$HOME/Public"'; \
    echo 'XDG_DOCUMENTS_DIR="$HOME/Documents"'; \
    echo 'XDG_MUSIC_DIR="$HOME/Music"'; \
    echo 'XDG_PICTURES_DIR="$HOME/Pictures"'; \
    echo 'XDG_VIDEOS_DIR="$HOME/Videos"'; \
    } > /home/${USERNAME}/.config/user-dirs.dirs \
    ; \
    fi    
RUN mkdir /home/${USERNAME}/Desktop/
RUN mkdir /home/${USERNAME}/Downloads/
RUN mkdir /home/${USERNAME}/Templates/
RUN mkdir /home/${USERNAME}/Public/
RUN mkdir /home/${USERNAME}/Documents/
RUN mkdir /home/${USERNAME}/Music/
RUN mkdir /home/${USERNAME}/Pictures/
RUN mkdir /home/${USERNAME}/Videos/

# disabled beep sound
RUN echo "set bell-style none" >> /home/${USERNAME}/.inputrc

RUN touch /home/${USERNAME}/Desktop/home.desktop
RUN touch /home/${USERNAME}/Desktop/trash.desktop

# Make Desktop Icons
RUN { \
    echo "[Desktop Entry]"; \
    echo "Encoding=UTF-8"; \
    echo "Name=Home"; \
    echo "GenericName=Personal Files"; \
    echo "URL[$e]=$HOME"; \
    echo "Icon=user-home"; \
    echo "Type=Link"; \
    } > /home/${USERNAME}/Desktop/home.desktop

RUN { \
    echo "[Desktop Entry]"; \
    echo "Name=Trash"; \
    echo "Comment=Contains removed files"; \
    echo "Icon=user-trash-full"; \
    echo "EmptyIcon=user-trash"; \
    echo "URL=trash:/"; \
    echo "Type=Link"; \
    } > /home/${USERNAME}/Desktop/trash.desktop

# initialize rosdep
RUN rosdep update

RUN echo "export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH" >> /home/${USERNAME}/.bashrc

COPY fix_chrome_browser.sh /home/${USERNAME}/fix_chrome_browser.sh

USER root

RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/fix_chrome_browser.sh
RUN chmod +x /home/${USERNAME}/fix_chrome_browser.sh
RUN apt update
RUN apt upgrade -y

# Fix chrome
RUN sed -i -e "s#/usr/bin/google-chrome-stable#/usr/bin/google-chrome-stable --no-sandbox#g" /usr/share/applications/google-chrome.desktop

# Enable ssh
RUN systemctl enable ssh

RUN sed -i "s/<user>/$USERNAME/g" /etc/entrypoint.sh
RUN sed -i "s/<user>/$USERNAME/g" /etc/supervisord.conf

RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER $USERNAME
ENV SHELL /bin/bash
ENV USER $USERNAME
WORKDIR /home/$USERNAME

ENTRYPOINT ["/usr/bin/supervisord"]

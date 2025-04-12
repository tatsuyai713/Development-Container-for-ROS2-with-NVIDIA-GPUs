#!/bin/bash -e

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

# Create and modify permissions of XDG_RUNTIME_DIR
sudo -u <user> mkdir -pm700 /tmp/runtime-user
sudo chown <user>:<user> /tmp/runtime-user
sudo -u <user> chmod 700 /tmp/runtime-user
# Make user directory owned by the user in case it is not
sudo chown <user>:<user> /home/<user>
# Change operating system password to environment variable
echo "<user>:$PASSWD" | sudo chpasswd
# Remove directories to make sure the desktop environment starts
sudo rm -rf ~/.cache
# Change time zone from environment variable
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone > /dev/null
# Add game directories for Lutris and VirtualGL directories to path
export PATH="${PATH}:/usr/local/games:/usr/games:/opt/VirtualGL/bin"
# Add LibreOffice to library path
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program:${LD_LIBRARY_PATH}"

# Start DBus without systemd
sudo /etc/init.d/dbus start

# SSH start
sudo service ssh start

# Default display is :10 across the container
export DISPLAY=":10"
sudo rm -rf /tmp/.X11-unix/X${DISPLAY/:/}

# Run Xvfb server with required extensions
Xvfb "${DISPLAY}" -ac -screen "0" "${SIZEW}x${SIZEH}x${CDEPTH}" -dpi "${DPI}" +extension "RANDR" +extension "GLX" +iglx +extension "MIT-SHM" +render -nolisten "tcp" -noreset -shmem &
sleep 5

# Wait for X11 to start
echo "Waiting for X socket"
if [ -S "/tmp/.X11-unix/X${DISPLAY/:/}" ]; then
  echo "X socket is ready"
else
  exit # retry
fi

if [ "${SSL_ENABLE,,}" = "true" ]; then
  SSL="--ssl-only"
  CERT="--cert $CERT_PATH/server.crt --key $CERT_PATH/server.key"
fi

# Run the x11vnc + noVNC fallback web interface if enabled
if [ -n "$NOVNC_VIEWPASS" ]; then export NOVNC_VIEWONLY="-viewpasswd ${NOVNC_VIEWPASS}"; else unset NOVNC_VIEWONLY; fi
x11vnc -display "${DISPLAY}" -listen 0.0.0.0 -nopw -shared -forever -repeat -xkb -snapfb -threads -xrandr "resize" -rfbport 5900 ${NOVNC_VIEWONLY} &
/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --heartbeat 10 $SSL $CERT &

# Choose startplasma-x11 or startkde for KDE startup
if [ -x "$(command -v startplasma-x11)" ]; then export KDE_START="startplasma-x11"; else export KDE_START="startkde"; fi

# Use VirtualGL to run the KDE desktop environment with OpenGL if the GPU is available, otherwise use OpenGL with llvmpipe
if [ -n "$(nvidia-smi --query-gpu=uuid --format=csv | sed -n 2p)" ]; then
  export VGL_DISPLAY="${VGL_DISPLAY:-egl}"
  export VGL_REFRESHRATE="$REFRESH"
  vglrun +wm $KDE_START &
else
  $KDE_START &
fi

dbus-launch fcitx &
sudo service xrdp restart

# Add custom processes right below this line, or within `supervisord.conf` to perform service management similar to systemd

echo "Session Running. Press [Return] to exit."
read

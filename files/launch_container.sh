#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd $SCRIPT_DIR

RESOLUTION_W="1920"
RESOLUTION_H="1080"

function InputVNCPassword() {
	echo "Please input VNC Password."
	read input
	if [ -z $input ]; then
		InputVNCPassword
	else
		VNC_PASSWORD=$input
	fi
}

NAME_IMAGE="devcontainer_20.04_nvidia_image_for_${USER}"
DOCKER_NAME="devcontainer_20.04_nvidia_for_${USER}"

# Make Container
if [ ! "$(docker image ls -q ${NAME_IMAGE})" ]; then
	if [ ! $# -ne 1 ]; then
		if [ "build" = $1 ]; then
			if [ "$http_proxy" ]; then
				echo "Image ${NAME_IMAGE} does not exist."
				echo 'Now building JP image with proxy...'
				docker build --file=./user_proxy.dockerfile -t $NAME_IMAGE . --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg UNAME=$USER --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$https_proxy
			else
				echo "Image ${NAME_IMAGE} does not exist."
				echo 'Now building JP image without proxy...'
				docker build --file=./user.dockerfile -t $NAME_IMAGE . --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg UNAME=$USER
			fi
			exit
		fi
	elif [ ! $# -ne 2 ]; then
		if [ "build" = $1 ]; then
			if [ "US" = $2 ]; then
				if [ "$http_proxy" ]; then
					echo "Image ${NAME_IMAGE} does not exist."
					echo 'Now building US image with proxy...'
					docker build --file=./user_proxy.dockerfile -t $NAME_IMAGE . --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg UNAME=$USER --build-arg IN_LOCALE='US' --build-arg IN_TZ='UTC' --build-arg IN_LANG='en_US.UTF-8' --build-arg IN_LANGUAGE='en_US:en' --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$https_proxy
				else
					echo "Image ${NAME_IMAGE} does not exist."
					echo 'Now building US image without proxy...'
					docker build --file=./user.dockerfile -t $NAME_IMAGE . --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg UNAME=$USER --build-arg IN_LOCALE='US' --build-arg IN_TZ='UTC' --build-arg IN_LANG='en_US.UTF-8' --build-arg IN_LANGUAGE='en_US:en'
				fi
			else
				if [ "$http_proxy" ]; then
					echo "Image ${NAME_IMAGE} does not exist."
					echo 'Now building JP image with proxy...'
					docker build --file=./user_proxy.dockerfile -t $NAME_IMAGE . --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg UNAME=$USER --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$https_proxy
				else
					echo "Image ${NAME_IMAGE} does not exist."
					echo 'Now building JP image without proxy...'
					docker build --file=./user.dockerfile -t $NAME_IMAGE . --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg UNAME=$USER
				fi
			fi
			exit
		fi
	else
		echo "Docker image not found. Please setup first!"
		exit
	fi
else
	if [ ! $# -ne 1 ]; then
		if [ "build" = $1 ]; then
			echo "Docker image is already built!"
			exit
		fi
	fi
	if [ ! $# -ne 2 ]; then
		if [ "build" = $1 ]; then
			echo "Docker image is already built!"
			exit
		fi
	fi
fi

# Commit
if [ ! $# -ne 1 ]; then
	if [ "commit" = $1 ]; then
		echo 'Now commiting docker container...'
		docker commit ${DOCKER_NAME} ${NAME_IMAGE}:latest
		CONTAINER_ID=$(docker ps -a | grep ${DOCKER_NAME} | awk '{print $1}')
		docker stop $CONTAINER_ID
		docker rm $CONTAINER_ID -f
		exit
	fi
fi

# Stop
if [ ! $# -ne 1 ]; then
	if [ "stop" = $1 ]; then
		echo 'Now stopping docker container...'
		CONTAINER_ID=$(docker ps -a | grep ${DOCKER_NAME} | awk '{print $1}')
		docker stop $CONTAINER_ID
		docker rm $CONTAINER_ID -f
		exit
	fi
fi

# Delete
if [ ! $# -ne 1 ]; then
	if [ "delete" = $1 ]; then
		echo 'Now deleting docker container...'
		CONTAINER_ID=$(docker ps -a | grep ${DOCKER_NAME} | awk '{print $1}')
		docker stop $CONTAINER_ID
		docker rm $CONTAINER_ID -f
		docker image rm ${NAME_IMAGE}
		exit
	fi
fi

XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth_list=$(xauth nlist :0 | sed -e 's/^..../ffff/')
if [ ! -z "$xauth_list" ]; then
	echo $xauth_list | xauth -f $XAUTH nmerge -
fi
chmod a+r $XAUTH

DOCKER_OPT=""
DOCKER_WORK_DIR="/home/${USER}"
KERNEL=$(uname -r)

## For XWindow
DOCKER_OPT="${DOCKER_OPT} \
	--env=QT_X11_NO_MITSHM=1 \
    --volume=/tmp/.X11-unix:/tmp/.X11-unix:rw \
	--volume=/home/${USER}:/home/${USER}/host_home:rw \
	--volume=/lib/modules/$(uname -r):/lib/modules/$(uname -r):rw \
	--volume=/usr/src/linux-headers-$(uname -r):/usr/src/linux-headers-$(uname -r):rw \
	--volume=/usr/src/linux-hwe-${KERNEL:0:4}-headers-${KERNEL:0:9}:/usr/src/linux-hwe-${KERNEL:0:4}-headers-${KERNEL:0:9}:rw \
	--env=XAUTHORITY=${XAUTH} \
	--env=TERM=xterm-256color \
	--volume=${XAUTH}:${XAUTH} \
	--env=DISPLAY=${DISPLAY} \
	-w ${DOCKER_WORK_DIR} \
	-u ${USER} \
	--shm-size=4096m \
	-e SIZEW=${RESOLUTION_W} -e SIZEH=${RESOLUTION_H} -e REFRESH=60 -e DPI=96 -e CDEPTH=24 \
	--tmpfs /dev/shm:rw \
	-p 2$(id -u):3389 \
	-e PULSE_SERVER=unix:/run/pulse/native \
	--hostname $(hostname)-Docker \
	--add-host $(hostname)-Docker:127.0.1.1"

# Device
if [ ! $# -ne 1 ]; then
	if [ "device" = $1 ]; then
		echo 'Enable host devices'
		DOCKER_OPT="${DOCKER_OPT} --volume=/dev:/dev:rw "
	fi
fi

## Allow X11 Connection
xhost +local:$(hostname)-Docker
CONTAINER_ID=$(docker ps -a | grep ${NAME_IMAGE}: | awk '{print $1}')

# Run Container
if [ ! "$CONTAINER_ID" ]; then
	if [ ! $# -ne 1 ]; then
		if [ "novnc" = $1 ]; then
			InputVNCPassword
			DOCKER_OPT="${DOCKER_OPT} --gpus all "
			docker run ${DOCKER_OPT} \
				--name=${DOCKER_NAME} \
				-it -e PASSWD=${VNC_PASSWORD} -e BASIC_AUTH_PASSWORD=${VNC_PASSWORD} \
				-e PULSE_COOKIE=/tmp/pulse/cookie \
				-e PULSE_SERVER=unix:/tmp/pulse/native \
				-v /run/user/$(id -u)/pulse/native:/tmp/pulse/native \
				-v /home/$USER/.config/pulse/cookie:/tmp/pulse/cookie:ro \
				-e SSL_ENABLE=${SSL_ENABLE} -e CERT_PATH="/home/$USER/host_home/ssl/" \
				-p 1$(id -u):8080 \
				--entrypoint "/usr/bin/supervisord" \
				${NAME_IMAGE}:latest
			CONTAINER_ID=$(docker ps -a | grep ${NAME_IMAGE} | awk '{print $1}')
			docker commit ${DOCKER_NAME} ${NAME_IMAGE}:latest
			docker stop $CONTAINER_ID
			docker rm $CONTAINER_ID -f
		else
			echo "Error"
			exit
		fi
	elif [ ! $# -ne 2 ]; then
		if [ "novnc" = $1 ]; then
			VNC_PASSWORD=$2
			DOCKER_OPT="${DOCKER_OPT} --gpus all "
			docker run ${DOCKER_OPT} \
				--name=${DOCKER_NAME} \
				-e PASSWD=${VNC_PASSWORD} -e BASIC_AUTH_PASSWORD=${VNC_PASSWORD} \
				-e PULSE_COOKIE=/tmp/pulse/cookie \
				-e PULSE_SERVER=unix:/tmp/pulse/native \
				-v /run/user/$(id -u)/pulse/native:/tmp/pulse/native \
				-v /home/$USER/.config/pulse/cookie:/tmp/pulse/cookie:ro \
				-e SSL_ENABLE=${SSL_ENABLE} -e CERT_PATH="/home/$USER/host_home/ssl/" \
				-p 1$(id -u):8080 \
				--entrypoint "/usr/bin/supervisord" \
				${NAME_IMAGE}:latest
			CONTAINER_ID=$(docker ps -a | grep ${NAME_IMAGE} | awk '{print $1}')
			docker commit ${DOCKER_NAME} ${NAME_IMAGE}:latest
			docker stop $CONTAINER_ID
			docker rm $CONTAINER_ID -f
		else
			echo "Error"
			exit
		fi
	elif [ ! $# -ne 3 ]; then
		if [ "novnc" = $1 ]; then
			VNC_PASSWORD=$2
			GPU_OPT=""
			if [ ! "none" = $3 ]; then
				GPU_OPT="--gpus $3"
			fi
			docker run ${DOCKER_OPT} \
				--name=${DOCKER_NAME} \
				-e PASSWD=${VNC_PASSWORD} -e BASIC_AUTH_PASSWORD=${VNC_PASSWORD} \
				$GPU_OPT \
				-e PULSE_COOKIE=/tmp/pulse/cookie \
				-e PULSE_SERVER=unix:/tmp/pulse/native \
				-v /run/user/$(id -u)/pulse/native:/tmp/pulse/native \
				-v /home/$USER/.config/pulse/cookie:/tmp/pulse/cookie:ro \
				-e SSL_ENABLE=${SSL_ENABLE} -e CERT_PATH="/home/$USER/host_home/ssl/" \
				-p 1$(id -u):8080 \
				--entrypoint "/usr/bin/supervisord" \
				${NAME_IMAGE}:latest
			CONTAINER_ID=$(docker ps -a | grep ${NAME_IMAGE} | awk '{print $1}')
			docker commit ${DOCKER_NAME} ${NAME_IMAGE}:latest
			docker stop $CONTAINER_ID
			docker rm $CONTAINER_ID -f
		else
			echo "Error"
			exit
		fi
	else
		docker run ${DOCKER_OPT} \
			--name=${DOCKER_NAME} \
			-it --entrypoint "bash" \
			${NAME_IMAGE}:latest
	fi
else
	docker start $CONTAINER_ID
	docker exec -it $CONTAINER_ID /bin/bash
fi

xhost -local:$(hostname)-Docker

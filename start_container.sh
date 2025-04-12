#!/bin/bash

VNC_PASSWORD="test"

if [ $# -ne 1 ]; then
	echo "Please select GPU. (gpu0, gpu1,..., all or none(default))"
	exit
fi

GPU=$1
GPU_OPTION="none"

if [ "gpu0" = $GPU ]; then
	GPU_OPTION="device=0"
fi
if [ "gpu1" = $GPU ]; then
	GPU_OPTION="device=1"
fi
if [ "gpu2" = $GPU ]; then
	GPU_OPTION="device=2"
fi
if [ "gpu3" = $GPU ]; then
	GPU_OPTION="device=3"
fi
if [ "all" = $GPU ]; then
	GPU_OPTION=all
fi

echo "GPU OPTION is ${GPU_OPTION}"

function InputVNCPassword() {
	echo "Please input VNC Password."
	read input
	if [ -z $input ] ; then
		InputVNCPassword
	else
		VNC_PASSWORD=$input 
	fi
}

NAME_IMAGE="devcontainer_20.04_nvidia_image_for_${USER}"
DOCKER_NAME="devcontainer_20.04_nvidia_for_${USER}"

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd $SCRIPT_DIR
cd ./files/
if [ "$(docker ps -al | grep ${DOCKER_NAME})" ]; then
	echo "docker container already started...(GPU option is ignored.)"
	CONTAINER_ID=$(docker ps -a | grep ${DOCKER_NAME} | awk '{print $1}')
	
	sudo rm -rf /tmp/.docker.xauth
	XAUTH=/tmp/.docker.xauth
	touch $XAUTH
	xauth_list=$(xauth nlist :0 | sed -e 's/^..../ffff/')
	if [ ! -z "$xauth_list" ]; then
		echo $xauth_list | xauth -f $XAUTH nmerge -
	fi
	chmod a+r $XAUTH

	docker start $CONTAINER_ID
	exit
fi
sudo pwd # check sudo
InputVNCPassword
nohup ./launch_container.sh novnc ${VNC_PASSWORD} ${GPU_OPTION} > /tmp/nohup_${USER}.out 2>&1 &

sleep 3
echo ""
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
echo "_/  Please access 'http(s)://localhost:1`id -u`'   _/"
echo "_/    or 'http(s)://<PC IP ADDRESS>:1`id -u`'      _/"
echo "_/        RDP Connection Port is 2`id -u`          _/"
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"

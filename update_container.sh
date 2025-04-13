#!/bin/bash

NAME_IMAGE="devcontainer_22.04_nvidia_image_for_${USER}"
DOCKER_NAME="devcontainer_22.04_nvidia_for_${USER}"

sudo apt install -y ansible

if [ ! "$(docker image ls -q ${NAME_IMAGE})" ]; then
	echo "Docker image not found."
	exit
fi

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd $SCRIPT_DIR
echo "Update Container"
cd ./files

nohup ./launch_container.sh novnc test none > /tmp/nohup_${USER}.out 2>&1 &

echo "Please wait..."
cd ../

# ここからwhileループで値が入るまで待機する
while [ -z "$CONTAINER_ID" ] || [ -z "$CONTAINER_IP" ]; do
    CONTAINER_ID=$(docker ps -a | grep ${DOCKER_NAME} | awk '{print $1}')
    CONTAINER_IP=$(docker inspect $CONTAINER_ID | grep IPAddress | awk -F'[,,"]' 'NR==2{print $4}')
    echo "Please wait until container running..."
    sleep 1
done
	

if [ ! -e ~/.ssh/id_rsa.pub  ]; then
	ssh-keygen -t rsa
fi

ssh-keygen -R $CONTAINER_IP

ssh-copy-id -i ~/.ssh/id_rsa.pub $CONTAINER_IP

ansible-playbook -i ${CONTAINER_IP}, ./ansible/update-docker.yml

cd ./files/

./launch_container.sh commit

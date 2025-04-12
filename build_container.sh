#!/bin/bash

NAME_IMAGE="devcontainer_20.04_nvidia_image_for_${USER}"
DOCKER_NAME="devcontainer_20.04_nvidia_for_${USER}"

echo "Build Container"

if [ $# -ne 1 ]; then
	echo "Please select keyboard type. (JP or US)"
	exit
fi

REGION=$1

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd $SCRIPT_DIR
cd ./files/

if [ "US" = $REGION ]; then
	./launch_container.sh build US
else
	./launch_container.sh build JP
fi

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
sleep 3
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
echo "_/  Please type 'test' as temporary password!!  _/"
echo "_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/"
ssh-copy-id -i ~/.ssh/id_rsa.pub $CONTAINER_IP

ansible-playbook -i ${CONTAINER_IP}, ./ansible/docker.yml

cd ./files/

./launch_container.sh commit

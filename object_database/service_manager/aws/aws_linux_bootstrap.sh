#!/bin/bash

export STORAGE=/media/ephemeral0

machineId=`curl http://169.254.169.254/latest/meta-data/instance-id`

echo "****************"
if [ -b /dev/xvdb ]; then
    echo "Mounting /dev/xvdb to $STORAGE"
    sudo mkfs -t ext4 /dev/xvdb
    sudo mkdir -p $STORAGE
    sudo mount /dev/xvdb $STORAGE
else
    echo "Mounting /dev/nvme1n1 to $STORAGE"
    sudo mkfs -t ext4 /dev/nvme1n1
    sudo mkdir -p $STORAGE
    sudo mount /dev/nvme1n1 $STORAGE
fi

echo "****************"
echo 'df -h $STORAGE'
df -h $STORAGE
echo "****************"

echo "Installing docker"

sudo apt-get update
sudo apt-get install -y docker.io

log "Installing git"

sudo apt-get install -y git

log "Installing awscli"

sudo apt-get install -y awscli

echo "Moving docker directory to $STORAGE"
sudo service docker stop

sudo cp /var/lib/docker $STORAGE -r
sudo rm /var/lib/docker -rf
(cd /var/lib; sudo ln -s $STORAGE/docker)

echo "Starting docker"

sudo service docker start

sudo chmod 777 /var/run/docker.sock

echo "Installing python dependencies"

sudo apt-get install -y python3-pip libtcmalloc-minimal4
sudo pip3 install boto3 psutil docker==2.6.1 pandas numpy pytz redis flask_sockets flask-cors websockets

export PYTHONPATH=$STORAGE/nativepython
export INSTALL=$STORAGE/install

mkdir -p $INSTALL
mkdir -p $INSTALL/logs
mkdir -p $INSTALL/service_source

cd $INSTALL

chmod 700 -R ~/.ssh

git clone https://github.com/braxtonmckee/nativepython.git $STORAGE/nativepython

export LD_PRELOAD=/usr/lib/libtcmalloc_minimal.so.4

{extra_boot_script}

$STORAGE/nativepython/object_database/frontends/service_manager.py \
    `hostname`  \
    {db_hostname} \
    {db_port} \
    --source $INSTALL/service_source \
    --storage $INSTALL/service_storage \
    --logdir $INSTALL/logs &> $INSTALL/logs/db_server.log



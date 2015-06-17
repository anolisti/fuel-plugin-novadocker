#!/bin/bash

##Variables
LOG_FILE="/var/log/docker-plugin"
CONFIG_FILE="/etc/compute.yaml"


#The file '/etc/compute.yaml' should exist because this script
#is executed only in compute node
if [[ -e $CONFIG_FILE ]]
then
    echo "File $CONFIG_FILE exists" >> $LOG_FILE
else
    echo "File $CONFIG_FILE does not exist" >> $LOG_FILE
    echo "This should not happen. Exit" >> $LOG_FILE
    exit 0
fi

#From hiera retrieves if all_nodes checkbox is checked
#Must do a workaround with python because
#hiera cannot return subkey correctly
all_nodes=`hiera fuel-plugin-docker | sed -e 's/=>/:/g' | \
python -c \
'import json; \
import sys; \
print str(json.load(sys.stdin)["fuel-plugin-docker-2_checkbox"]).lower()'`

#Check if the name of the node contains 'docker'
if (hiera user_node_name|grep -i docker) || $all_nodes
then
    echo "Proceed to docker installation" >> $LOG_FILE
else
    echo "No docker installation" >> $LOG_FILE
    echo "Exit" >> $LOG_FILE
    exit 0
fi

#Install docker
curl -sSL https://get.docker.com/ubuntu/ | sh

#Install nova-docker
apt-get update
apt-get install git
wget -O- https://raw.github.com/pypa/pip/master/contrib/get-pip.py | python
ln -s `which pip` /usr/bin/pip
git clone -b stable/juno https://github.com/ddepaoli3/nova-docker.git
cd nova-docker
python setup.py install

#Config nova
echo -e "[DEFAULT]\ncompute_driver=novadocker.virt.docker.DockerDriver" > /etc/nova/nova-compute.conf
echo '[Filters]' > /etc/nova/rootwrap.d/docker.filters
echo 'ln: CommandFilter, /bin/ln, root' >> /etc/nova/rootwrap.d/docker.filters
usermod -G docker nova

service nova-compute restart

exit 0

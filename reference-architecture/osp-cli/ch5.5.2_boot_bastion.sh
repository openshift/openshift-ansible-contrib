#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
IMAGE=${IMAGE:-rhel7}
FLAVOR=${FLAVOR:-m1.small}
OCP3_KEY_NAME=${OCP3_KEY_NAME:-ocp3}
netid1=$(openstack network list | awk "/control-network/ { print \$2 }")
netid2=$(openstack network list | awk "/tenant-network/ { print \$2 }")
openstack server create --flavor ${FLAVOR} --image ${IMAGE} \
--key-name ${OCP3_KEY_NAME} \
--nic net-id=$netid1 \
--nic net-id=$netid2 \
--security-group bastion-sg --user-data=user-data/bastion.yaml \
bastion.${OCP3_CONTROL_DOMAIN}

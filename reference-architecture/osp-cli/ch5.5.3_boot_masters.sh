#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
OCP3_KEY_NAME=${OCP3_KEY_NAME:-ocp3}
IMAGE=${IMAGE:-rhel7}
FLAVOR=${FLAVOR:-m1.small}
MASTER_COUNT=${MASTER_COUNT:-3}
netid1=$(openstack network list | awk "/control-network/ { print \$2 }")
netid2=$(openstack network list | awk "/tenant-network/ { print \$2 }")
for HOSTNUM in $(seq 0 $(($MASTER_COUNT-1))) ; do
    openstack server create --flavor ${FLAVOR} --image ${IMAGE} \
      --key-name ${OCP3_KEY_NAME} \
      --nic net-id=$netid1 --nic net-id=$netid2 \
      --security-group master-sg --user-data=user-data/master-${HOSTNUM}.yaml \
      master-${HOSTNUM}.${OCP3_CONTROL_DOMAIN}
done

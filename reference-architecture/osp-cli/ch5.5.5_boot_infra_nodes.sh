#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
OCP3_KEY_NAME=${OCP3_KEY_NAME:-ocp3}
IMAGE=${IMAGE:-rhel7}
FLAVOR=${FLAVOR:-m1.small}
netid1=$(openstack network list | awk "/control-network/ { print \$2 }")
netid2=$(openstack network list | awk "/tenant-network/ { print \$2 }")
INFRA_NODE_COUNT=${INFRA_NODE_COUNT:-2}
for HOSTNUM in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do
    HOSTNAME=infra-node-$HOSTNUM
    VOLUMEID=$(cinder list | awk "/${HOSTNAME}-docker/ { print \$2 }")
    openstack server create --flavor ${FLAVOR} --image ${IMAGE} \
       --key-name ${OCP3_KEY_NAME} \
       --nic net-id=$netid1 --nic net-id=$netid2 \
       --security-group infra-node-sg --user-data=user-data/${HOSTNAME}.yaml \
       --block-device-mapping vdb=${VOLUMEID} \
       ${HOSTNAME}.${OCP3_CONTROL_DOMAIN}
done

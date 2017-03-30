#!/bin/sh
DOMAIN=${DOMAIN:-control.ocp3.example.com}
netid1=$(openstack network list | awk "/control-network/ { print \$2 }")
netid2=$(openstack network list | awk "/tenant-network/ { print \$2 }")
for HOSTNAME in app-node-0 app-node-1 app-node-2
do
  VOLUMEID=$(cinder list | awk "/${HOSTNAME}-docker/ { print \$2 }")
  openstack server create --flavor m1.medium --image rhel7 --key-name ocp3kp \
  --nic net-id=$netid1 --nic net-id=$netid2 \
  --security-group app-node-sg --user-data=user-data/${HOSTNAME}.yaml \
  --block-device-mapping vdb=${VOLUMEID} \
  ${HOSTNAME}.${DOMAIN}
done

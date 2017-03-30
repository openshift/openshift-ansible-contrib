#!/bin/sh
DOMAIN=${DOMAIN:-control.ocp3.example.com}
netid1=$(openstack network list | awk "/control-network/ { print \$2 }")
netid2=$(openstack network list | awk "/tenant-network/ { print \$2 }")
for HOSTNUM in 0 1 2 ; do
  openstack server create --flavor m1.small --image rhel7 --key-name ocp3kp \
  --nic net-id=$netid1 --nic net-id=$netid2 \
  --security-group master-sg --user-data=user-data/master-${HOSTNUM}.yaml \
  master-${HOSTNUM}.${DOMAIN}
done

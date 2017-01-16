#!/bin/sh
DOMAIN=${DOMAIN:-ocp3.example.com}
GLANCE_IMAGE=${GLANCE_IMAGE:-rhel72}

# Retrive a Neutron net id by name
function net_id_by_name() {
    # NAME=$1
    neutron net-list --field id --field name | grep $1 | cut -d' ' -f2
}

for HOSTNUM in 0 1 2 ; do
  nova boot --flavor m1.small --image ${GLANCE_IMAGE} --key-name ocp3 \
  --nic net-id=$(net_id_by_name control-network) \
  --nic net-id=$(net_id_by_name tenant-network) \
   --security-groups master-sg \
   --user-data=user-data/master-${HOSTNUM}.yaml \
  master-${HOSTNUM}.${DOMAIN}
done

#!/bin/sh
DOMAIN=${DOMAIN:-ocp3.example.com}
GLANCE_IMAGE=${GLANCE_IMAGE:-rhel72}

# Retrive a Neutron net id by name
function net_id_by_name() {
    # NAME=$1
    neutron net-list --field id --field name | grep $1 | cut -d' ' -f2
}

nova boot --flavor m1.small --image ${GLANCE_IMAGE} --key-name ocp3 \
  --nic net-id=$(net_id_by_name control-network) \
  --nic net-id=$(net_id_by_name tenant-network) \
  --security-groups bastion-sg \
  --user-data=user-data/bastion.yaml \
  bastion.${DOMAIN}

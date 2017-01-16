#!/bin/sh
DOMAIN=${DOMAIN:-ocp3.example.com}
GLANCE_IMAGE=${GLANCE_IMAGE:-rhel72}

# Retrive a Neutron net id by name
function net_id_by_name() {
    # NAME=$1
    neutron net-list --field id --field name | grep $1 | cut -d' ' -f2
}

for HOSTNAME in infra-node-0 infra-node-1
do
  VOLUMEID=$(cinder show ${HOSTNAME}-docker | grep ' id ' | awk '{print $4}')

  nova boot --flavor m1.medium --image ${GLANCE_IMAGE} --key-name ocp3 \
   --nic net-id=$(net_id_by_name control-network) \
   --nic net-id=$(net_id_by_name tenant-network) \
   --security-groups infra-sg \
   --block-device source=volume,dest=volume,device=vdb,id=${VOLUMEID} \
   --user-data=user-data/${HOSTNAME}.yaml \
   ${HOSTNAME}.${DOMAIN}
done

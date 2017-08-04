#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
PUBLIC_NETWORK=${PUBLIC_NETWORK:-public_network}
MASTER_COUNT=${MASTER_COUNT:-3}
INFRA_NODE_COUNT=${INFRA_NODE_COUNT:-2}
APP_NODE_COUNT=${APP_NODE_COUNT:3}

BASTION="bastion"
MASTERS=$(for M in $(seq 0 $(($MASTER_COUNT-1))) ; do echo master-$M ; done)
INFRA_NODES=$(for I in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do echo infra-node-$I ; done)
for HOST in $BASTION $MASTERS $INFRA_NODES
do
  openstack floating ip create ${PUBLIC_NETWORK}
  FLOATING_IP=$(openstack floating ip list | awk "/None/ { print \$4 }")
  openstack server add floating ip ${HOST}.${OCP3_CONTROL_DOMAIN} ${FLOATING_IP}
done

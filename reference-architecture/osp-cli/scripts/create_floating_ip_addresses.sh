#!/bin/sh
DOMAIN=${DOMAIN:-control.ocp3.example.com}
MASTERS="master-0 master-1 master-2"
BASTION="bastion"
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
ALL_NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$BASTION $MASTERS $ALL_NODES"
for HOST in $BASTION $MASTERS $INFRA_NODES
do
  openstack floating ip create public_network
  FLOATING_IP=$(openstack floating ip list | awk "/None/ { print \$4 }")
  openstack server add floating ip ${HOST}.${DOMAIN} ${FLOATING_IP}
done

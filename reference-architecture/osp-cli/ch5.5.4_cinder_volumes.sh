#!/bin/sh
VOLUME_SIZE=${VOLUME_SIZE:-8}
BASTION="bastion"
INFRA_NODE_COUNT=${INFRA_NODE_COUNT:-2}
APP_NODE_COUNT=${APP_NODE_COUNT:-3}

INFRA_NODES=$(for I in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do echo infra-node-$I ; done)
APP_NODES=$(for I in $(seq 0 $(($APP_NODE_COUNT-1))) ; do echo app-node-$I ; done)
ALL_NODES="$INFRA_NODES $APP_NODES"

for NODE in $ALL_NODES ; do
    cinder create --name ${NODE}-docker ${VOLUME_SIZE}
done

openstack volume list

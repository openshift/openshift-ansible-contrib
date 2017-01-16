#!/bin/sh
VOLUME_SIZE=${VOLUME_SIZE:-8}
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
ALL_NODES="$INFRA_NODES $APP_NODES"

for NODE in $ALL_NODES ; do
    cinder create --name ${NODE}-docker ${VOLUME_SIZE}
done

#!/bin/sh
for H in $INFRA_NODES $APP_NODES
do
  scp docker-storage-setup $H:
  ssh $H sudo cp ./docker-storage-setup /etc/sysconfig
  ssh $H sudo /usr/bin/docker-storage-setup
done

#!/bin/sh
for H in $INFRA_NODES $APP_NODES
do
  ssh $H sudo systemctl enable docker
  ssh $H sudo systemctl start docker
done

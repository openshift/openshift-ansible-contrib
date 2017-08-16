#!/bin/sh
for H in $INFRA_NODES $APP_NODES
do
  ssh $H sudo yum install -y docker
done

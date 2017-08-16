#!/bin/sh
for H in $INFRA_NODES $APP_NODES
do
  ssh $H sudo systemctl enable lvm2-lvmetad
  ssh $H sudo systemctl start lvm2-lvmetad
done

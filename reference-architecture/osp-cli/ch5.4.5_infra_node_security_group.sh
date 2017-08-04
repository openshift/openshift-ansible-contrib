#!/bin/sh
openstack security group create infra-node-sg
openstack security group rule create --protocol icmp infra-node-sg
neutron security-group-rule-create infra-node-sg \
  --protocol tcp --port-range-min 22 --port-range-max 22 \
  --remote-group-id bastion-sg

for PORT in 80 443 10250 4789
do
 openstack security group rule create --protocol tcp --dst-port $PORT infra-node-sg
done

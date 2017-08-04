#!/bin/sh
openstack security group create master-sg
openstack security group rule create --protocol icmp master-sg
neutron security-group-rule-create master-sg \
 --protocol tcp --port-range-min 22 --port-range-max 22 \
 --remote-group-id bastion-sg


neutron security-group-rule-create master-sg \
 --protocol tcp --port-range-min 2380 --port-range-max 2380 \
 --remote-group-id master-sg

for PORT in 53 2379 2380 8053 8443 10250 24224
do
  openstack security group rule create --protocol tcp --dst-port $PORT master-sg
done

for PORT in 53 4789 8053 24224
do
  openstack security group rule create --protocol udp --dst-port $PORT master-sg
done


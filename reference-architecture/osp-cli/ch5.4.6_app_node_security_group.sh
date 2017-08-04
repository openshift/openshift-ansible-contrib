#!/bin/sh
openstack security group create app-node-sg
openstack security group rule create --protocol icmp app-node-sg
neutron security-group-rule-create app-node-sg \
     --protocol tcp --port-range-min 22 --port-range-max 22 \
     --remote-group-id bastion-sg
openstack security group rule create --protocol tcp --dst-port 10250 app-node-sg
openstack security group rule create --protocol udp --dst-port 4789 app-node-sg

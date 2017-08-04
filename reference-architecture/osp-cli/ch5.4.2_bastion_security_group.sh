#!/bin/sh
openstack security group create bastion-sg
openstack security group rule create --ingress --protocol icmp bastion-sg
openstack security group rule create --protocol tcp \
--dst-port 22 bastion-sg
#Verification of security group
openstack security group show bastion-sg

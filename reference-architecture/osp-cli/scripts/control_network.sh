#!/bin/sh
# REQUIRED: Set NAMESERVER value
NAMESERVER=
openstack network create control-network 
openstack subnet create --net control-network --subnet-range 172.18.10.0/24 \
--dns-nameserver ${NAMESERVER} control-subnet
openstack router create control-router
openstack router add subnet control-router control-subnet
neutron router-gateway-set control-router public_network

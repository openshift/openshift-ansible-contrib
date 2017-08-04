#!/bin/sh

openstack network create tenant-network
openstack subnet create --network tenant-network \
  --subnet-range 172.18.20.0/24 --gateway none tenant-subnet

#!/bin/sh

# delete instances
nova list --field name | grep control | awk '{print $4}' | xargs nova delete


# delete floating IPs
nova floating-ip-list | grep 10.19.114 | awk '{print $4}' | xargs -I{} nova floating-ip-delete {}

# delete security-groups
for SG in bastion-sg master-sg infra-sg node-sg ; do
    neutron security-group-delete $SG
done

# detach router from gateway and ports
neutron router-gateway-clear control-router
neutron router-interface-delete control-router control-subnet
neutron router-delete control-router

# delete router

# delete networks
neutron net-delete control-network
neutron net-delete tenant-network

# delete cinder volumes
cinder list | grep available | awk '{print $6}' | xargs -I{} cinder delete {}

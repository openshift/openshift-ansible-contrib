#!/bin/sh

[ ! -e /usr/bin/jq -o $(jq --version) != 'jq-1.5' ] &&
    echo "missing required jq version 1.5" && exit 1

# delete instances
#nova list --field name | grep control | awk '{print $4}' | xargs nova delete
openstack server list -f json | jq '.[].Name'| tr -d \"  | grep control |
    xargs -I{} openstack server delete {}

sleep 2

# delete floating IPs
#nova floating-ip-list | grep 10.19.114 | awk '{print $4}' | xargs -I{} nova floating-ip-delete {}
openstack floating ip list -f json |
    jq 'foreach .[]  as $rec ( [] ; 
          if 
            $rec."Fixed IP Address" == null  
          then 
            $rec."Floating IP Address"
          else 
            empty
          end ;
          . )' |
    tr -d \" | 
    xargs -I{} openstack floating ip delete {}


# delete security-groups
for SG in bastion-sg master-sg infra-node-sg app-node-sg ; do
    openstack security group delete $SG
done

# detach router from gateway and ports
neutron router-gateway-clear control-router
openstack router remove subnet control-router control-subnet
openstack router delete control-router

# delete router

# delete networks
openstack network delete control-network
openstack network delete tenant-network

# delete cinder volumes
#cinder list | grep available | awk '{print $6}' | xargs -I{} cinder delete {}
INFRA_NODE_COUNT=${INFRA_NODE_COUNT:-2}
APP_NODE_COUNT=${APP_NODE_COUNT:3}

INFRA_NODES=$(for I in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do echo infra-node-$I ; done)
APP_NODES=$(for A in $(seq 0 $(($APP_NODE_COUNT-1))) ; do echo app-node-$A ; done)


function free_volumes() {
    openstack volume list -f json |
        jq -r 'foreach .[] as $i (
               [] ; 
               if $i.Status == "available" then $i."Display Name" else empty end ; 
               $i."Display Name")'
}

for VOLUME in $(free_volumes) ; do
    openstack volume delete $VOLUME
done


# Delete DNS entries
#dig @10.19.114.199 ocp3.example.com axfr |
#  grep -e 'bastion\|master-[[:digit:]]\|-node-[[:digit:]]' |
#  cut -d' ' -f1 | sed -e 's/\.$//' -e 's/^/update delete /'

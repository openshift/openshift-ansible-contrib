#!/bin/sh

#HOSTNAME=$1
OCP3_BASE_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=control.${OCP3_BASE_DOMAIN}
OCP3_TENANT_DOMAIN=tenant.${OCP3_BASE_DOMAIN}

BASTION="bastion"
MASTERS=$(for M in $(seq 0 $(($MASTER_COUNT-1))) ; do echo master-$M ; done)
INFRA_NODES=$(for I in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do echo infra-node-$I ; done)
APP_NODES=$(for A in $(seq 0 $(($APP_NODE_COUNT-1))) ; do echo app-node-$A ; done)
ALL_NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$BASTION $MASTERS $ALL_NODES"

[ -z "${OCP3_DNS_NAMESERVER}" ] &&
    echo "Missing required argument OCP3_DNS_NAMESERVER" && exit 1
[ -z "${OCP3_DNS_UPDATE_KEY}" ] &&
    echo "MIssing required argument OCP3_DNS_UPDATE_KEY" && exit 1

function control_ip() {
    # HOSTNAME=$1
    openstack server show $1 -f json |
        jq -r '.addresses |
               match("control-network=([\\d.]+)") |
                .captures[0].string'
}

# Get the tenent-network IP address from the server record
function tenant_ip() {
    # HOSTNAME=$1
    openstack server show $1 -f json |
        jq -r '.addresses |
               match("tenant-network=([\\d.]+)") |
                .captures[0].string'
}

function floating_ip() {
    # HOSTNAME=$1
    openstack server show $1 -f json |
        jq -r '.addresses | 
                 match("control-network=[\\d.]+, ([\\d.]+)") |
                 .captures[0].string'
}

function update_dns_a() {
    # FQDN=$1
    # IPADDR=$2
    echo "updating $1 => $2"
    nsupdate -k ${OCP3_DNS_UPDATE_KEY} <<EOF
server ${OCP3_DNS_NAMESERVER}
zone ${OCP3_BASE_DOMAIN}
update delete $1
send
update add $1 300 A $2
send
quit
EOF
    
}


for HOST in $BASTION $MASTERS $INFRA_NODES
do
    CONTROL_NAME=${HOST}.${OCP3_CONTROL_DOMAIN}
    update_dns_a ${HOST}.${OCP3_BASE_DOMAIN} $(floating_ip ${CONTROL_NAME})
    update_dns_a ${CONTROL_NAME} $(control_ip ${CONTROL_NAME})
    update_dns_a ${HOST}.tenant.${OCP3_BASE_DOMAIN} $(tenant_ip ${CONTROL_NAME})
done

for HOST in $APP_NODES
do
    CONTROL_NAME=${HOST}.${OCP3_CONTROL_DOMAIN}
    update_dns_a ${CONTROL_NAME} $(control_ip ${CONTROL_NAME})
    update_dns_a ${HOST}.tenant.${OCP3_BASE_DOMAIN} $(tenant_ip ${CONTROL_NAME})
done

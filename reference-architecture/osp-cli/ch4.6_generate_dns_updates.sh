#!/bin/sh

HOSTNAME=$1
OCP3_BASE_DOMAIN=${OCP3_BASE_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_BASE_DOMAIN}}
OCP3_TENANT_DOMAIN=${OCP3_TENANT_DOMAIN:-tenant.${OCP3_BASE_DOMAIN}}

BASTION="bastion"
MASTERS="master-0 master-1 master-2"
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
ALL_NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$BASTION $MASTERS $ALL_NODES"

OCP3_DNS_SERVER=${OCP3_DNS_SERVER:-10.19.114.130} # ns1.ose3.e2e.bos.redhat.com
OCP3_DNS_UPDATE_KEY=${OCP3_DNS_UPDATE_KEY:-keys/ns1.ose3.key}

function control_ip() {
    # HOSTNAME=$1
    nova show ${1} | \
        grep control-network | \
        cut -d\| -f3 | cut -d, -f1 | tr -d ' '
}

function tenant_ip() {
    # HOSTNAME=$1
    nova show ${1} | \
        grep tenant-network | \
        cut -d\| -f3 | cut -d, -f1 | tr -d ' '
}

function floating_ip() {
    # HOSTNAME=$1
    nova floating-ip-list | \
        grep $(control_ip $1) | \
        cut -d \| -f3 | tr -d ' '
}


function update_dns_a() {
    # FQDN=$1
    # IPADDR=$2
    echo "updating $1 => $2"
    nsupdate -k ${OCP3_DNS_UPDATE_KEY} <<EOF
server ${OCP3_DNS_SERVER}
zone ${OCP3_BASE_DOMAIN}
update delete $1 300 A
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
done

for HOST in $APP_NODES
do
    CONTROL_NAME=${HOST}.${OCP3_CONTROL_DOMAIN}
    update_dns_a ${CONTROL_NAME} $(control_ip ${CONTROL_NAME})
done

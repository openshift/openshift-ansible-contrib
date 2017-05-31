#!/bin/sh
DOMAIN=${DOMAIN:-control.ocp3.example.com}

BASTION="bastion"
MASTERS="master-0 master-1 master-2"
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
ALL_NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$BASTION $MASTERS $ALL_NODES"

function tenant_ip() {
  # HOSTNAME=$1
  nova show ${1} | grep tenant-network | cut -d\| -f3 | cut -d, -f1 | tr -d ' '
}

function port_id_by_ip() {
  # IP=$1
  neutron port-list --field id --field fixed_ips | grep $1 | cut -d' ' -f2
}

for NAME in $MASTERS $INFRA_NODES $APP_NODES
do
  TENANT_IP=$(tenant_ip ${NAME}.${DOMAIN})
  PORT_ID=$(port_id_by_ip $TENANT_IP)
  neutron port-update $PORT_ID --no-security-groups --port-security-enabled=False
done

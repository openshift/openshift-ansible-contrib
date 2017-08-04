#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
TENANT_NETWORK=${TENANT_NETWORK:-tenant-network}

MASTER_COUNT=${MASTER_COUNT:-3}
INFRA_NODE_COUNT=${INFRA_NODE_COUNT:-2}
APP_NODE_COUNT=${APP_NODE_COUNT:-3}

MASTERS=$(for M in $(seq 0 $(($MASTER_COUNT-1))) ; do echo master-$M ; done)
INFRA_NODES=$(for I in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do echo infra-node-$I ; done)
APP_NODES=$(for A in $(seq 0 $(($APP_NODE_COUNT-1))) ; do echo app-node-$A ; done)

function tenant_ip() {
  # HOSTNAME=$1
  nova show ${1} | grep ${TENANT_NETWORK} | cut -d\| -f3 | cut -d, -f1 | tr -d ' '
}

function port_id_by_ip() {
  # IP=$1
  neutron port-list --field id --field fixed_ips | grep $1 | cut -d' ' -f2
}

for NAME in $MASTERS $INFRA_NODES $APP_NODES
do
  TENANT_IP=$(tenant_ip ${NAME}.${OCP3_CONTROL_DOMAIN})
  PORT_ID=$(port_id_by_ip $TENANT_IP)
  neutron port-update $PORT_ID --no-security-groups --port-security-enabled=False
done

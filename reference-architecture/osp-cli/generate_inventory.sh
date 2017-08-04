#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
MASTER_COUNT=${MASTER_COUNT:-3}
INFRA_NODE_COUNT=${INFRA_NODE_COUNT:-2}
APP_NODE_COUNT=${APP_NODE_COUNT:-3}

INVENTORY=${INVENTORY:-inventory}

M=$(($MASTER_COUNT-1))
I=$(($INFRA_NODE_COUNT-1))
A=$(($APP_NODE_COUNT-1))

cat <<EOF > $INVENTORY
[OSEv3:children]
masters
etcd
nodes

[masters]
master-[0:${M}].${OCP3_CONTROL_DOMAIN} openshift_public_hostname=master-[0:${M}].${OCP3_DOMAIN}

[masters:vars]
openshift_schedulable=false
openshift_router_selector="region=infra"
openshift_registry_selector="region=infra"

[etcd]
master-[0:${M}].${OCP3_CONTROL_DOMAIN} openshift_public_hostname=master-[0:${M}].${OCP3_DOMAIN}

[infra-nodes]
infra-node-[0:${I}].${OCP3_CONTROL_DOMAIN} openshift_public_hostname=infra-node-[0:${I}].${OCP3_DOMAIN} openshift_node_labels="{'region': 'infra', 'zone': 'default'}"

[app-nodes]
app-node-[0:${A}].${OCP3_CONTROL_DOMAIN} openshift_public_hostname=app-node-[0:${A}].${OCP3_DOMAIN} openshift_node_labels="{'region': 'primary', 'zone': 'default'}"

[nodes:children]
infra-nodes
app-nodes
EOF

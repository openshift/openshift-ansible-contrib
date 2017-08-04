#!/bin/bash
#
# Copy files to the bastion
# Prepare the bastion to configure the rest of the VMs
# 
#
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
BASTION_HOST=${BASTION_HOST:-bastion.control.${OCP3_DOMAIN}}

function floating_ip() {
    # HOSTNAME=$1
    openstack server show $1 -f json |
        jq -r '.addresses | 
                 match("control-network=[\\d.]+, ([\\d.]+)") |
                 .captures[0].string'
}

BASTION_IP=$(floating_ip $BASTION_HOST)

INSTANCE_FILES="ansible.cfg inventory instance_hosts_ansible.sh ch5.8.*_ansible.sh"

sh ./generate_inventory.sh

scp -i ${OCP3_KEY_FILE} ${INSTANCE_FILES} cloud-user@${BASTION_IP}:
ssh -i ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} sh ./instance_hosts_ansible.sh

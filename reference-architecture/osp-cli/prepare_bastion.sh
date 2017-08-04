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

ssh-keygen -R ${BASTION_HOST}
ssh-keygen -R ${BASTION_IP}

# force add the SSH host key without checking
ssh -o StrictHostKeyChecking=no cloud-user@${BASTION_IP} true

scp -i $OCP3_KEY_FILE $OCP3_KEY_FILE  cloud-user@${BASTION_IP}:.ssh/id_rsa
ssh -i $OCP3_KEY_FILE cloud-user@${BASTION_IP} chmod 600 .ssh/id_rsa

# copy credentials if present
[ -f rhn_credentials ] &&
    scp -i ${OCP3_KEY_FILE} rhn_credentials cloud-user@${BASTION_IP}:

# register host and subscribe/attach
BASTION_FILES="bastion_host.sh ch5.8.1*.sh"
scp -i ${OCP3_KEY_FILE} ${BASTION_FILES} cloud-user@${BASTION_IP}:

ssh -i ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} sh ./bastion_host.sh


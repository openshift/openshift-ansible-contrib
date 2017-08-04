#!/bin/bash
#
# Push control files and install openshift
#
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
BASTION_PUBLIC=${BASTION_PUBLIC:-bastion.${OCP3_BASE_DOMAIN}}
BASTION_HOST=${BASTION_HOST:-bastion.control.${OCP3_DOMAIN}}

function floating_ip() {
    # HOSTNAME=$1
    openstack server show $1 -f json |
        jq -r '.addresses | 
                 match("control-network=[\\d.]+, ([\\d.]+)") |
                 .captures[0].string'
}

BASTION_IP=$(floating_ip $BASTION_HOST)

ANSIBLE_FILES="ch5.9_*.sh OSEv3.yml"
OCP3_ANSIBLE_ROOT=${OCP3_ANSIBLE_ROOT:-/usr/share/ansible}

# generate ansible files

sh ./generate_inventory.sh
sh ./generate_ansible_config.sh

scp -i ${OCP3_KEY_FILE} ${ANSIBLE_FILES} cloud-user@${BASTION_IP}:
ssh -i ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} 'mkdir -p group_vars ; mv OSEv3.yml group_vars'

if [ -n "${OCP3_ANSIBLE_GIT_URL}" ] ; then
    ssh -i  ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} sudo yum -y install git
    ssh -i  ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} git clone ${OCP3_ANSIBLE_GIT_URL}

    if [ -n "${OCP3_ANSIBLE_GIT_COMMIT}" ] ; then
	ssh -i  ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} "cd ${OCP3_ANSIBLE_ROOT}/openshift-ansible ; git checkout ${OCP3_ANSIBLE_GIT_COMMIT}" 
    fi
    OCP3_ANSIBLE_ENV="OCP3_ANSIBLE_ROOT=${OCP_ANSIBLE_ROOT}"
fi

ssh -i ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} "${OCP3_ANSIBLE_ENV} sh ./ch5.9_deploy_openshift.sh"
#ssh -i ${OCP3_KEY_FILE} cloud-user@${BASTION_IP} sh ./ch5.9_allow_docker_flannel.sh

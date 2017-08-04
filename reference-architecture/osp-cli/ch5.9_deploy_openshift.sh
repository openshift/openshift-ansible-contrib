#!/bin/sh
export OCP_ANSIBLE_ROOT=${OCP_ANSIBLE_ROOT:-/usr/share/ansible}
export ANSIBLE_ROLES_PATH=${ANSIBLE_ROLES_PATH:-${OCP_ANSIBLE_ROOT}/openshift-ansible/roles}
export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook -i ~/inventory \
  ${OCP_ANSIBLE_ROOT}/openshift-ansible/playbooks/byo/config.yml

#!/bin/bash

set -euo pipefail

source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" != "true" ]; then
    echo RUN_OPENSTACK_CI is set to false, skipping the openstack end to end test.
    exit
fi

# Do we have ssh keys?

export INVENTORY="$PWD/playbooks/provisioning/openstack/sample-inventory"


echo INSTALL OPENSHIFT

ansible-playbook --become --timeout 180 --user openshift --private-key ~/.ssh/id_rsa -i "$INVENTORY" ../openshift-ansible/playbooks/byo/config.yml

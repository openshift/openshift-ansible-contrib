#!/bin/bash

set -euo pipefail

source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" != "true" ]; then
    echo RUN_OPENSTACK_CI is set to false, skipping the openstack end to end test.
    exit
fi

if [ "${CI_OVER_CAPACITY:-}" == "true" ]; then
    echo the CI is over capacity, skipping the end-end test.
    exit 1
fi

export INVENTORY="$PWD/playbooks/provisioning/openstack/sample-inventory"

echo INSTALL OPENSHIFT

ansible-playbook --become --timeout 180 --user openshift --private-key ~/.ssh/id_rsa -i "$INVENTORY" ../openshift-ansible/playbooks/byo/config.yml -e @extra-vars.yaml

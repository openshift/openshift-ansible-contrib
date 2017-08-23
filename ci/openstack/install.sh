#!/bin/bash

set -euox pipefail

source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" != "true" ]; then
    echo RUN_OPENSTACK_CI is set to false, skipping the openstack end to end test.
    exit
fi

if [ "${CI_OVER_CAPACITY:-}" == "true" ]; then
    echo the CI is over capacity, skipping the end-end test.
    exit 1
fi

git clone https://github.com/openshift/openshift-ansible ../openshift-ansible
cd ../openshift-ansible
git checkout "${OPENSHIFT_ANSIBLE_COMMIT:-master}"
git status
cd ../openshift-ansible-contrib

pip install ansible shade dnspython python-openstackclient python-heatclient

#!/bin/bash

set -euo pipefail

source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" != "true" ]; then
    echo RUN_OPENSTACK_CI is set to false, skipping the openstack end to end test.
    exit
fi

git clone https://github.com/openshift/openshift-ansible ../openshift-ansible
cd ../openshift-ansible
git checkout openshift-ansible-3.6.153-1
cd ../openshift-ansible-contrib

pip install ansible shade dnspython python-openstackclient python-heatclient

curl -L -o oc.tgz https://github.com/openshift/origin/releases/download/v1.5.1/openshift-origin-client-tools-v1.5.1-7b451fc-linux-64bit.tar.gz
tar -xf oc.tgz
mv openshift-origin-client-tools-v1.5.1-7b451fc-linux-64bit bin

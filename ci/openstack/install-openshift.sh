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

ansible-playbook --become --timeout 180 --user openshift -i "$INVENTORY" ../openshift-ansible/playbooks/byo/config.yml -e openstack_inventory_path="$INVENTORY" -e @extra-vars.yaml


echo Waiting for the router to come up
for i in $(seq 15); do
    if ansible -i "$INVENTORY" masters --user openshift -m shell -a 'oc get pod | grep -v deploy | grep router | grep Running'; then
        echo Router is running
        break
    elif ansible -i "$INVENTORY" masters --user openshift -m shell -a 'oc get pod | grep -v deploy | grep router | grep Failed'; then
        echo Router failed
        break
    else
        printf .
        sleep 60
    fi
done

echo Waiting for the docker-registry to come up
for i in $(seq 15); do
    if ansible -i "$INVENTORY" masters --user openshift -m shell -a 'oc get pod | grep docker-registry | grep Running'; then
        echo Registry is running
        break
    elif ansible -i "$INVENTORY" masters --user openshift -m shell -a 'oc get pod | grep docker-registry | grep Failed'; then
        echo Registry failed
        break
    else
        printf .
        sleep 60
    fi
done

echo oc get nodes --show-labels:
ansible -i "$INVENTORY" masters --user openshift -m command -a 'oc get nodes --show-labels'

echo oc status -v:
ansible -i "$INVENTORY" masters --user openshift -m command -a 'oc status -v'

echo oc get all:
ansible -i "$INVENTORY" masters --user openshift -m command -a 'oc get all'

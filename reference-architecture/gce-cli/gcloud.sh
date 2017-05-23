#!/bin/bash

# MIT License
#
# Copyright (c) 2016 Peter Schiffer <pschiffe@redhat.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#
# Script to deploy infrastructure and OpenShift Cloud Platform on GCP.
#

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${DIR}/config.sh"

function echoerr {
    cat <<< "$@" 1>&2;
}

# Check $RHEL_IMAGE_PATH
if [ -z "$RHEL_IMAGE_PATH" ]; then
    echoerr '$RHEL_IMAGE_PATH variable is required'
    exit 1
fi
if [ ! -f "$RHEL_IMAGE_PATH" ]; then
    echoerr '$RHEL_IMAGE_PATH must exist'
    exit 1
fi
if [ "${RHEL_IMAGE_PATH:(-6)}" != '.qcow2' ]; then
    echoerr '$RHEL_IMAGE_PATH image must be in qcow2 format'
    exit 1
fi

# Check $RH_USERNAME
if [ -z "$RH_USERNAME" ]; then
    echoerr '$RH_USERNAME variable is required'
    exit 1
fi

# Check $RH_POOL_ID
if [ -z "$RH_POOL_ID" ]; then
    echoerr '$RH_POOL_ID variable is required'
    exit 1
fi

# Check $GCLOUD_PROJECT
if [ -z "$GCLOUD_PROJECT" ]; then
    echoerr '$GCLOUD_PROJECT variable is required'
    exit 1
fi

# Check $GCLOUD_ZONE
if [ -z "$GCLOUD_ZONE" ]; then
    echoerr '$GCLOUD_ZONE variable is required'
    exit 1
fi

# Check $DNS_DOMAIN
if [ -z "$DNS_DOMAIN" ]; then
    echoerr '$DNS_DOMAIN variable is required'
    exit 1
fi

# Check $GCLOUD_ZONE
if [ -z "$MASTER_DNS_NAME" ]; then
    echoerr '$MASTER_DNS_NAME variable is required'
    exit 1
fi

# Check $OCP_APPS_DNS_NAME
if [ -z "$OCP_APPS_DNS_NAME" ]; then
    echoerr '$OCP_APPS_DNS_NAME variable is required'
    exit 1
fi

# Check $MASTER_HTTPS_CERT_FILE and $MASTER_HTTPS_KEY_FILE
if [ -z "${MASTER_HTTPS_CERT_FILE:-}" ] || [ -z "${MASTER_HTTPS_KEY_FILE:-}" ]; then
    echo '$MASTER_HTTPS_CERT_FILE or $MASTER_HTTPS_KEY_FILE variable is empty - self-signed certificate will be generated'
fi

# Get basename of $RHEL_IMAGE_PATH without suffix
RHEL_IMAGE=$(basename "$RHEL_IMAGE_PATH")
RHEL_IMAGE=${RHEL_IMAGE%.qcow2}

# Image name in GCE can't contain '.' or '_', so replace them with '-'
RHEL_IMAGE_GCE=${RHEL_IMAGE//[._]/-}
GOLD_IMAGE="${RHEL_IMAGE_GCE}-gold"

# If user doesn't provide DNS_DOMAIN_NAME, create it
if [ -z "$DNS_DOMAIN_NAME" ]; then
    DNS_MANAGED_ZONE=${DNS_DOMAIN//./-}
else
    DNS_MANAGED_ZONE="$DNS_DOMAIN_NAME"
fi

GCLOUD_REGION=${GCLOUD_ZONE%-*}

# Configure python path
PYTHONPATH="${PYTHONPATH:-}:${DIR}/ansible/inventory/gce/hosts"
export PYTHONPATH

# Prepare main ansible config file based on the configuration from this script
export GCLOUD_PROJECT \
    GCLOUD_REGION \
    GCLOUD_ZONE \
    OCP_PREFIX \
    DNS_DOMAIN \
    MASTER_DNS_NAME \
    INTERNAL_MASTER_DNS_NAME \
    OCP_APPS_DNS_NAME \
    RHEL_IMAGE_PATH \
    CONSOLE_PORT \
    MASTER_HTTPS_KEY_FILE \
    MASTER_HTTPS_CERT_FILE \
    MASTER_INSTANCE_GROUP_SIZE \
    INFRA_NODE_INSTANCE_GROUP_SIZE \
    NODE_INSTANCE_GROUP_SIZE \
    BASTION_MACHINE_TYPE \
    MASTER_MACHINE_TYPE \
    NODE_MACHINE_TYPE \
    BASTION_DISK_SIZE \
    MASTER_BOOT_DISK_SIZE \
    NODE_BOOT_DISK_SIZE \
    NODE_DOCKER_DISK_SIZE \
    NODE_OPENSHIFT_DISK_SIZE \
    REGISTRY_BUCKET \
    OPENSHIFT_SDN \
    OPENSHIFT_METRICS \
    OCP_IDENTITY_PROVIDERS \
    DELETE_GOLD_IMAGE \
    DELETE_IMAGE
envsubst < "${DIR}/ansible-main-config.yaml.tpl" > "${DIR}/ansible-main-config.yaml"

function revert {
    pushd "${DIR}/ansible"
    ansible-playbook playbooks/teardown.yaml
    popd
}

# Support the revert option
if [ "${1:-}" = '--revert' ]; then
    revert
    exit 0
fi

### PROVISION THE INFRASTRUCTURE ###

# Run Ansible
pushd "${DIR}/ansible"
ansible-playbook -i inventory/inventory playbooks/prereq.yaml
ansible-playbook -e rhsm_user="${RH_USERNAME}" -e rhsm_password="${RH_PASSWORD}" -e rhsm_pool="${RH_POOL_ID}" playbooks/main.yaml
popd

echo
echo "Deployment is complete. OpenShift Console can be found at https://${MASTER_DNS_NAME}"
echo


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
# Script to run the ansible playbook
#

set -euo pipefail

source "${CONFIG_SCRIPT:-${DIR}/config.sh}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prepare config file for ansible based on the configuration from this script
export DNS_DOMAIN \
    OCP_APPS_DNS_NAME \
    MASTER_DNS_NAME \
    INTERNAL_MASTER_DNS_NAME \
    CONSOLE_PORT \
    INFRA_NODE_INSTANCE_GROUP_SIZE \
    REGISTRY_BUCKET \
    GCLOUD_PROJECT \
    OCP_NETWORK \
    OCP_IDENTITY_PROVIDERS
envsubst < "${DIR}/ansible-config.yml.tpl" > "${DIR}/working/ansible-config.yml"

export GCE_PROJECT=${GCLOUD_PROJECT}
export GCE_ZONE=${GCLOUD_ZONE}
export GCE_EMAIL=${GCLOUD_SERVICE_ACCOUNT}
export INVENTORY_IP_TYPE=${INVENTORY_IP_TYPE:-external}

pushd "${DIR}/../gce-ansible/"
ansible-playbook -e "@${DIR}/working/ansible-config.yml" "$@" "playbooks/openshift-install.yaml"
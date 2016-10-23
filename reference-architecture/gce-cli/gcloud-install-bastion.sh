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
# Script to prepare infrastructure for OpenShift Cloud Platform installation on GCE.
#

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CONFIG_SCRIPT:-${DIR}/config.sh}"

function echoerr {
    cat <<< "$@" 1>&2;
}

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

# Check $GCLOUD_ZONE
if [ -z "$MASTER_DNS_NAME" ]; then
    echoerr '$MASTER_DNS_NAME variable is required'
    exit 1
fi

# If user doesn't provide REGISTERED_IMAGE, create it
if [ -z "${REGISTERED_IMAGE:-}" ]; then
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

    # Get basename of $RHEL_IMAGE_PATH without suffix
    RHEL_IMAGE=$(basename "$RHEL_IMAGE_PATH")
    RHEL_IMAGE=${RHEL_IMAGE%.qcow2}

    # Image name in GCE can't contain '.' or '_', so replace them with '-'
    RHEL_IMAGE_GCE=${RHEL_IMAGE//[._]/-}
    REGISTERED_IMAGE="${RHEL_IMAGE_GCE}-registered"
fi

GCLOUD_REGION=${GCLOUD_ZONE%-*}

function revert {
    # Bastion instance
    if gcloud --project "$GCLOUD_PROJECT" compute instances describe "$BASTION_INSTANCE" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$BASTION_INSTANCE" --zone "$GCLOUD_ZONE"
    fi

    # Temp instance (it shouldn't exist, just to be sure..)
    if gcloud --project "$GCLOUD_PROJECT" compute instances describe "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
    fi
    if gcloud --project "$GCLOUD_PROJECT" compute disks describe "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
    fi

    # Firewall rules
    if gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "$BASTION_SSH_FW_RULE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute firewall-rules delete "$BASTION_SSH_FW_RULE"
    fi
}

# Support the revert option
if [ "${1:-}" = '--revert' ]; then
    revert
    exit 0
fi

metadata=""
if [[ -n "${STARTUP_SCRIPT_FILE:-}" ]]; then
    metadata+="startup-script=${STARTUP_SCRIPT_FILE}"
fi

# Create Bastion instance
(
if ! gcloud --project "$GCLOUD_PROJECT" compute instances describe "$BASTION_INSTANCE" --zone "$GCLOUD_ZONE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instances create "$BASTION_INSTANCE" --zone "$GCLOUD_ZONE" --machine-type "$BASTION_MACHINE_TYPE" --network "$OCP_NETWORK" --tags "bastion,ssh-external" --image "$REGISTERED_IMAGE" --boot-disk-size "20" --boot-disk-type "pd-ssd" --scopes logging-write,monitoring-write,useraccounts-ro,service-control,service-management,storage-rw,compute-rw --metadata-file="${metadata}"
else
    echo "Instance '${BASTION_INSTANCE}' already exists"
fi

# Allow bastion to connect via SSH to other instances via external IP
bastion_ext_ip=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="name=${BASTION_INSTANCE}" --format='value(EXTERNAL_IP)')
if ! gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "$BASTION_SSH_FW_RULE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute firewall-rules create "$BASTION_SSH_FW_RULE" --network "$OCP_NETWORK" --allow tcp:22 --source-ranges "$bastion_ext_ip"
else
    echo "Firewall rule '${BASTION_SSH_FW_RULE}' already exists"
fi
) &

for i in `jobs -p`; do wait $i; done

# Configure local SSH so we can connect directly to all instances
ssh_config_file=~/.ssh/config
if ! grep -q '# OpenShift on GCE Section' "$ssh_config_file"; then
    echo -e '\n# OpenShift on GCE Section\n' >> "$ssh_config_file"
    bastion_data=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter='name:bastion' --format='value(EXTERNAL_IP,id)')
    echo "Host bastion
    HostName $(echo $bastion_data | cut -d ' ' -f 1)
    User cloud-user
    IdentityFile ~/.ssh/google_compute_engine
    UserKnownHostsFile ~/.ssh/google_compute_known_hosts
    HostKeyAlias compute.$(echo $bastion_data | cut -d ' ' -f 2)
    IdentitiesOnly yes
    CheckHostIP no
" >> "$ssh_config_file"
    instances=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter='tags.items:ocp' --format='value(name)')
    for i in $instances; do
        echo "Host ${i}
    User cloud-user
    proxycommand ssh bastion -W %h:%p
" >> "$ssh_config_file"
    done
    echo -e '# End of OpenShift on GCE Section\n' >> "$ssh_config_file"
fi

gcloud --project "$GCLOUD_PROJECT" compute copy-files "${DIR}/ansible-config.yml" "cloud-user@${BASTION_INSTANCE}:" --zone "$GCLOUD_ZONE"

# Prepare bastion instance for openshift installation
gcloud --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${BASTION_INSTANCE}" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "sudo bash -euc '
    yum install -y python-libcloud atomic-openshift-utils;

    if ! grep -q \"export GCE_PROJECT=${GCLOUD_PROJECT}\" /etc/profile.d/ocp.sh 2>/dev/null; then
        echo \"export GCE_PROJECT=${GCLOUD_PROJECT}\" >> /etc/profile.d/ocp.sh;
    fi
    if ! grep -q \"export INVENTORY_IP_TYPE=internal\" /etc/profile.d/ocp.sh 2>/dev/null; then
        echo \"export INVENTORY_IP_TYPE=internal\" >> /etc/profile.d/ocp.sh;
    fi
'";
gcloud --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${BASTION_INSTANCE}" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "bash -euc '
    if [ ! -d ~/google-cloud-sdk ]; then
        curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-x86_64.tar.gz | tar -xz;
        ~/google-cloud-sdk/bin/gcloud -q components update;
        ~/google-cloud-sdk/install.sh -q --usage-reporting false;
    fi

    if [ ! -f ~/.ssh/google_compute_engine ]; then
        ssh-keygen -t rsa -f ~/.ssh/google_compute_engine -C cloud-user -N \"\";
    fi

    # This command will upload our public SSH key to the GCE project metadata
    ~/google-cloud-sdk/bin/gcloud compute ssh cloud-user@${BASTION_INSTANCE} --zone ${GCLOUD_ZONE} --command echo;

    if [ ! -d ~/openshift-ansible-contrib ]; then
        git clone https://github.com/openshift/openshift-ansible-contrib.git ~/openshift-ansible-contrib;
    fi
    pushd ~/openshift-ansible-contrib/reference-architecture/gce-ansible;
    ansible-playbook -e @~/ansible-config.yml playbooks/openshift-install.yaml;
'";

echo
echo "Deployment is complete. OpenShift Console can be found at https://${MASTER_DNS_NAME}"
echo

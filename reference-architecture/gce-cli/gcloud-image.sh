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
# Script to create base image for OpenShift Cloud Platform installation on GCE.
#

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CONFIG_SCRIPT:-${DIR}/config.sh}"

function echoerr {
    cat <<< "$@" 1>&2;
}

# Check $RHEL_IMAGE_PATH
if [ -z "$RHEL_IMAGE_PATH" ]; then
    echoerr '$RHEL_IMAGE_PATH variable is required'
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

GCLOUD_REGION=${GCLOUD_ZONE%-*}

function revert {
    # Pre-registered image
    if gcloud --project "$GCLOUD_PROJECT" compute images describe "$REGISTERED_IMAGE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute images delete "$REGISTERED_IMAGE"
    fi

    # RHEL image
    if gcloud --project "$GCLOUD_PROJECT" compute images describe "$RHEL_IMAGE_GCE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute images delete "$RHEL_IMAGE_GCE"
    fi
}

# Support the revert option
if [ "${1:-}" = '--revert' ]; then
    revert
    exit 0
fi

# Create SSH key for GCE
if [ ! -f "${GCLOUD_SSH_PRIVATE_KEY}" ]; then
    ssh-keygen -t rsa -f "${GCLOUD_SSH_PRIVATE_KEY}" -C gce-provision-cloud-user -N ''
    ssh-add "${GCLOUD_SSH_PRIVATE_KEY}" || true
fi

# Check if the ~/.ssh/google_compute_engine.pub key is in the project metadata, and if not, add it there
pub_key=$(cut -d ' ' -f 2 < "${GCLOUD_SSH_PRIVATE_KEY}.pub")
key_tmp_file='/tmp/ocp-gce-keys'
if ! gcloud --project "$GCLOUD_PROJECT" compute project-info describe | grep -q "$pub_key"; then
    if gcloud --project "$GCLOUD_PROJECT" compute project-info describe | grep -q ssh-rsa; then
        gcloud --project "$GCLOUD_PROJECT" compute project-info describe | grep ssh-rsa | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/value: //' > "$key_tmp_file"
    fi
    echo -n 'cloud-user:' >> "$key_tmp_file"
    cat "${GCLOUD_SSH_PRIVATE_KEY}.pub" >> "$key_tmp_file"
    gcloud --project "$GCLOUD_PROJECT" compute project-info add-metadata --metadata-from-file "sshKeys=${key_tmp_file}"
    rm -f "$key_tmp_file"
fi

### GENERATE THE IMAGE ###

# Upload image
if ! gcloud --project "$GCLOUD_PROJECT" compute images describe "$RHEL_IMAGE_GCE" &>/dev/null; then
    if [ ! -f "$RHEL_IMAGE_PATH" ]; then
        echoerr '$RHEL_IMAGE_PATH must exist'
        exit 1
    fi

    echo 'Converting gcow2 image to raw image:'
    qemu-img convert -p -S 4096 -f qcow2 -O raw "$RHEL_IMAGE_PATH" disk.raw
    echo 'Creating archive of raw image:'
    tar -Szcvf "${RHEL_IMAGE}.tar.gz" disk.raw
    bucket='gs://ocp-rhel-guest-raw-image'
    gsutil ls -p "$GCLOUD_PROJECT" "$bucket" &>/dev/null || gsutil mb -p "$GCLOUD_PROJECT" -l "$GCLOUD_REGION" "$bucket"
    gsutil ls -p "$GCLOUD_PROJECT" "${bucket}/${RHEL_IMAGE}.tar.gz" &>/dev/null || gsutil cp "${RHEL_IMAGE}.tar.gz" "$bucket"
    gcloud --project "$GCLOUD_PROJECT" compute images create "$RHEL_IMAGE_GCE" --source-uri "${bucket}/${RHEL_IMAGE}.tar.gz"
    gsutil rm -r "$bucket"
    rm -f disk.raw "${RHEL_IMAGE}.tar.gz"
else
    echo "Image '${RHEL_IMAGE_GCE}' already exists"
fi

# Create pre-registered image based on the uploaded image
if ! gcloud --project "$GCLOUD_PROJECT" compute images describe "$REGISTERED_IMAGE" &>/dev/null; then
    # Create the instance or fail
    if ! gcloud --project "$GCLOUD_PROJECT" compute instances create "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE" --machine-type "n1-standard-1" --network "$OCP_NETWORK" --image "$RHEL_IMAGE_GCE" --boot-disk-size "10" --no-boot-disk-auto-delete --boot-disk-type "pd-ssd" --tags "ssh-external"; then
        echo "Instance exists - to remove it run:"
        echo gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
        echo gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
        exit 1
    fi

    # Loop until the instance is up - permission errors here will wait forever
    until gcloud -q --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --command "echo" &>/dev/null; do
        echo "Waiting for '${TEMP_INSTANCE}' to come up..."
        sleep 5
    done

    # Set the initial state of the image
    if ! gcloud -q --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "sudo bash -euc '
        # enables pipelining
        sed -i \"s/Defaults\\s\\+requiretty/Defaults    !requiretty/g\" /etc/sudoers

        # register to subscription manager
        subscription-manager register --username=${RH_USERNAME} --password=${RH_PASSWORD};
        subscription-manager attach --pool=${RH_POOL_ID};
        subscription-manager repos --disable=\"*\";
        subscription-manager repos \
            --enable=\"rhel-7-server-rpms\" \
            --enable=\"rhel-7-server-extras-rpms\" \
            --enable=\"rhel-7-server-ose-${OCP_VERSION}-rpms\";

        yum -q list atomic-openshift-utils;

        cat << EOF > /etc/yum.repos.d/google-cloud.repo
[google-cloud-compute]
name=Google Cloud Compute
baseurl=https://packages.cloud.google.com/yum/repos/google-cloud-compute-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

        # install and clean
        yum install -y google-compute-engine google-compute-engine-init google-config wget git net-tools bind-utils iptables-services bridge-utils bash-completion python-httplib2 docker;
        yum update -y;
        yum clean all;
'"; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
        gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
        echoerr "Deployment failed, please check provided Red Hat Username, Password and Pool ID and rerun the script"
        exit 1
    fi

    # Commit the image
    gcloud --project "$GCLOUD_PROJECT" compute instances stop "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
    gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
    gcloud --project "$GCLOUD_PROJECT" compute images create "$REGISTERED_IMAGE" --source-disk "$TEMP_INSTANCE" --source-disk-zone "$GCLOUD_ZONE"
    gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
else
    echo "Image '${REGISTERED_IMAGE}' already exists"
fi

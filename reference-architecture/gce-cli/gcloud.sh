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

source "${DIR}/config.sh"

ssh_config_file=~/.ssh/config

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
REGISTERED_IMAGE="${RHEL_IMAGE_GCE}-registered"

# If user doesn't provide DNS_DOMAIN_NAME, create it
if [ -z "$DNS_DOMAIN_NAME" ]; then
    DNS_MANAGED_ZONE=${DNS_DOMAIN//./-}
else
    DNS_MANAGED_ZONE="$DNS_DOMAIN_NAME"
fi

GCLOUD_REGION=${GCLOUD_ZONE%-*}

function revert {
    # Bucket for registry
    if gsutil ls -p "$GCLOUD_PROJECT" "gs://${REGISTRY_BUCKET}" &>/dev/null; then
        gsutil -m rm -r "gs://${REGISTRY_BUCKET}"
    fi

    # DNS
    if gcloud --project "$GCLOUD_PROJECT" dns managed-zones describe "$DNS_MANAGED_ZONE" &>/dev/null; then
        # Easy way how to delete all records from a zone is to import empty file and specify '--delete-all-existing'
        EMPTY_FILE=/tmp/ocp-dns-records-empty.yml
        touch "$EMPTY_FILE"
        gcloud --project "$GCLOUD_PROJECT" dns record-sets import "$EMPTY_FILE" -z "$DNS_MANAGED_ZONE" --delete-all-existing &>/dev/null
        rm -f "$EMPTY_FILE"
    fi

    # Router forwarding rule
    if gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules describe "$ROUTER_NETWORK_LB_RULE" --region "$GCLOUD_REGION" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute forwarding-rules delete "$ROUTER_NETWORK_LB_RULE" --region "$GCLOUD_REGION"
    fi

    # Router IP
    if gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$ROUTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute addresses delete "$ROUTER_NETWORK_LB_IP" --region "$GCLOUD_REGION"
    fi

    # Router target pool
    if gcloud --project "$GCLOUD_PROJECT" compute target-pools describe "$ROUTER_NETWORK_LB_POOL" --region "$GCLOUD_REGION" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute target-pools delete "$ROUTER_NETWORK_LB_POOL" --region "$GCLOUD_REGION"
    fi

    # Router health check
    if gcloud --project "$GCLOUD_PROJECT" compute http-health-checks describe "$ROUTER_NETWORK_LB_HEALTH_CHECK" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute http-health-checks delete "$ROUTER_NETWORK_LB_HEALTH_CHECK"
    fi

    # Internal master forwarding rule
    if gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules describe "$MASTER_NETWORK_LB_RULE" --region "$GCLOUD_REGION" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute forwarding-rules delete "$MASTER_NETWORK_LB_RULE" --region "$GCLOUD_REGION"
    fi

    # Internal master IP
    if gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute addresses delete "$MASTER_NETWORK_LB_IP" --region "$GCLOUD_REGION"
    fi

    # Internal master target pool
    if gcloud --project "$GCLOUD_PROJECT" compute target-pools describe "$MASTER_NETWORK_LB_POOL" --region "$GCLOUD_REGION" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute target-pools delete "$MASTER_NETWORK_LB_POOL" --region "$GCLOUD_REGION"
    fi

    # Internal master health check
    if gcloud --project "$GCLOUD_PROJECT" compute http-health-checks describe "$MASTER_NETWORK_LB_HEALTH_CHECK" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute http-health-checks delete "$MASTER_NETWORK_LB_HEALTH_CHECK"
    fi

    # Master forwarding rule
    if gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules describe "$MASTER_SSL_LB_RULE" --global &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute forwarding-rules delete "$MASTER_SSL_LB_RULE" --global
    fi

    # Master target proxy
    if gcloud --project "$GCLOUD_PROJECT" compute target-ssl-proxies describe "$MASTER_SSL_LB_TARGET" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute target-ssl-proxies delete "$MASTER_SSL_LB_TARGET"
    fi

    # Master certificate
    if gcloud --project "$GCLOUD_PROJECT" compute ssl-certificates describe "$MASTER_SSL_LB_CERT" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute ssl-certificates delete "$MASTER_SSL_LB_CERT"
    fi

    # Master IP
    if gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_SSL_LB_IP" --global &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute addresses delete "$MASTER_SSL_LB_IP" --global
    fi

    # Master backend service
    if gcloud --project "$GCLOUD_PROJECT" beta compute backend-services describe "$MASTER_SSL_LB_BACKEND" --global &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" beta compute backend-services delete "$MASTER_SSL_LB_BACKEND" --global
    fi

    # Master health check
    if gcloud --project "$GCLOUD_PROJECT" compute health-checks describe "$MASTER_SSL_LB_HEALTH_CHECK" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute health-checks delete "$MASTER_SSL_LB_HEALTH_CHECK"
    fi

    # Additional disks for node instances for docker and openshift storage
    instances=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter='tags.items:ocp-node OR tags.items:ocp-infra-node' --format='value(name)')
    for i in $instances; do
        docker_disk="${i}${NODE_DOCKER_DISK_POSTFIX}"
        openshift_disk="${i}${NODE_OPENSHIFT_DISK_POSTFIX}"
        instance_zone=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="name:${i}" --format='value(zone)')
        if gcloud --project "$GCLOUD_PROJECT" compute disks describe "$docker_disk" --zone "$instance_zone" &>/dev/null; then
            gcloud --project "$GCLOUD_PROJECT" compute instances detach-disk "${i}" --disk "$docker_disk" --zone "$instance_zone"
            gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$docker_disk" --zone "$instance_zone"
        fi
        if gcloud --project "$GCLOUD_PROJECT" compute disks describe "$openshift_disk" --zone "$instance_zone" &>/dev/null; then
            gcloud --project "$GCLOUD_PROJECT" compute instances detach-disk "${i}" --disk "$openshift_disk" --zone "$instance_zone"
            gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$openshift_disk" --zone "$instance_zone"
        fi
    done

    # Master instance group
    if gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed describe "$MASTER_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" beta compute instance-groups managed delete "$MASTER_INSTANCE_GROUP" --zone "$GCLOUD_ZONE"
    fi

    # Node instance group
    if gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed describe "$NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" beta compute instance-groups managed delete "$NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE"
    fi

    # Infra node instance group
    if gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed describe "$INFRA_NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" beta compute instance-groups managed delete "$INFRA_NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE"
    fi

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

    # Master instance template
    if gcloud --project "$GCLOUD_PROJECT" compute instance-templates describe "$MASTER_INSTANCE_TEMPLATE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instance-templates delete "$MASTER_INSTANCE_TEMPLATE"
    fi

    # Node instance template
    if gcloud --project "$GCLOUD_PROJECT" compute instance-templates describe "$NODE_INSTANCE_TEMPLATE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instance-templates delete "$NODE_INSTANCE_TEMPLATE"
    fi

    # Infra node instance template
    if gcloud --project "$GCLOUD_PROJECT" compute instance-templates describe "$INFRA_NODE_INSTANCE_TEMPLATE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instance-templates delete "$INFRA_NODE_INSTANCE_TEMPLATE"
    fi

    # Pre-registered image
    if gcloud --project "$GCLOUD_PROJECT" compute images describe "$REGISTERED_IMAGE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute images delete "$REGISTERED_IMAGE"
    fi

    # Firewall rules
    for rule in "${!FW_RULES[@]}"; do
        if gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "$rule" &>/dev/null; then
            gcloud -q --project "$GCLOUD_PROJECT" compute firewall-rules delete "$rule"
        fi
    done
    if gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "$BASTION_SSH_FW_RULE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute firewall-rules delete "$BASTION_SSH_FW_RULE"
    fi

    # Network
    if gcloud --project "$GCLOUD_PROJECT" compute networks describe "$OCP_NETWORK" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute networks delete "$OCP_NETWORK"
    fi

    # RHEL image
    if gcloud --project "$GCLOUD_PROJECT" compute images describe "$RHEL_IMAGE_GCE" &>/dev/null && [ "$DELETE_IMAGE" = true ]; then
        gcloud -q --project "$GCLOUD_PROJECT" compute images delete "$RHEL_IMAGE_GCE"
    fi

    # Remove configuration from local ~/.ssh/config file
    sed -i '/^# OpenShift on GCE Section$/,/^# End of OpenShift on GCE Section$/d' "$ssh_config_file"
}

# Support the revert option
if [ "${1:-}" = '--revert' ]; then
    revert
    exit 0
fi

### PROVISION THE INFRASTRUCTURE ###

# Check the DNS managed zone in Google Cloud DNS, create it if it doesn't exist and exit after printing NS servers
if ! gcloud --project "$GCLOUD_PROJECT" dns managed-zones describe "$DNS_MANAGED_ZONE" &>/dev/null; then
    echo "DNS zone '${DNS_MANAGED_ZONE}' doesn't exist. It will be created and installation will stop. Please configure the following NS servers for your domain in your domain provider before proceeding with the installation:"
    gcloud --project "$GCLOUD_PROJECT" dns managed-zones create "$DNS_MANAGED_ZONE" --dns-name "$DNS_DOMAIN" --description "${DNS_DOMAIN} domain"
    gcloud --project "$GCLOUD_PROJECT" dns managed-zones describe "$DNS_MANAGED_ZONE" --format='value(nameServers)' | tr ';' '\n'
    exit 0
fi

# Upload image
if ! gcloud --project "$GCLOUD_PROJECT" compute images describe "$RHEL_IMAGE_GCE" &>/dev/null; then
    echo 'Converting gcow2 image to raw image:'
    qemu-img convert -p -S 4096 -f qcow2 -O raw "$RHEL_IMAGE_PATH" disk.raw
    echo 'Creating archive of raw image:'
    tar -Szcvf "${RHEL_IMAGE}.tar.gz" disk.raw
    bucket="gs://${IMAGE_BUCKET}"
    gsutil ls -p "$GCLOUD_PROJECT" "$bucket" &>/dev/null || gsutil mb -p "$GCLOUD_PROJECT" -l "$GCLOUD_REGION" "$bucket"
    gsutil ls -p "$GCLOUD_PROJECT" "${bucket}/${RHEL_IMAGE}.tar.gz" &>/dev/null || gsutil cp "${RHEL_IMAGE}.tar.gz" "$bucket"
    gcloud --project "$GCLOUD_PROJECT" compute images create "$RHEL_IMAGE_GCE" --source-uri "${bucket}/${RHEL_IMAGE}.tar.gz"
    gsutil -m rm -r "$bucket"
    rm -f disk.raw "${RHEL_IMAGE}.tar.gz"
else
    echo "Image '${RHEL_IMAGE_GCE}' already exists"
fi

# Create network
if ! gcloud --project "$GCLOUD_PROJECT" compute networks describe "$OCP_NETWORK" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute networks create "$OCP_NETWORK" --mode "auto"
else
    echo "Network '${OCP_NETWORK}' already exists"
fi

# Create firewall rules
for rule in "${!FW_RULES[@]}"; do
    if ! gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "$rule" &>/dev/null; then
        gcloud --project "$GCLOUD_PROJECT" compute firewall-rules create "$rule" --network "$OCP_NETWORK" ${FW_RULES[$rule]}
    else
        echo "Firewall rule '${rule}' already exists"
    fi
done

# Create SSH key for GCE
if [ ! -f ~/.ssh/google_compute_engine ]; then
    ssh-keygen -t rsa -f ~/.ssh/google_compute_engine -C cloud-user -N ''
    if [ -z "${SSH_AGENT_PID:-}" ]; then
        eval $(ssh-agent -s)
    fi
    ssh-add ~/.ssh/google_compute_engine
fi

# Check if the ~/.ssh/google_compute_engine.pub key is in the project metadata, and if not, add it there
pub_key=$(cut -d ' ' -f 2 < ~/.ssh/google_compute_engine.pub)
key_tmp_file='/tmp/ocp-gce-keys'
if ! gcloud --project "$GCLOUD_PROJECT" compute project-info describe | grep -q "$pub_key"; then
    if gcloud --project "$GCLOUD_PROJECT" compute project-info describe | grep -q ssh-rsa; then
        gcloud --project "$GCLOUD_PROJECT" compute project-info describe | grep ssh-rsa | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/value: //' > "$key_tmp_file"
    fi
    echo -n 'cloud-user:' >> "$key_tmp_file"
    cat ~/.ssh/google_compute_engine.pub >> "$key_tmp_file"
    gcloud --project "$GCLOUD_PROJECT" compute project-info add-metadata --metadata-from-file "sshKeys=${key_tmp_file}"
    rm -f "$key_tmp_file"
fi

# Create pre-registered image based on the uploaded image
if ! gcloud --project "$GCLOUD_PROJECT" compute images describe "$REGISTERED_IMAGE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instances create "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE" --machine-type "n1-standard-1" --network "$OCP_NETWORK" --image "$RHEL_IMAGE_GCE" --boot-disk-size "10" --no-boot-disk-auto-delete --boot-disk-type "pd-ssd" --tags "ssh-external"
    until gcloud -q --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --command "echo" &>/dev/null; do
        echo "Waiting for '${TEMP_INSTANCE}' to come up..."
        sleep 5
    done
    if ! gcloud -q --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "sudo bash -euc '
        subscription-manager register --username=${RH_USERNAME} --password=\"${RH_PASSWORD}\";
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

        yum install -y google-compute-engine google-compute-engine-init google-config wget git net-tools bind-utils iptables-services bridge-utils bash-completion python-httplib2 docker;
        yum update -y;
        yum clean all;
'"; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
        gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
        echoerr "Deployment failed, please check provided Red Hat Username, Password and Pool ID and rerun the script"
        exit 1
    fi
    gcloud --project "$GCLOUD_PROJECT" compute instances stop "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
    gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
    gcloud --project "$GCLOUD_PROJECT" compute images create "$REGISTERED_IMAGE" --source-disk "$TEMP_INSTANCE" --source-disk-zone "$GCLOUD_ZONE"
    gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "$TEMP_INSTANCE" --zone "$GCLOUD_ZONE"
else
    echo "Image '${REGISTERED_IMAGE}' already exists"
fi

# Create instance templates
if ! gcloud --project "$GCLOUD_PROJECT" compute instance-templates describe "$MASTER_INSTANCE_TEMPLATE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instance-templates create "$MASTER_INSTANCE_TEMPLATE" --machine-type "$MASTER_MACHINE_TYPE" --network "$OCP_NETWORK" --tags "ocp,ocp-master" --image "$REGISTERED_IMAGE" --boot-disk-size "35" --boot-disk-type "pd-ssd" --scopes logging-write,monitoring-write,useraccounts-ro,service-control,service-management,storage-ro,compute-rw
else
    echo "Instance template '${MASTER_INSTANCE_TEMPLATE}' already exists"
fi
if ! gcloud --project "$GCLOUD_PROJECT" compute instance-templates describe "$NODE_INSTANCE_TEMPLATE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instance-templates create "$NODE_INSTANCE_TEMPLATE" --machine-type "$NODE_MACHINE_TYPE" --network "$OCP_NETWORK" --tags "ocp,ocp-node" --image "$REGISTERED_IMAGE" --boot-disk-size "25" --boot-disk-type "pd-ssd" --scopes logging-write,monitoring-write,useraccounts-ro,service-control,service-management,storage-ro,compute-rw
else
    echo "Instance template '${NODE_INSTANCE_TEMPLATE}' already exists"
fi
if ! gcloud --project "$GCLOUD_PROJECT" compute instance-templates describe "$INFRA_NODE_INSTANCE_TEMPLATE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instance-templates create "$INFRA_NODE_INSTANCE_TEMPLATE" --machine-type "$INFRA_NODE_MACHINE_TYPE" --network "$OCP_NETWORK" --tags "ocp,ocp-infra-node" --image "$REGISTERED_IMAGE" --boot-disk-size "25" --boot-disk-type "pd-ssd" --scopes logging-write,monitoring-write,useraccounts-ro,service-control,service-management,storage-rw,compute-rw
else
    echo "Instance template '${INFRA_NODE_INSTANCE_TEMPLATE}' already exists"
fi

# Create Bastion instance
if ! gcloud --project "$GCLOUD_PROJECT" compute instances describe "$BASTION_INSTANCE" --zone "$GCLOUD_ZONE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instances create "$BASTION_INSTANCE" --zone "$GCLOUD_ZONE" --machine-type "$BASTION_MACHINE_TYPE" --network "$OCP_NETWORK" --tags "bastion,ssh-external" --image "$REGISTERED_IMAGE" --boot-disk-size "20" --boot-disk-type "pd-ssd" --scopes logging-write,monitoring-write,useraccounts-ro,service-control,service-management,storage-rw,compute-rw
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

# Create Infra node instance group
if ! gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed describe "$INFRA_NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed create "$INFRA_NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" --template "$INFRA_NODE_INSTANCE_TEMPLATE" --size "$INFRA_NODE_INSTANCE_GROUP_SIZE"
else
    echo "Instance group '${INFRA_NODE_INSTANCE_GROUP}' already exists"
fi

# Create Node instance group
if ! gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed describe "$NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed create "$NODE_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" --template "$NODE_INSTANCE_TEMPLATE" --size "$NODE_INSTANCE_GROUP_SIZE"
else
    echo "Instance group '${NODE_INSTANCE_GROUP}' already exists"
fi

# Create Master instance group
if ! gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed describe "$MASTER_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed create "$MASTER_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" --template "$MASTER_INSTANCE_TEMPLATE" --size "$MASTER_INSTANCE_GROUP_SIZE"
    gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed set-named-ports "$MASTER_INSTANCE_GROUP" --zone "$GCLOUD_ZONE" --named-ports "${MASTER_NAMED_PORT_NAME}:${CONSOLE_PORT}"
else
    echo "Instance group '${MASTER_INSTANCE_GROUP}' already exists"
fi

# Attach additional disks to node instances for docker and openshift storage
instances=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter='tags.items:ocp-node OR tags.items:ocp-infra-node' --format='value(name)')
for i in $instances; do
    docker_disk="${i}${NODE_DOCKER_DISK_POSTFIX}"
    openshift_disk="${i}${NODE_OPENSHIFT_DISK_POSTFIX}"
    instance_zone=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="name:${i}" --format='value(zone)')
    if ! gcloud --project "$GCLOUD_PROJECT" compute disks describe "$docker_disk" --zone "$instance_zone" &>/dev/null; then
        gcloud --project "$GCLOUD_PROJECT" compute disks create "$docker_disk" --zone "$instance_zone" --size "$NODE_DOCKER_DISK_SIZE" --type "pd-ssd"
        gcloud --project "$GCLOUD_PROJECT" compute instances attach-disk "${i}" --disk "$docker_disk" --zone "$instance_zone"
    else
        echo "Disk '${docker_disk}' already exists"
    fi
    if ! gcloud --project "$GCLOUD_PROJECT" compute disks describe "$openshift_disk" --zone "$instance_zone" &>/dev/null; then
        gcloud --project "$GCLOUD_PROJECT" compute disks create "$openshift_disk" --zone "$instance_zone" --size "$NODE_OPENSHIFT_DISK_SIZE" --type "pd-ssd"
        gcloud --project "$GCLOUD_PROJECT" compute instances attach-disk "${i}" --disk "$openshift_disk" --zone "$instance_zone"
    else
        echo "Disk '${openshift_disk}' already exists"
    fi
done

# Master health check
if ! gcloud --project "$GCLOUD_PROJECT" compute health-checks describe "$MASTER_SSL_LB_HEALTH_CHECK" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute health-checks create https "$MASTER_SSL_LB_HEALTH_CHECK" --port "$CONSOLE_PORT" --request-path "/healthz"
else
    echo "Health check '${MASTER_SSL_LB_HEALTH_CHECK}' already exists"
fi

# Master backend service
if ! gcloud --project "$GCLOUD_PROJECT" beta compute backend-services describe "$MASTER_SSL_LB_BACKEND" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" beta compute backend-services create "$MASTER_SSL_LB_BACKEND" --health-checks "$MASTER_SSL_LB_HEALTH_CHECK" --port-name "$MASTER_NAMED_PORT_NAME" --protocol "SSL" --global
    gcloud --project "$GCLOUD_PROJECT" beta compute backend-services add-backend "$MASTER_SSL_LB_BACKEND" --instance-group "$MASTER_INSTANCE_GROUP" --global --instance-group-zone "$GCLOUD_ZONE"
else
    echo "Backend service '${MASTER_SSL_LB_BACKEND}' already exists"
fi

# Master IP
if ! gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_SSL_LB_IP" --global &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute addresses create "$MASTER_SSL_LB_IP" --global
else
    echo "IP '${MASTER_SSL_LB_IP}' already exists"
fi

# Master Certificate
if ! gcloud --project "$GCLOUD_PROJECT" compute ssl-certificates describe "$MASTER_SSL_LB_CERT" &>/dev/null; then
    if [ -z "${MASTER_HTTPS_KEY_FILE:-}" ] || [ -z "${MASTER_HTTPS_CERT_FILE:-}" ]; then
        KEY='/tmp/ocp-ssl.key'
        CERT='/tmp/ocp-ssl.crt'
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -subj "/C=US/L=Raleigh/O=${DNS_DOMAIN}/CN=${MASTER_DNS_NAME}" -keyout "$KEY" -out "$CERT"
    else
        KEY="$MASTER_HTTPS_KEY_FILE"
        CERT="$MASTER_HTTPS_CERT_FILE"
    fi
    gcloud --project "$GCLOUD_PROJECT" compute ssl-certificates create "$MASTER_SSL_LB_CERT" --private-key "$KEY" --certificate "$CERT"
    if [ -z "${MASTER_HTTPS_KEY_FILE:-}" ] || [ -z "${MASTER_HTTPS_CERT_FILE:-}" ]; then
        rm -fv "$KEY" "$CERT"
    fi
else
    echo "Certificate '${MASTER_SSL_LB_CERT}' already exists"
fi

# Master ssl proxy target
if ! gcloud --project "$GCLOUD_PROJECT" compute target-ssl-proxies describe "$MASTER_SSL_LB_TARGET" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute target-ssl-proxies create "$MASTER_SSL_LB_TARGET" --backend-service "$MASTER_SSL_LB_BACKEND" --ssl-certificate "$MASTER_SSL_LB_CERT"
else
    echo "Proxy target '${MASTER_SSL_LB_TARGET}' already exists"
fi

# Master forwarding rule
if ! gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules describe "$MASTER_SSL_LB_RULE" --global &>/dev/null; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_SSL_LB_IP" --global --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules create "$MASTER_SSL_LB_RULE" --address "$IP" --global --ports "$CONSOLE_PORT" --target-ssl-proxy "$MASTER_SSL_LB_TARGET"
else
    echo "Forwarding rule '${MASTER_SSL_LB_RULE}' already exists"
fi

# Internal master health check
if ! gcloud --project "$GCLOUD_PROJECT" compute http-health-checks describe "$MASTER_NETWORK_LB_HEALTH_CHECK" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute http-health-checks create "$MASTER_NETWORK_LB_HEALTH_CHECK" --port "8080" --request-path "/healthz"
else
    echo "Health check '${MASTER_NETWORK_LB_HEALTH_CHECK}' already exists"
fi

# Internal master target pool
if ! gcloud --project "$GCLOUD_PROJECT" compute target-pools describe "$MASTER_NETWORK_LB_POOL" --region "$GCLOUD_REGION" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute target-pools create "$MASTER_NETWORK_LB_POOL" --http-health-check "$MASTER_NETWORK_LB_HEALTH_CHECK" --region "$GCLOUD_REGION"
    gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed set-target-pools "$MASTER_INSTANCE_GROUP" --target-pools "$MASTER_NETWORK_LB_POOL" --zone "$GCLOUD_ZONE"
else
    echo "Target pool '${MASTER_NETWORK_LB_POOL}' already exists"
fi

# Internal master IP
if ! gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute addresses create "$MASTER_NETWORK_LB_IP" --region "$GCLOUD_REGION"
else
    echo "IP '${MASTER_NETWORK_LB_IP}' already exists"
fi

# Internal master forwarding rule
if ! gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules describe "$MASTER_NETWORK_LB_RULE" --region "$GCLOUD_REGION" &>/dev/null; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules create "$MASTER_NETWORK_LB_RULE" --address "$IP" --ports "$CONSOLE_PORT" --region "$GCLOUD_REGION" --target-pool "$MASTER_NETWORK_LB_POOL"
else
    echo "Forwarding rule '${MASTER_NETWORK_LB_RULE}' already exists"
fi

# Router health check
if ! gcloud --project "$GCLOUD_PROJECT" compute http-health-checks describe "$ROUTER_NETWORK_LB_HEALTH_CHECK" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute http-health-checks create "$ROUTER_NETWORK_LB_HEALTH_CHECK" --port "1936" --request-path "/healthz"
else
    echo "Health check '${ROUTER_NETWORK_LB_HEALTH_CHECK}' already exists"
fi

# Router target pool
if ! gcloud --project "$GCLOUD_PROJECT" compute target-pools describe "$ROUTER_NETWORK_LB_POOL" --region "$GCLOUD_REGION" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute target-pools create "$ROUTER_NETWORK_LB_POOL" --http-health-check "$ROUTER_NETWORK_LB_HEALTH_CHECK" --region "$GCLOUD_REGION"
    gcloud --project "$GCLOUD_PROJECT" beta compute instance-groups managed set-target-pools "$INFRA_NODE_INSTANCE_GROUP" --target-pools "$ROUTER_NETWORK_LB_POOL" --zone "$GCLOUD_ZONE"
else
    echo "Target pool '${ROUTER_NETWORK_LB_POOL}' already exists"
fi

# Router IP
if ! gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$ROUTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute addresses create "$ROUTER_NETWORK_LB_IP" --region "$GCLOUD_REGION"
else
    echo "IP '${ROUTER_NETWORK_LB_IP}' already exists"
fi

# Router forwarding rule
if ! gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules describe "$ROUTER_NETWORK_LB_RULE" --region "$GCLOUD_REGION" &>/dev/null; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$ROUTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" compute forwarding-rules create "$ROUTER_NETWORK_LB_RULE" --address "$IP" --ports '80-443' --region "$GCLOUD_REGION" --target-pool "$ROUTER_NETWORK_LB_POOL"
else
    echo "Forwarding rule '${ROUTER_NETWORK_LB_RULE}' already exists"
fi

# DNS record for master lb
if ! gcloud --project "$GCLOUD_PROJECT" dns record-sets list -z "$DNS_MANAGED_ZONE" --name "$MASTER_DNS_NAME" 2>/dev/null | grep -q "$MASTER_DNS_NAME"; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_SSL_LB_IP" --global --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction start -z "$DNS_MANAGED_ZONE"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction add -z "$DNS_MANAGED_ZONE" --ttl 3600 --name "${MASTER_DNS_NAME}." --type A "$IP"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction execute -z "$DNS_MANAGED_ZONE"
else
    echo "DNS record for '${MASTER_DNS_NAME}' already exists"
fi

# DNS record for internal master lb
if ! gcloud --project "$GCLOUD_PROJECT" dns record-sets list -z "$DNS_MANAGED_ZONE" --name "$INTERNAL_MASTER_DNS_NAME" 2>/dev/null | grep -q "$INTERNAL_MASTER_DNS_NAME"; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$MASTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction start -z "$DNS_MANAGED_ZONE"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction add -z "$DNS_MANAGED_ZONE" --ttl 3600 --name "${INTERNAL_MASTER_DNS_NAME}." --type A "$IP"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction execute -z "$DNS_MANAGED_ZONE"
else
    echo "DNS record for '${INTERNAL_MASTER_DNS_NAME}' already exists"
fi

# DNS record for router lb
if ! gcloud --project "$GCLOUD_PROJECT" dns record-sets list -z "$DNS_MANAGED_ZONE" --name "$OCP_APPS_DNS_NAME" 2>/dev/null | grep -q "$OCP_APPS_DNS_NAME"; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "$ROUTER_NETWORK_LB_IP" --region "$GCLOUD_REGION" --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction start -z "$DNS_MANAGED_ZONE"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction add -z "$DNS_MANAGED_ZONE" --ttl 3600 --name "${OCP_APPS_DNS_NAME}." --type A "$IP"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction add -z "$DNS_MANAGED_ZONE" --ttl 3600 --name "*.${OCP_APPS_DNS_NAME}." --type CNAME "${OCP_APPS_DNS_NAME}."
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction execute -z "$DNS_MANAGED_ZONE"
else
    echo "DNS record for '${OCP_APPS_DNS_NAME}' already exists"
fi

# Create bucket for registry
if ! gsutil ls -p "$GCLOUD_PROJECT" "gs://${REGISTRY_BUCKET}" &>/dev/null; then
    gsutil mb -p "$GCLOUD_PROJECT" -l "$GCLOUD_REGION" "gs://${REGISTRY_BUCKET}"
else
    echo "Bucket '${REGISTRY_BUCKET}' already exists"
fi

# Configure local SSH so we can connect directly to all instances
touch "$ssh_config_file"
chmod 600 "$ssh_config_file"
sed -i '/^# OpenShift on GCE Section$/,/^# End of OpenShift on GCE Section$/d' "$ssh_config_file"
echo -e '# OpenShift on GCE Section\n' >> "$ssh_config_file"
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
    IdentityFile ~/.ssh/google_compute_engine
    proxycommand ssh bastion -W %h:%p
" >> "$ssh_config_file"
done
echo -e '# End of OpenShift on GCE Section\n' >> "$ssh_config_file"

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
envsubst < "${DIR}/ansible-config.yml.tpl" > "${DIR}/ansible-config.yml"
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

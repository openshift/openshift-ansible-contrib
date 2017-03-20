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

function revert {
    # Unregister systems
    gcloud --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${OCP_PREFIX}-bastion" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "bash -euc '
    pushd ~/openshift-ansible-contrib/reference-architecture/gce-ansible;
    ansible-playbook playbooks/unregister.yaml;
    '";

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

    # Core deployment
    if gcloud --project "$GCLOUD_PROJECT" deployment-manager deployments describe "${OCP_PREFIX}-${CORE_DEPLOYMENT}" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" deployment-manager deployments delete "${OCP_PREFIX}-${CORE_DEPLOYMENT}"
    fi

    # Master certificate
    if gcloud --project "$GCLOUD_PROJECT" compute ssl-certificates describe "${OCP_PREFIX}-${MASTER_SSL_LB_CERT}" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute ssl-certificates delete "${OCP_PREFIX}-${MASTER_SSL_LB_CERT}"
    fi

    # Temp instance (it shouldn't exist, just to be sure..)
    if gcloud --project "$GCLOUD_PROJECT" compute instances describe "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
    fi
    if gcloud --project "$GCLOUD_PROJECT" compute disks describe "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
    fi

    # Dynamic firewall rule
    if gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "${OCP_PREFIX}-${BASTION_SSH_FW_RULE}" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" compute firewall-rules delete "${OCP_PREFIX}-${BASTION_SSH_FW_RULE}"
    fi

    # Network deployment
    if gcloud --project "$GCLOUD_PROJECT" deployment-manager deployments describe "${OCP_PREFIX}-${NETWORK_DEPLOYMENT}" &>/dev/null; then
        gcloud -q --project "$GCLOUD_PROJECT" deployment-manager deployments delete "${OCP_PREFIX}-${NETWORK_DEPLOYMENT}"
    fi

    # Gold image
    if gcloud --project "$GCLOUD_PROJECT" compute images describe "$GOLD_IMAGE" &>/dev/null && [ "$DELETE_GOLD_IMAGE" = 'true' ]; then
        gcloud -q --project "$GCLOUD_PROJECT" compute images delete "$GOLD_IMAGE"
    fi

    # RHEL image
    if gcloud --project "$GCLOUD_PROJECT" compute images describe "$RHEL_IMAGE_GCE" &>/dev/null && [ "$DELETE_IMAGE" = 'true' ]; then
        gcloud -q --project "$GCLOUD_PROJECT" compute images delete "$RHEL_IMAGE_GCE"
    fi

    # Remove configuration from local ~/.ssh/config file
    sed -i '/^# OpenShift on GCP Section$/,/^# End of OpenShift on GCP Section$/d' "$SSH_CONFIG_FILE"
}

# Support the revert option
if [ "${1:-}" = '--revert' ]; then
    revert
    exit 0
fi

### PROVISION THE INFRASTRUCTURE ###

# Prepare main ansible config file based on the configuration from this script
export GCLOUD_PROJECT \
    GCLOUD_REGION \
    GCLOUD_ZONE \
    OCP_PREFIX
envsubst < "${DIR}/ansible-main-config.yaml.tpl" > "${DIR}/ansible-main-config.yaml"

# Configure ansible connection to the GCP
pushd "${DIR}/ansible"
ansible-playbook -i inventory/inventory playbooks/local.yaml
popd

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

# Deploy network and firewall rules
export OCP_PREFIX \
    GCLOUD_REGION \
    CONSOLE_PORT
envsubst < "${DIR}/deployment-manager/deployment-net-config.yml.tpl" > "${DIR}/deployment-manager/deployment-net-config.yml"
if ! gcloud --project "$GCLOUD_PROJECT" deployment-manager deployments describe "${OCP_PREFIX}-${NETWORK_DEPLOYMENT}" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" deployment-manager deployments create "${OCP_PREFIX}-${NETWORK_DEPLOYMENT}" --config "${DIR}/deployment-manager/deployment-net-config.yml"
else
    echo "Deployment '${OCP_PREFIX}-${NETWORK_DEPLOYMENT}' already exists"
fi

# Create the gold image based on the uploaded image
if ! gcloud --project "$GCLOUD_PROJECT" compute images describe "$GOLD_IMAGE" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute instances create "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --machine-type "n1-standard-1" --network "${OCP_PREFIX}-${OCP_NETWORK}" --image "$RHEL_IMAGE_GCE" --boot-disk-size "10" --no-boot-disk-auto-delete --boot-disk-type "pd-ssd" --tags "${OCP_PREFIX}-ssh-external"
    until gcloud -q --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --command "echo" &>/dev/null; do
        echo "Waiting for '${OCP_PREFIX}-${TEMP_INSTANCE}' to come up..."
        sleep 5
    done
    if ! gcloud -q --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "sudo bash -euc '
        if ! subscription-manager identity &>/dev/null; then
            subscription-manager register --username=${RH_USERNAME} --password=\"${RH_PASSWORD}\";
        fi
        for i in {0..5}; do
            if subscription-manager list --consumed | grep -q ${RH_POOL_ID}; then
                break;
            fi
            sleep 10;
            subscription-manager attach --pool=${RH_POOL_ID} || true;
        done
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
        yum remove -y irqbalance
        yum install -y google-compute-engine google-compute-engine-init google-config wget git net-tools bind-utils iptables-services bridge-utils bash-completion python-httplib2 docker;
        yum update -y;
        yum clean all;
        subscription-manager unregister;
'"; then
        gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
        gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
        echoerr "Deployment failed, please check provided Red Hat Username, Password and Pool ID and rerun the script"
        exit 1
    fi
    gcloud --project "$GCLOUD_PROJECT" compute instances stop "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
    gcloud -q --project "$GCLOUD_PROJECT" compute instances delete "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
    gcloud --project "$GCLOUD_PROJECT" compute images create "$GOLD_IMAGE" --source-disk "${OCP_PREFIX}-${TEMP_INSTANCE}" --source-disk-zone "$GCLOUD_ZONE"
    gcloud -q --project "$GCLOUD_PROJECT" compute disks delete "${OCP_PREFIX}-${TEMP_INSTANCE}" --zone "$GCLOUD_ZONE"
else
    echo "Image '${GOLD_IMAGE}' already exists"
fi

# Master Certificate
if ! gcloud --project "$GCLOUD_PROJECT" compute ssl-certificates describe "${OCP_PREFIX}-${MASTER_SSL_LB_CERT}" &>/dev/null; then
    if [ -z "${MASTER_HTTPS_KEY_FILE:-}" ] || [ -z "${MASTER_HTTPS_CERT_FILE:-}" ]; then
        KEY='/tmp/ocp-ssl.key'
        CERT='/tmp/ocp-ssl.crt'
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -subj "/C=US/L=Raleigh/O=${DNS_DOMAIN}/CN=${MASTER_DNS_NAME}" -keyout "$KEY" -out "$CERT"
    else
        KEY="$MASTER_HTTPS_KEY_FILE"
        CERT="$MASTER_HTTPS_CERT_FILE"
    fi
    gcloud --project "$GCLOUD_PROJECT" compute ssl-certificates create "${OCP_PREFIX}-${MASTER_SSL_LB_CERT}" --private-key "$KEY" --certificate "$CERT"
    if [ -z "${MASTER_HTTPS_KEY_FILE:-}" ] || [ -z "${MASTER_HTTPS_CERT_FILE:-}" ]; then
        rm -fv "$KEY" "$CERT"
    fi
else
    echo "Certificate '${OCP_PREFIX}-${MASTER_SSL_LB_CERT}' already exists"
fi

# Deploy core infrastructure
export OCP_PREFIX \
    GCLOUD_PROJECT \
    GCLOUD_REGION \
    GCLOUD_ZONE \
    GOLD_IMAGE \
    CONSOLE_PORT \
    BASTION_MACHINE_TYPE \
    BASTION_DISK_SIZE \
    MASTER_MACHINE_TYPE \
    MASTER_BOOT_DISK_SIZE \
    NODE_MACHINE_TYPE \
    NODE_BOOT_DISK_SIZE \
    MASTER_INSTANCE_GROUP_SIZE \
    INFRA_NODE_INSTANCE_GROUP_SIZE \
    NODE_INSTANCE_GROUP_SIZE
envsubst < "${DIR}/deployment-manager/deployment-core-config.yml.tpl" > "${DIR}/deployment-manager/deployment-core-config.yml"
if ! gcloud --project "$GCLOUD_PROJECT" deployment-manager deployments describe "${OCP_PREFIX}-${CORE_DEPLOYMENT}" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" deployment-manager deployments create "${OCP_PREFIX}-${CORE_DEPLOYMENT}" --config "${DIR}/deployment-manager/deployment-core-config.yml"
else
    echo "Deployment '${OCP_PREFIX}-${CORE_DEPLOYMENT}' already exists"
fi

# Allow bastion to connect via SSH to other instances via external IP
bastion_ext_ip=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="name=${OCP_PREFIX}-bastion" --format='value(EXTERNAL_IP)')
if ! gcloud --project "$GCLOUD_PROJECT" compute firewall-rules describe "${OCP_PREFIX}-${BASTION_SSH_FW_RULE}" &>/dev/null; then
    gcloud --project "$GCLOUD_PROJECT" compute firewall-rules create "${OCP_PREFIX}-${BASTION_SSH_FW_RULE}" --network "${OCP_PREFIX}-${OCP_NETWORK}" --allow tcp:22 --source-ranges "$bastion_ext_ip"
else
    echo "Firewall rule '${OCP_PREFIX}-${BASTION_SSH_FW_RULE}' already exists"
fi

# Attach additional disks to node instances for docker and openshift storage
instances=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="tags.items=${OCP_PREFIX}-node OR tags.items=${OCP_PREFIX}-infra-node" --format='value(name)')
for i in $instances; do
    docker_disk="${i}-docker"
    openshift_disk="${i}-openshift"
    instance_zone=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="name=${i}" --format='value(zone)')
    if ! gcloud --project "$GCLOUD_PROJECT" compute disks describe "$docker_disk" --zone "$instance_zone" &>/dev/null; then
        gcloud --project "$GCLOUD_PROJECT" compute disks create "$docker_disk" --zone "$instance_zone" --size "$NODE_DOCKER_DISK_SIZE" --type "pd-ssd"
        gcloud --project "$GCLOUD_PROJECT" compute instances attach-disk "${i}" --disk "$docker_disk" --zone "$instance_zone"
        gcloud --project "$GCLOUD_PROJECT" compute instances set-disk-auto-delete "${i}" --disk "$docker_disk" --auto-delete
    else
        echo "Disk '${docker_disk}' already exists"
    fi
    if ! gcloud --project "$GCLOUD_PROJECT" compute disks describe "$openshift_disk" --zone "$instance_zone" &>/dev/null; then
        gcloud --project "$GCLOUD_PROJECT" compute disks create "$openshift_disk" --zone "$instance_zone" --size "$NODE_OPENSHIFT_DISK_SIZE" --type "pd-ssd"
        gcloud --project "$GCLOUD_PROJECT" compute instances attach-disk "${i}" --disk "$openshift_disk" --zone "$instance_zone"
        gcloud --project "$GCLOUD_PROJECT" compute instances set-disk-auto-delete "${i}" --disk "$openshift_disk" --auto-delete
    else
        echo "Disk '${openshift_disk}' already exists"
    fi
done

# DNS record for master lb
if ! gcloud --project "$GCLOUD_PROJECT" dns record-sets list -z "$DNS_MANAGED_ZONE" --name "$MASTER_DNS_NAME" 2>/dev/null | grep -q "$MASTER_DNS_NAME"; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "${OCP_PREFIX}-master-ssl-lb-ip" --global --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction start -z "$DNS_MANAGED_ZONE"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction add -z "$DNS_MANAGED_ZONE" --ttl 3600 --name "${MASTER_DNS_NAME}." --type A "$IP"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction execute -z "$DNS_MANAGED_ZONE"
else
    echo "DNS record for '${MASTER_DNS_NAME}' already exists"
fi

# DNS record for internal master lb
if ! gcloud --project "$GCLOUD_PROJECT" dns record-sets list -z "$DNS_MANAGED_ZONE" --name "$INTERNAL_MASTER_DNS_NAME" 2>/dev/null | grep -q "$INTERNAL_MASTER_DNS_NAME"; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "${OCP_PREFIX}-master-network-lb-ip" --region "$GCLOUD_REGION" --format='value(address)')
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction start -z "$DNS_MANAGED_ZONE"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction add -z "$DNS_MANAGED_ZONE" --ttl 3600 --name "${INTERNAL_MASTER_DNS_NAME}." --type A "$IP"
    gcloud --project "$GCLOUD_PROJECT" dns record-sets transaction execute -z "$DNS_MANAGED_ZONE"
else
    echo "DNS record for '${INTERNAL_MASTER_DNS_NAME}' already exists"
fi

# DNS record for router lb
if ! gcloud --project "$GCLOUD_PROJECT" dns record-sets list -z "$DNS_MANAGED_ZONE" --name "$OCP_APPS_DNS_NAME" 2>/dev/null | grep -q "$OCP_APPS_DNS_NAME"; then
    IP=$(gcloud --project "$GCLOUD_PROJECT" compute addresses describe "${OCP_PREFIX}-router-network-lb-ip" --region "$GCLOUD_REGION" --format='value(address)')
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
touch "$SSH_CONFIG_FILE"
chmod 600 "$SSH_CONFIG_FILE"
sed -i '/^# OpenShift on GCP Section$/,/^# End of OpenShift on GCP Section$/d' "$SSH_CONFIG_FILE"
echo -e '# OpenShift on GCP Section\n' >> "$SSH_CONFIG_FILE"
bastion_data=$(gcloud --project "$GCLOUD_PROJECT" compute instances list --filter="name=${OCP_PREFIX}-bastion" --format='value(EXTERNAL_IP,id)')
echo "Host ${OCP_PREFIX}-bastion
    HostName $(echo ${bastion_data} | cut -d ' ' -f 1)
    User cloud-user
    IdentityFile ~/.ssh/google_compute_engine
    UserKnownHostsFile ~/.ssh/google_compute_known_hosts
    HostKeyAlias compute.$(echo ${bastion_data} | cut -d ' ' -f 2)
    IdentitiesOnly yes
    CheckHostIP no
" >> "$SSH_CONFIG_FILE"
instances=$(gcloud --project "${GCLOUD_PROJECT}" compute instances list --filter="tags.items=${OCP_PREFIX}" --format='value(name)')
for i in $instances; do
    echo "Host ${i}
    User cloud-user
    IdentityFile ~/.ssh/google_compute_engine
    proxycommand ssh ${OCP_PREFIX}-bastion -W %h:%p
" >> "$SSH_CONFIG_FILE"
done
echo -e '# End of OpenShift on GCP Section\n' >> "$SSH_CONFIG_FILE"

# Prepare config file for ansible based on the configuration from this script
export DNS_DOMAIN \
    OCP_APPS_DNS_NAME \
    OPENSHIFT_SDN \
    OCP_PREFIX \
    MASTER_DNS_NAME \
    INTERNAL_MASTER_DNS_NAME \
    CONSOLE_PORT \
    INFRA_NODE_INSTANCE_GROUP_SIZE \
    REGISTRY_BUCKET \
    GCLOUD_PROJECT \
    OCP_NETWORK \
    OCP_IDENTITY_PROVIDERS
envsubst < "${DIR}/ansible-config.yml.tpl" > "${DIR}/ansible-config.yml"
gcloud --project "$GCLOUD_PROJECT" compute copy-files "${DIR}/ansible-config.yml" "cloud-user@${OCP_PREFIX}-bastion:" --zone "$GCLOUD_ZONE"

# Prepare bastion instance for openshift installation
gcloud --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${OCP_PREFIX}-bastion" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "sudo bash -euc '
    if ! subscription-manager identity &>/dev/null; then
        subscription-manager register --username=${RH_USERNAME} --password=\"${RH_PASSWORD}\";
    fi
    for i in {0..5}; do
        if subscription-manager list --consumed | grep -q ${RH_POOL_ID}; then
            break;
        fi
        sleep 10;
        subscription-manager attach --pool=${RH_POOL_ID} || true;
    done
    subscription-manager repos --disable=\"*\";
    subscription-manager repos \
        --enable=\"rhel-7-server-rpms\" \
        --enable=\"rhel-7-server-extras-rpms\" \
        --enable=\"rhel-7-server-ose-${OCP_VERSION}-rpms\";

    yum install -y python-libcloud atomic-openshift-utils;

    if ! grep -q \"export GCE_PROJECT=${GCLOUD_PROJECT}\" /etc/profile.d/ocp.sh 2>/dev/null; then
        echo \"export GCE_PROJECT=${GCLOUD_PROJECT}\" >> /etc/profile.d/ocp.sh;
    fi
    if ! grep -q \"export INVENTORY_IP_TYPE=internal\" /etc/profile.d/ocp.sh 2>/dev/null; then
        echo \"export INVENTORY_IP_TYPE=internal\" >> /etc/profile.d/ocp.sh;
    fi
'"
gcloud --project "$GCLOUD_PROJECT" compute ssh "cloud-user@${OCP_PREFIX}-bastion" --zone "$GCLOUD_ZONE" --ssh-flag="-t" --command "bash -euc '
    if [ ! -d ~/google-cloud-sdk ]; then
        curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-x86_64.tar.gz | tar -xz;
        ~/google-cloud-sdk/bin/gcloud -q components update;
        ~/google-cloud-sdk/install.sh -q --usage-reporting false;
    fi

    if [ ! -f ~/.ssh/google_compute_engine ]; then
        ssh-keygen -t rsa -f ~/.ssh/google_compute_engine -C cloud-user -N \"\";
    fi

    # This command will upload our public SSH key to the GCE project metadata
    ~/google-cloud-sdk/bin/gcloud compute ssh cloud-user@${OCP_PREFIX}-bastion --zone ${GCLOUD_ZONE} --command echo;

    if [ ! -d ~/openshift-ansible-contrib ]; then
        git clone https://github.com/openshift/openshift-ansible-contrib.git ~/openshift-ansible-contrib;
    fi
    pushd ~/openshift-ansible-contrib/reference-architecture/gce-ansible;
    ansible-playbook -e rhsm_user=${RH_USERNAME} -e rhsm_password="${RH_PASSWORD}" -e rhsm_pool=${RH_POOL_ID} -e @~/ansible-config.yml playbooks/openshift-install.yaml;
'"

echo
echo "Deployment is complete. OpenShift Console can be found at https://${MASTER_DNS_NAME}"
echo

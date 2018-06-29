#!/bin/bash

set -eo pipefail

warnuser(){
  cat << EOF
###########
# WARNING #
###########
This script is distributed WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND
Refer to the official documentation
https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_google_cloud_platform/

EOF
}

die(){
  echo "$1"
  exit $2
}

usage(){
  warnuser
  echo "$0 <vars_file>"
  echo "  vars_file  The file containing all the required variables"
  echo "Examples:"
  echo "    $0 myvars"
}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]
then
  usage
  die "vars_file not provided" 2
fi

warnuser

VARSFILE=${1}

if [[ ! -f ${VARSFILE} ]]
then
  usage
  die "vars_file not found" 2
fi

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    die "User cancel" 4
fi

source ${VARSFILE}

if [ -z $RHUSER ]; then
  sudo subscription-manager register --activationkey=${AK} --org=${ORGID}
else
  sudo subscription-manager register --user=${RHUSER} --password=${RHPASS}
fi

sudo subscription-manager attach --pool=${POOLID}
sudo subscription-manager repos --disable="*" \
  --enable="rhel-7-server-rpms" \
  --enable="rhel-7-server-extras-rpms" \
  --enable="rhel-7-server-ose-${OCPVER}-rpms" \
  --enable="rhel-7-fast-datapath-rpms" \
  --enable="rhel-7-server-ansible-2.4-rpms"

sudo yum install atomic-openshift-utils tmux -y

sudo yum update -y

cat <<'EOF' > ./ansible.cfg
[defaults]
forks = 20
host_key_checking = False
remote_user = MYUSER
roles_path = roles/
gathering = smart
fact_caching = jsonfile
fact_caching_connection = $HOME/ansible/facts
fact_caching_timeout = 600
log_path = $HOME/ansible.log
nocows = 1
callback_whitelist = profile_tasks

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=600s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=false -o ForwardAgent=yes
control_path = %(directory)s/%%h-%%r
pipelining = True
timeout = 10

[persistent_connection]
connect_timeout = 30
connect_retries = 30
connect_interval = 1
EOF

sed -i -e "s/MYUSER/${MYUSER}/g" ./ansible.cfg

cat <<'EOF' > ./inventory
[OSEv3:children]
masters
etcd
nodes
glusterfs

[OSEv3:vars]
ansible_become=true
openshift_release=vOCPVER
os_firewall_use_firewalld=True
openshift_clock_enabled=true

openshift_cloudprovider_kind=gce
openshift_gcp_project=PROJECTID
openshift_gcp_prefix=CLUSTERID
# If deploying single zone cluster set to "False"
openshift_gcp_multizone="True"
openshift_gcp_network_name=CLUSTERID-net

openshift_master_api_port=443
openshift_master_console_port=443

openshift_node_local_quota_per_fsgroup=512Mi

openshift_hosted_registry_replicas=1
openshift_hosted_registry_storage_kind=object
openshift_hosted_registry_storage_provider=gcs
openshift_hosted_registry_storage_gcs_bucket=CLUSTERID-registry

openshift_master_cluster_method=native
openshift_master_cluster_hostname=CLUSTERID-ocp.DOMAIN
openshift_master_cluster_public_hostname=CLUSTERID-ocp.DOMAIN
openshift_master_default_subdomain=CLUSTERID-apps.DOMAIN

os_sdn_network_plugin_name=redhat/openshift-ovs-networkpolicy

deployment_type=openshift-enterprise

# Required per https://access.redhat.com/solutions/3480921
oreg_url=registry.access.redhat.com/openshift3/ose-${component}:${version}
openshift_examples_modify_imagestreams=true
openshift_storage_glusterfs_image=registry.access.redhat.com/rhgs3/rhgs-server-rhel7
openshift_storage_glusterfs_block_image=registry.access.redhat.com/rhgs3/rhgs-gluster-block-prov-rhel7
openshift_storage_glusterfs_s3_image=registry.access.redhat.com/rhgs3/rhgs-s3-server-rhel7
openshift_storage_glusterfs_heketi_image=registry.access.redhat.com/rhgs3/rhgs-volmanager-rhel7

# Service catalog
openshift_hosted_etcd_storage_kind=dynamic
openshift_hosted_etcd_storage_volume_name=etcd-vol
openshift_hosted_etcd_storage_access_modes=["ReadWriteOnce"]
openshift_hosted_etcd_storage_volume_size=SC_STORAGE
openshift_hosted_etcd_storage_labels={'storage': 'etcd'}

# Metrics
openshift_metrics_install_metrics=true
openshift_metrics_cassandra_storage_type=dynamic
openshift_metrics_storage_volume_size=METRICS_STORAGE
openshift_metrics_cassandra_nodeselector={"region":"infra"}
openshift_metrics_hawkular_nodeselector={"region":"infra"}
openshift_metrics_heapster_nodeselector={"region":"infra"}

# Aggregated logging
openshift_logging_install_logging=true
openshift_logging_es_pvc_dynamic=true
openshift_logging_es_pvc_size=LOGGING_STORAGE
openshift_logging_es_cluster_size=3
openshift_logging_es_nodeselector={"region":"infra"}
openshift_logging_kibana_nodeselector={"region":"infra"}
openshift_logging_curator_nodeselector={"region":"infra"}
openshift_logging_es_number_of_replicas=1

openshift_master_identity_providers=[{'name': 'htpasswd_auth','login': 'true','challenge': 'true','kind': 'HTPasswdPasswordIdentityProvider','filename': '/etc/origin/master/htpasswd'}]
openshift_master_htpasswd_users={'admin': 'HTPASSWD'}

openshift_hosted_prometheus_deploy=true
openshift_prometheus_node_selector={"region":"infra"}
openshift_prometheus_storage_type=pvc

[masters]
CLUSTERID-master-0
CLUSTERID-master-1
CLUSTERID-master-2

[etcd]
CLUSTERID-master-0
CLUSTERID-master-1
CLUSTERID-master-2

[nodes]
CLUSTERID-master-0 openshift_node_labels="{'region': 'master'}"
CLUSTERID-master-1 openshift_node_labels="{'region': 'master'}"
CLUSTERID-master-2 openshift_node_labels="{'region': 'master'}"
CLUSTERID-infra-0 openshift_node_labels="{'region': 'infra', 'node-role.kubernetes.io/infra': 'true'}"
CLUSTERID-infra-1 openshift_node_labels="{'region': 'infra', 'node-role.kubernetes.io/infra': 'true'}"
CLUSTERID-infra-2 openshift_node_labels="{'region': 'infra', 'node-role.kubernetes.io/infra': 'true'}"
CLUSTERID-app-0 openshift_node_labels="{'region': 'apps'}"
CLUSTERID-app-1 openshift_node_labels="{'region': 'apps'}"
CLUSTERID-app-2 openshift_node_labels="{'region': 'apps'}"
CLUSTERID-cns-0 openshift_node_labels="{'region': 'cns', 'node-role.kubernetes.io/cns': 'true'}"
CLUSTERID-cns-1 openshift_node_labels="{'region': 'cns', 'node-role.kubernetes.io/cns': 'true'}"
CLUSTERID-cns-2 openshift_node_labels="{'region': 'cns', 'node-role.kubernetes.io/cns': 'true'}"

[glusterfs]
CLUSTERID-cns-0 glusterfs_devices='[ "/dev/disk/by-id/google-CLUSTERID-cns-0-gluster" ]' openshift_node_local_quota_per_fsgroup=""
CLUSTERID-cns-1 glusterfs_devices='[ "/dev/disk/by-id/google-CLUSTERID-cns-1-gluster" ]' openshift_node_local_quota_per_fsgroup=""
CLUSTERID-cns-2 glusterfs_devices='[ "/dev/disk/by-id/google-CLUSTERID-cns-2-gluster" ]' openshift_node_local_quota_per_fsgroup=""
EOF

sed -i -e "s/MYUSER/${MYUSER}/g" \
       -e "s/OCPVER/${OCPVER}/g" \
       -e "s/CLUSTERID/${CLUSTERID}/g" \
       -e "s/PROJECTID/${PROJECTID}/g" \
       -e "s/DOMAIN/${DOMAIN}/g" \
       -e "s/HTPASSWD/${HTPASSWD}/g" \
       -e "s/LOGGING_STORAGE/${LOGGING_STORAGE}/g" \
       -e "s/METRICS_STORAGE/${METRICS_STORAGE}/g" \
       -e "s/SC_STORAGE/${SC_STORAGE}/g" \
       ./inventory

if [ -z $RHUSER ]; then
  ansible nodes -i inventory -b -m redhat_subscription -a \
    "state=present activationkey=${AK} org_id=${ORGID} pool_ids=${POOLID}"
else
  ansible nodes -i inventory -b -m redhat_subscription -a \
    "state=present user=${RHUSER} password=${RHPASS} pool_ids=${POOLID}"
fi

ansible nodes -i inventory -b -m shell -a \
  "subscription-manager repos --disable=\* \
    --enable=rhel-7-server-rpms \
    --enable=rhel-7-server-extras-rpms \
    --enable=rhel-7-server-ose-${OCPVER}-rpms \
    --enable=rhel-7-fast-datapath-rpms \
    --enable=rhel-7-server-ansible-2.4-rpms"

ansible *-infra-* -i inventory -b -m firewalld -a \
  "port=1936/tcp permanent=true state=enabled"

ansible nodes -i inventory -b -m firewalld -a \
  "port=10256/tcp permanent=true state=enabled"

ansible all -i inventory -b -m yum -a "name=* state=latest"
ansible all -i inventory -b -m command -a "reboot"

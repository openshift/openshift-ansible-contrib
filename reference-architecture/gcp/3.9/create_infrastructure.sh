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

for i in gcloud gsutil
do
  command -v $i >/dev/null 2>&1 || die "$i required but not found" 3
done

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

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

source ${VARSFILE}

# Config
gcloud config set project ${PROJECTID}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${DEFAULTZONE}

# Network
gcloud compute networks create ${CLUSTERID_NETWORK} --subnet-mode custom

# Subnet
gcloud compute networks subnets create ${CLUSTERID_SUBNET} \
  --network ${CLUSTERID_NETWORK} \
  --range ${CLUSTERID_SUBNET_CIDR}

# External to bastion
gcloud compute firewall-rules create ${CLUSTERID}-external-to-bastion \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:22,icmp \
  --source-ranges=0.0.0.0/0 --target-tags=${CLUSTERID}-bastion
# Bastion to all hosts
gcloud compute firewall-rules create ${CLUSTERID}-bastion-to-any \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=all \
  --source-tags=${CLUSTERID}-bastion --target-tags=${CLUSTERID}-node

# Nodes to master
gcloud compute firewall-rules create ${CLUSTERID}-node-to-master \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=udp:8053,tcp:8053 \
  --source-tags=${CLUSTERID}-node --target-tags=${CLUSTERID}-master

# Master to node
gcloud compute firewall-rules create ${CLUSTERID}-master-to-node \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:10250 \
  --source-tags=${CLUSTERID}-master --target-tags=${CLUSTERID}-node

# Master to master
gcloud compute firewall-rules create ${CLUSTERID}-master-to-master \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:2379,tcp:2380 \
  --source-tags=${CLUSTERID}-master --target-tags=${CLUSTERID}-master

# Any to master
gcloud compute firewall-rules create ${CLUSTERID}-any-to-masters \
  --direction=INGRESS --priority=1000  --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:443 \
  --source-ranges=${CLUSTERID_SUBNET_CIDR} --target-tags=${CLUSTERID}-master

# Infra node to infra node
gcloud compute firewall-rules create ${CLUSTERID}-infra-to-infra \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:9200,tcp:9300 \
  --source-tags=${CLUSTERID}-infra --target-tags=${CLUSTERID}-infra

# Routers
gcloud compute firewall-rules create ${CLUSTERID}-any-to-routers \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --source-ranges 0.0.0.0/0 \
  --target-tags ${CLUSTERID}-infra \
  --allow tcp:443,tcp:80

# Node to node SDN
gcloud compute firewall-rules create ${CLUSTERID}-node-to-node \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=udp:4789 \
  --source-tags=${CLUSTERID}-node --target-tags=${CLUSTERID}-node

# Infra to node kubelet
gcloud compute firewall-rules create ${CLUSTERID}-infra-to-node \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:10250 \
  --source-tags=${CLUSTERID}-infra --target-tags=${CLUSTERID}-node

# CNS to CNS node
gcloud compute firewall-rules create ${CLUSTERID}-cns-to-cns \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:2222 \
  --source-tags=${CLUSTERID}-cns --target-tags=${CLUSTERID}-cns

# Node to CNS node (client)
gcloud compute firewall-rules create ${CLUSTERID}-node-to-cns \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW \
  --rules=tcp:111,udp:111,tcp:3260,tcp:24007-24010,tcp:49152-49664 \
  --source-tags=${CLUSTERID}-node --target-tags=${CLUSTERID}-cns

# Masters load balancer
gcloud compute addresses create ${CLUSTERID}-master-lb \
    --ip-version=IPV4 \
    --global

# Applications load balancer
gcloud compute addresses create ${CLUSTERID}-apps-lb \
    --region ${REGION}

# Bastion host
gcloud compute addresses create ${CLUSTERID}-bastion \
  --region ${REGION}

# Masters load balancer entry
export LBIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-master-lb" --format="value(address)")

gcloud dns record-sets transaction start --zone=${DNSZONE}

gcloud dns record-sets transaction add \
  ${LBIP} --name=${CLUSTERID}-ocp.${DOMAIN} --ttl=${TTL} --type=A \
  --zone=${DNSZONE}
gcloud dns record-sets transaction execute --zone=${DNSZONE}

# Applications load balancer entry
export APPSLBIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-apps-lb" --format="value(address)")

gcloud dns record-sets transaction start --zone=${DNSZONE}

gcloud dns record-sets transaction add \
  ${APPSLBIP} --name=\*.${CLUSTERID}-apps.${DOMAIN} --ttl=${TTL} --type=A \
  --zone=${DNSZONE}

gcloud dns record-sets transaction execute --zone=${DNSZONE}

# Bastion host
export BASTIONIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-bastion" --format="value(address)")

gcloud dns record-sets transaction start --zone=${DNSZONE}

gcloud dns record-sets transaction add \
  ${BASTIONIP} --name=${CLUSTERID}-bastion.${DOMAIN} --ttl=${TTL} --type=A \
  --zone=${DNSZONE}

gcloud dns record-sets transaction execute --zone=${DNSZONE}

export BASTIONIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-bastion" --format="value(address)")

gcloud compute instances create ${CLUSTERID}-bastion \
  --machine-type=${BASTIONSIZE} \
  --subnet=${CLUSTERID_SUBNET} \
  --address=${BASTIONIP} \
  --maintenance-policy=MIGRATE \
  --scopes=https://www.googleapis.com/auth/cloud.useraccounts.readonly,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_write,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol \
  --tags=${CLUSTERID}-bastion \
  --metadata "ocp-cluster=${CLUSTERID},${CLUSTERID}-type=bastion" \
  --image=${RHELIMAGE} --image-project=${IMAGEPROJECT} \
  --boot-disk-size=${BASTIONDISKSIZE} --boot-disk-type=pd-ssd \
  --boot-disk-device-name=${CLUSTERID}-bastion \
  --zone=${DEFAULTZONE}

cat <<'EOF' > ./master.sh
#!/bin/bash
LOCALVOLDEVICE=$(readlink -f /dev/disk/by-id/google-*local*)
ETCDDEVICE=$(readlink -f /dev/disk/by-id/google-*etcd*)
CONTAINERSDEVICE=$(readlink -f /dev/disk/by-id/google-*containers*)
LOCALDIR="/var/lib/origin/openshift.local.volumes"
ETCDDIR="/var/lib/etcd"
CONTAINERSDIR="/var/lib/docker"

for device in ${LOCALVOLDEVICE} ${ETCDDEVICE} ${CONTAINERSDEVICE}
do
  mkfs.xfs ${device}
done

for dir in ${LOCALDIR} ${ETCDDIR} ${CONTAINERSDIR}
do
  mkdir -p ${dir}
  restorecon -R ${dir}
done

echo UUID=$(blkid -s UUID -o value ${LOCALVOLDEVICE}) ${LOCALDIR} xfs defaults,discard,gquota 0 2 >> /etc/fstab
echo UUID=$(blkid -s UUID -o value ${ETCDDEVICE}) ${ETCDDIR} xfs defaults,discard 0 2 >> /etc/fstab
echo UUID=$(blkid -s UUID -o value ${CONTAINERSDEVICE}) ${CONTAINERSDIR} xfs defaults,discard 0 2 >> /etc/fstab

mount -a
EOF

eval "$MYZONES_LIST"

for i in $(seq 0 $((${MASTER_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks create ${CLUSTERID}-master-${i}-etcd \
    --type=pd-ssd --size=${ETCDSIZE} --zone=${zone[$i]}
  gcloud compute disks create ${CLUSTERID}-master-${i}-containers \
    --type=pd-ssd --size=${MASTERCONTAINERSSIZE} --zone=${zone[$i]}
  gcloud compute disks create ${CLUSTERID}-master-${i}-local \
    --type=pd-ssd --size=${MASTERLOCALSIZE} --zone=${zone[$i]}
done

# Master instances multizone and single zone support
for i in $(seq 0 $((${MASTER_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances create ${CLUSTERID}-master-${i} \
     --machine-type=${MASTERSIZE} \
    --subnet=${CLUSTERID_SUBNET} \
    --address="" --no-public-ptr \
    --maintenance-policy=MIGRATE \
    --scopes=https://www.googleapis.com/auth/cloud.useraccounts.readonly,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol \
    --tags=${CLUSTERID}-master,${CLUSTERID}-node \
    --metadata "ocp-cluster=${CLUSTERID},${CLUSTERID}-type=master" \
    --image=${RHELIMAGE}  --image-project=${IMAGEPROJECT} \
    --boot-disk-size=${MASTERDISKSIZE} --boot-disk-type=pd-ssd \
    --boot-disk-device-name=${CLUSTERID}-master-${i} \
    --disk=name=${CLUSTERID}-master-${i}-etcd,device-name=${CLUSTERID}-master-${i}-etcd,mode=rw,boot=no \
    --disk=name=${CLUSTERID}-master-${i}-containers,device-name=${CLUSTERID}-master-${i}-containers,mode=rw,boot=no \
    --disk=name=${CLUSTERID}-master-${i}-local,device-name=${CLUSTERID}-master-${i}-local,mode=rw,boot=no \
    --metadata-from-file startup-script=./master.sh \
    --zone=${zone[$i]}
done

cat <<'EOF' > ./node.sh
#!/bin/bash
LOCALVOLDEVICE=$(readlink -f /dev/disk/by-id/google-*local*)
CONTAINERSDEVICE=$(readlink -f /dev/disk/by-id/google-*containers*)
LOCALDIR="/var/lib/origin/openshift.local.volumes"
CONTAINERSDIR="/var/lib/docker"

for device in ${LOCALVOLDEVICE} ${CONTAINERSDEVICE}
do
  mkfs.xfs ${device}
done

for dir in ${LOCALDIR} ${CONTAINERSDIR}
do
  mkdir -p ${dir}
  restorecon -R ${dir}
done

echo UUID=$(blkid -s UUID -o value ${LOCALVOLDEVICE}) ${LOCALDIR} xfs defaults,discard,gquota 0 2 >> /etc/fstab
echo UUID=$(blkid -s UUID -o value ${CONTAINERSDEVICE}) ${CONTAINERSDIR} xfs defaults,discard 0 2 >> /etc/fstab

mount -a
EOF

# Disks multizone and single zone support
eval "$MYZONES_LIST"

for i in $(seq 0 $(($INFRA_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks create ${CLUSTERID}-infra-${i}-containers \
  --type=pd-ssd --size=${INFRACONTAINERSSIZE} --zone=${zone[$i]}
  gcloud compute disks create ${CLUSTERID}-infra-${i}-local \
  --type=pd-ssd --size=${INFRALOCALSIZE} --zone=${zone[$i]}
done

# Infrastructure instances multizone and single zone support
for i in $(seq 0 $(($INFRA_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances create ${CLUSTERID}-infra-${i} \
     --machine-type=${INFRASIZE} \
    --subnet=${CLUSTERID_SUBNET} \
    --address="" --no-public-ptr \
    --maintenance-policy=MIGRATE \
    --scopes=https://www.googleapis.com/auth/cloud.useraccounts.readonly,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_write,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol \
    --tags=${CLUSTERID}-infra,${CLUSTERID}-node,${CLUSTERID}ocp \
    --metadata "ocp-cluster=${CLUSTERID},${CLUSTERID}-type=infra" \
    --image=${RHELIMAGE}  --image-project=${IMAGEPROJECT} \
    --boot-disk-size=${INFRADISKSIZE} --boot-disk-type=pd-ssd \
    --boot-disk-device-name=${CLUSTERID}-infra-${i} \
    --disk=name=${CLUSTERID}-infra-${i}-containers,device-name=${CLUSTERID}-infra-${i}-containers,mode=rw,boot=no \
    --disk=name=${CLUSTERID}-infra-${i}-local,device-name=${CLUSTERID}-infra-${i}-local,mode=rw,boot=no \
    --metadata-from-file startup-script=./node.sh \
    --zone=${zone[$i]}
done

# Disks multizone and single zone support
eval "$MYZONES_LIST"

for i in $(seq 0 $(($APP_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks create ${CLUSTERID}-app-${i}-containers \
  --type=pd-ssd --size=${APPCONTAINERSSIZE} --zone=${zone[$i]}
  gcloud compute disks create ${CLUSTERID}-app-${i}-local \
  --type=pd-ssd --size=${APPLOCALSIZE} --zone=${zone[$i]}
done

# Application instances multizone and single zone support
for i in $(seq 0 $(($APP_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances create ${CLUSTERID}-app-${i} \
     --machine-type=${APPSIZE} \
    --subnet=${CLUSTERID_SUBNET} \
    --address="" --no-public-ptr \
    --maintenance-policy=MIGRATE \
    --scopes=https://www.googleapis.com/auth/cloud.useraccounts.readonly,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol \
    --tags=${CLUSTERID}-node,${CLUSTERID}ocp \
    --metadata "ocp-cluster=${CLUSTERID},${CLUSTERID}-type=app" \
    --image=${RHELIMAGE}  --image-project=${IMAGEPROJECT} \
    --boot-disk-size=${INFRADISKSIZE} --boot-disk-type=pd-ssd \
    --boot-disk-device-name=${CLUSTERID}-app-${i} \
    --disk=name=${CLUSTERID}-app-${i}-containers,device-name=${CLUSTERID}-app-${i}-containers,mode=rw,boot=no \
    --disk=name=${CLUSTERID}-app-${i}-local,device-name=${CLUSTERID}-app-${i}-local,mode=rw,boot=no \
    --metadata-from-file startup-script=./node.sh \
    --zone=${zone[$i]}
done

# Health check
gcloud compute health-checks create https ${CLUSTERID}-master-lb-healthcheck \
  --port 443 --request-path "/healthz" --check-interval=10s --timeout=10s \
  --healthy-threshold=3 --unhealthy-threshold=3

# Create backend and set client ip affinity to avoid websocket timeout
gcloud compute backend-services create ${CLUSTERID}-master-lb-backend \
  --global \
  --protocol TCP \
  --session-affinity CLIENT_IP \
  --health-checks ${CLUSTERID}-master-lb-healthcheck \
  --port-name ocp-api

eval "$MYZONES_LIST"

# Multizone and single zone support for instance groups
for i in $(seq 0 $((${#ZONES[@]}-1))); do
  ZONE=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instance-groups unmanaged create ${CLUSTERID}-masters-${ZONE} \
    --zone=${ZONE}
  gcloud compute instance-groups unmanaged set-named-ports \
    ${CLUSTERID}-masters-${ZONE} --named-ports=ocp-api:443 --zone=${ZONE}
  gcloud compute instance-groups unmanaged add-instances \
    ${CLUSTERID}-masters-${ZONE} --instances=${CLUSTERID}-master-${i} \
    --zone=${ZONE}
  # Instances are added to the backend service
  gcloud compute backend-services add-backend ${CLUSTERID}-master-lb-backend \
    --global \
    --instance-group ${CLUSTERID}-masters-${ZONE} \
    --instance-group-zone ${ZONE}
done

# Do not set any proxy header to be transparent
gcloud compute target-tcp-proxies create ${CLUSTERID}-master-lb-target-proxy \
  --backend-service ${CLUSTERID}-master-lb-backend \
  --proxy-header NONE

export LBIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-master-lb" --format="value(address)")

# Forward only 443/tcp port
gcloud compute forwarding-rules create \
  ${CLUSTERID}-master-lb-forwarding-rule \
  --global \
  --target-tcp-proxy ${CLUSTERID}-master-lb-target-proxy \
  --address ${LBIP} \
  --ports 443

# Allow health checks from Google health check IPs
gcloud compute firewall-rules create ${CLUSTERID}-healthcheck-to-lb \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --source-ranges 130.211.0.0/22,35.191.0.0/16 \
  --target-tags ${CLUSTERID}-master \
  --allow tcp:443

# Health check
gcloud compute http-health-checks create ${CLUSTERID}-infra-lb-healthcheck \
  --port 1936 --request-path "/healthz" --check-interval=10s --timeout=10s \
  --healthy-threshold=3 --unhealthy-threshold=3

# Target Pool
gcloud compute target-pools create ${CLUSTERID}-infra \
    --http-health-check ${CLUSTERID}-infra-lb-healthcheck

for i in $(seq 0 $(($INFRA_NODE_COUNT-1))); do
  gcloud compute target-pools add-instances ${CLUSTERID}-infra \
  --instances=${CLUSTERID}-infra-${i}
done

# Forwarding rules and firewall rules
export APPSLBIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-apps-lb" --format="value(address)")

gcloud compute forwarding-rules create ${CLUSTERID}-infra-http \
  --ports 80 \
  --address ${APPSLBIP} \
  --region ${REGION} \
  --target-pool ${CLUSTERID}-infra

gcloud compute forwarding-rules create ${CLUSTERID}-infra-https \
  --ports 443 \
  --address ${APPSLBIP} \
  --region ${REGION} \
  --target-pool ${CLUSTERID}-infra

# Bucket to host registry
gsutil mb -l ${REGION} gs://${CLUSTERID}-registry

cat <<EOF > labels.json
{
  "ocp-cluster": "${CLUSTERID}"
}
EOF

gsutil label set labels.json gs://${CLUSTERID}-registry

rm -f labels.json

cat <<'EOF' > ./cns.sh
#!/bin/bash
CONTAINERSDEVICE=$(readlink -f /dev/disk/by-id/google-*containers*)
CONTAINERSDIR="/var/lib/docker"

mkfs.xfs ${CONTAINERSDEVICE}
mkdir -p ${CONTAINERSDIR}
restorecon -R ${CONTAINERSDIR}

echo UUID=$(blkid -s UUID -o value ${CONTAINERSDEVICE}) ${CONTAINERSDIR} xfs defaults,discard 0 2 >> /etc/fstab

mount -a
EOF

# Disks multizone and single zone support
eval "$MYZONES_LIST"

for i in $(seq 0 $(($CNS_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks create ${CLUSTERID}-cns-${i}-containers \
  --type=pd-ssd --size=${CNSCONTAINERSSIZE} --zone=${zone[$i]}
  gcloud compute disks create ${CLUSTERID}-cns-${i}-gluster \
  --type=pd-ssd --size=${CNSGLUSTERSIZE} --zone=${zone[$i]}
done

# CNS instances multizone and single zone support
for i in $(seq 0 $(($CNS_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances create ${CLUSTERID}-cns-${i} \
     --machine-type=${CNSSIZE} \
    --subnet=${CLUSTERID_SUBNET} \
    --address="" --no-public-ptr \
    --maintenance-policy=MIGRATE \
    --scopes=https://www.googleapis.com/auth/cloud.useraccounts.readonly,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_write,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol\
    --tags=${CLUSTERID}-cns,${CLUSTERID}-node,${CLUSTERID}ocp \
    --metadata "ocp-cluster=${CLUSTERID},${CLUSTERID}-type=cns" \
    --image=${RHELIMAGE} --image-project=${IMAGEPROJECT} \
    --boot-disk-size=${CNSDISKSIZE} --boot-disk-type=pd-ssd \
    --boot-disk-device-name=${CLUSTERID}-cns-${i} \
    --disk=name=${CLUSTERID}-cns-${i}-containers,device-name=${CLUSTERID}-cns-${i}-containers,mode=rw,boot=no \
    --disk=name=${CLUSTERID}-cns-${i}-gluster,device-name=${CLUSTERID}-cns-${i}-gluster,mode=rw,boot=no \
    --metadata-from-file startup-script=./cns.sh \
    --zone=${zone[$i]}
done

sleep 180

eval "$MYZONES_LIST"

# Masters
for i in $(seq 0 $((${MASTER_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances remove-metadata \
    --keys startup-script ${CLUSTERID}-master-${i} --zone=${zone[$i]}
done

# Application nodes
for i in $(seq 0 $(($APP_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances remove-metadata \
    --keys startup-script ${CLUSTERID}-app-${i} --zone=${zone[$i]}
done

# Infrastructure nodes
for i in $(seq 0 $(($INFRA_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances remove-metadata \
    --keys startup-script ${CLUSTERID}-infra-${i} --zone=${zone[$i]}
done

# CNS nodes
for i in $(seq 0 $(($CNS_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances remove-metadata \
    --keys startup-script ${CLUSTERID}-cns-${i} --zone=${zone[$i]}
done

gcloud compute firewall-rules create \
  ${CLUSTERID}-prometheus-infranode-to-node \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:9100,tcp:10250 \
  --source-tags=${CLUSTERID}-infra --target-tags=${CLUSTERID}-node

gcloud compute firewall-rules create \
  ${CLUSTERID}-prometheus-infranode-to-master \
  --direction=INGRESS --priority=1000 --network=${CLUSTERID_NETWORK} \
  --action=ALLOW --rules=tcp:8444 \
  --source-tags=${CLUSTERID}-infra --target-tags=${CLUSTERID}-master

echo "Finished provisioning infrastructure objects"

exit 0

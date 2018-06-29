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

read -p "Are you sure to delete all your OCP infrastructure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    die "User cancel" 4
fi

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

source ${VARSFILE}

eval "$MYZONES_LIST"
# Bucket
gsutil rb gs://${CLUSTERID}-registry
# Apps LB
gcloud compute firewall-rules delete ${CLUSTERID}-any-to-routers
gcloud compute forwarding-rules delete ${CLUSTERID}-infra-https --region ${REGION}
gcloud compute forwarding-rules delete ${CLUSTERID}-infra-http --region ${REGION}
gcloud compute target-pools delete ${CLUSTERID}-infra
gcloud compute http-health-checks delete ${CLUSTERID}-infra-lb-healthcheck
# Masters LB
gcloud compute firewall-rules delete ${CLUSTERID}-healthcheck-to-lb
gcloud compute forwarding-rules delete ${CLUSTERID}-master-lb-forwarding-rule \
    --global
gcloud compute target-tcp-proxies delete ${CLUSTERID}-master-lb-target-proxy
gcloud compute backend-services delete ${CLUSTERID}-master-lb-backend --global
for i in $(seq 0 $((${#ZONES[@]}-1))); do
  ZONE=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instance-groups unmanaged delete ${CLUSTERID}-masters-${ZONE} \
    --zone=${ZONE}
done
gcloud compute health-checks delete ${CLUSTERID}-master-lb-healthcheck
# App instances
for i in $(seq 0 $(($APP_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances delete ${CLUSTERID}-app-${i} --zone=${zone[$i]}
done
# App disk
for i in $(seq 0 $(($APP_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks delete ${CLUSTERID}-app-${i}-containers \
    --zone=${zone[$i]}
  gcloud compute disks delete ${CLUSTERID}-app-${i}-local \
    --zone=${zone[$i]}
done
# Infra instances
for i in $(seq 0 $(($INFRA_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances delete ${CLUSTERID}-infra-${i} --zone=${zone[$i]}
done
for i in $(seq 0 $(($INFRA_NODE_COUNT-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks delete ${CLUSTERID}-infra-${i}-containers \
    --zone=${zone[$i]}
  gcloud compute disks delete ${CLUSTERID}-infra-${i}-local \
    --zone=${zone[$i]}
done
# Masters
for i in $(seq 0 $((${MASTER_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances delete ${CLUSTERID}-master-${i} --zone=${zone[$i]}
done
for i in $(seq 0 $((${MASTER_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks delete ${CLUSTERID}-master-${i}-etcd \
    --zone=${zone[$i]}
  gcloud compute disks delete ${CLUSTERID}-master-${i}-containers \
    --zone=${zone[$i]}
  gcloud compute disks delete ${CLUSTERID}-master-${i}-local \
    --zone=${zone[$i]}
done
# CNS
for i in $(seq 0 $((${CNS_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute instances delete ${CLUSTERID}-cns-${i} --zone=${zone[$i]}
done
for i in $(seq 0 $((${CNS_NODE_COUNT}-1))); do
  zone[$i]=${ZONES[$i % ${#ZONES[@]}]}
  gcloud compute disks delete ${CLUSTERID}-cns-${i}-containers \
    --zone=${zone[$i]}
  gcloud compute disks delete ${CLUSTERID}-cns-${i}-gluster \
    --zone=${zone[$i]}
done
# BASTION
gcloud compute instances delete ${CLUSTERID}-bastion
# DNS records
export LBIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-master-lb" --format="value(address)")
gcloud dns record-sets transaction start --zone=${DNSZONE}
gcloud dns record-sets transaction remove \
  ${LBIP} --name=${CLUSTERID}-ocp.${DOMAIN} --ttl=${TTL} --type=A --zone=${DNSZONE}
gcloud dns record-sets transaction execute --zone=${DNSZONE}

export APPSLBIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-apps-lb" --format="value(address)")
gcloud dns record-sets transaction start --zone=${DNSZONE}
gcloud dns record-sets transaction remove \
  ${APPSLBIP} --name=\*.${CLUSTERID}-apps.${DOMAIN} --ttl=${TTL} --type=A --zone=${DNSZONE}
gcloud dns record-sets transaction execute --zone=${DNSZONE}

export BASTIONIP=$(gcloud compute addresses list \
  --filter="name:${CLUSTERID}-bastion" --format="value(address)")
gcloud dns record-sets transaction start --zone=${DNSZONE}
gcloud dns record-sets transaction remove \
  ${BASTIONIP} --name=${CLUSTERID}-bastion.${DOMAIN} --ttl=${TTL} --type=A --zone=${DNSZONE}
gcloud dns record-sets transaction execute --zone=${DNSZONE}

# External IPs
gcloud compute addresses delete ${CLUSTERID}-master-lb --global
gcloud compute addresses delete ${CLUSTERID}-apps-lb --region ${REGION}
gcloud compute addresses delete ${CLUSTERID}-bastion --region ${REGION}

gcloud compute firewall-rules delete ${CLUSTERID}-external-to-bastion
gcloud compute firewall-rules delete ${CLUSTERID}-node-to-node
gcloud compute firewall-rules delete ${CLUSTERID}-node-to-master
gcloud compute firewall-rules delete ${CLUSTERID}-any-to-masters
gcloud compute firewall-rules delete ${CLUSTERID}-master-to-node
gcloud compute firewall-rules delete ${CLUSTERID}-master-to-master
gcloud compute firewall-rules delete ${CLUSTERID}-bastion-to-any
gcloud compute firewall-rules delete ${CLUSTERID}-infra-to-infra
gcloud compute firewall-rules delete ${CLUSTERID}-infra-to-node
gcloud compute firewall-rules delete ${CLUSTERID}-cns-to-cns
gcloud compute firewall-rules delete ${CLUSTERID}-node-to-cns
gcloud compute firewall-rules delete ${CLUSTERID}-prometheus-infranode-to-node
gcloud compute firewall-rules delete ${CLUSTERID}-prometheus-infranode-to-master

gcloud compute networks subnets delete ${CLUSTERID_SUBNET}
gcloud compute networks delete ${CLUSTERID_NETWORK}

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

#export CLOUDSDK_CORE_DISABLE_PROMPTS=1

source ${VARSFILE}

# Start: Project, DNS and Service Account
gcloud projects create ${PROJECTID} --name ${PROJECTID} --labels=openshift=true

gcloud beta billing projects link ${PROJECTID} --billing-account=${ACCOUNTID}

gcloud config set project ${PROJECTID}

gcloud services enable dns.googleapis.com

gcloud dns managed-zones create ${DNSZONE} --description="Openshift DNS Zone" \
            --dns-name=${DNSNAME}

echo "Don't forget to redirect your DNS for" ${DNSNAME} "registrar to " 
gcloud dns managed-zones describe ${DNSZONE} --format="flattened(nameServers[])"

gcloud iam service-accounts create ${SANAME} --display-name ${SANAME}

gcloud iam service-accounts keys create ${HOME}/Downloads/gcp_keys.json --iam-account="${SANAME}@${PROJECTID}.iam.gserviceaccount.com" --key-file-type="json"

# Now the ssh
ssh-keygen -t rsa -N '' -f ${HOME}/.ssh/gcp_key

gcloud compute project-info add-metadata --metadata-from-file ssh-keys=${HOME}/.ssh/gcp_key.pub

# Change to the ServiceAccount to setup everything else
gcloud auth activate-service-account --key-file=${HOME}/Downloads/gcp_keys.json

echo "Listing Service Accounts"
gcloud auth list

gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${DEFAULTZONE}
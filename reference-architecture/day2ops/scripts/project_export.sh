#!/bin/bash
# OpenShift namespaced objects:
# oc get --raw /oapi/v1/ |  python -c 'import json,sys ; resources = "\n".join([o["name"] for o in json.load(sys.stdin)["resources"] if o["namespaced"] and "create" in o["verbs"] and "delete" in o["verbs"] ]) ; print resources'
# Kubernetes namespaced objects:
# oc get --raw /api/v1/ |  python -c 'import json,sys ; resources = "\n".join([o["name"] for o in json.load(sys.stdin)["resources"] if o["namespaced"] and "create" in o["verbs"] and "delete" in o["verbs"] ]) ; print resources'

set -eo pipefail

warnuser(){
  cat << EOF
###########
# WARNING #
###########
This script is distributed WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND
Beware ImageStreams objects are not importables due to the way they work
See https://github.com/openshift/openshift-ansible-contrib/issues/967
for more information
EOF
}

die(){
  echo "$1"
  exit $2
}

usage(){
  echo "$0 <projectname>"
  echo "  projectname  The OCP project to be exported"
  echo "Examples:"
  echo "    $0 myproject"
  warnuser
}

exportlist(){
  if [ "$#" -lt "3" ]; then
    echo "Invalid parameters"
    return
  fi

  KIND=$1
  BASENAME=$2
  DELETEPARAM=$3

  echo "Exporting '${KIND}' resources to ${PROJECT}/${BASENAME}.json"

  BUFFER=$(oc get ${KIND} --export -o json -n ${PROJECT} || true)

  # return if resource type unknown or access denied
  if [ -z "${BUFFER}" ]; then
    echo "Skipped: no data"
    return
  fi

  # return if list empty
  if [ "$(echo ${BUFFER} | jq '.items | length > 0')" == "false" ]; then
    echo "Skipped: list empty"
    return
  fi

  echo ${BUFFER} | jq ${DELETEPARAM} > ${PROJECT}/${BASENAME}.json
}

ns(){
  echo "Exporting namespace to ${PROJECT}/ns.json"
  oc get --export -o=json ns ${PROJECT} | jq '
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/ns.json
}

rolebindings(){
  exportlist \
    rolebindings \
    rolebindings \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp)'
}

serviceaccounts(){
  exportlist \
    serviceaccounts \
    serviceaccounts \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp)'
}

secrets(){
  exportlist \
    secrets \
    secrets \
    'del('\
'.items[]|select(.type=='\
'"'\
'kubernetes.io/service-account-token'\
'"'\
'))|'\
'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.annotations.'\
'"'\
'kubernetes.io/service-account.uid'\
'"'\
')'
}

dcs(){
  echo "Exporting deploymentconfigs to ${PROJECT}/dc_*.json"
  DCS=$(oc get dc -n ${PROJECT} -o jsonpath="{.items[*].metadata.name}")
  for dc in ${DCS}; do
    oc get --export -o=json dc ${dc} -n ${PROJECT} | jq '
      del(.status,
          .metadata.uid,
          .metadata.selfLink,
          .metadata.resourceVersion,
          .metadata.creationTimestamp,
          .metadata.generation,
          .spec.triggers[].imageChangeParams.lastTriggeredImage
          )' > ${PROJECT}/dc_${dc}.json
    if [ !$(cat ${PROJECT}/dc_${dc}.json | jq '.spec.triggers[].type' | grep -q "ImageChange") ]; then
      for container in $(cat ${PROJECT}/dc_${dc}.json | jq -r '.spec.triggers[] | select(.type == "ImageChange") .imageChangeParams.containerNames[]'); do
        echo "Patching DC..."
        OLD_IMAGE=$(cat ${PROJECT}/dc_${dc}.json | jq --arg cname ${container} -r '.spec.template.spec.containers[] | select(.name == $cname)| .image')
        NEW_IMAGE=$(cat ${PROJECT}/dc_${dc}.json | jq -r '.spec.triggers[] | select(.type == "ImageChange") .imageChangeParams.from.name // empty')
        sed -e "s#$OLD_IMAGE#$NEW_IMAGE#g" ${PROJECT}/dc_${dc}.json >> ${PROJECT}/dc_${dc}_patched.json
      done
    fi
  done
}

bcs(){
  exportlist \
    bc \
    bcs \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.generation,'\
'.items[].spec.triggers[].imageChangeParams.lastTriggeredImage)'
}

builds(){
  exportlist \
    builds \
    builds \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

is(){
  exportlist \
    is \
    iss \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation,'\
'.items[].metadata.annotations."openshift.io/image.dockerRepositoryCheck")'
}

rcs(){
  exportlist \
    rc \
    rcs \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

svcs(){
  echo "Exporting services to ${PROJECT}/svc_*.json"
  SVCS=$(oc get svc -n ${PROJECT} -o jsonpath="{.items[*].metadata.name}")
  for svc in ${SVCS}; do
    oc get --export -o=json svc ${svc} -n ${PROJECT} | jq '
      del(.status,
            .metadata.uid,
            .metadata.selfLink,
            .metadata.resourceVersion,
            .metadata.creationTimestamp,
            .metadata.generation,
            .spec.clusterIP
            )' > ${PROJECT}/svc_${svc}.json
    if [[ $(cat ${PROJECT}/svc_${svc}.json | jq -e '.spec.selector.app') == "null" ]]; then
      oc get --export -o json endpoints ${svc} -n ${PROJECT}| jq '
        del(.status,
            .metadata.uid,
            .metadata.selfLink,
            .metadata.resourceVersion,
            .metadata.creationTimestamp,
            .metadata.generation
            )' > ${PROJECT}/endpoint_${svc}.json
    fi
  done
}

pods(){
  exportlist \
    po \
    pods \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

cms(){
  exportlist \
    cm \
    cms \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

pvcs(){
  exportlist \
    pvc \
    pvcs \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation,'\
'.items[].metadata.annotations['\
'"'\
'pv.kubernetes.io/bind-completed'\
'"'\
'],'\
'.items[].metadata.annotations['\
'"'\
'pv.kubernetes.io/bound-by-controller'\
'"'\
'],'\
'.items[].metadata.annotations['\
'"'\
'volume.beta.kubernetes.io/storage-provisioner'\
'"'\
'],'\
'.items[].spec.volumeName)'
}

pvcs_attachment(){
  exportlist \
    pvc \
    pvcs_attachment \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

routes(){
  exportlist \
    routes \
    routes \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

templates(){
  exportlist \
    templates \
    templates \
    'del('\
'.items[].status,'\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation)'
}

egressnetworkpolicies(){
  exportlist \
    egressnetworkpolicies \
    egressnetworkpolicies \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp)'
}

imagestreamtags(){
  exportlist \
    imagestreamtags \
    imagestreamtags \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].tag.generation)'
}

rolebindingrestrictions(){
  exportlist \
    rolebindingrestrictions \
    rolebindingrestrictions \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp)'
}

limitranges(){
  exportlist \
    limitranges \
    limitranges \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp)'
}

resourcequotas(){
  exportlist \
    resourcequotas \
    resourcequotas \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].status)'
}

podpreset(){
  exportlist \
    podpreset \
    podpreset \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp)'
}

cronjobs(){
  exportlist \
    cronjobs \
    cronjobs \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].status)'
}

statefulsets(){
  exportlist \
    statefulsets \
    statefulsets \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].status)'
}

hpas(){
  exportlist \
    hpa \
    hpas \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].status)'
}

deployments(){
  exportlist \
    deploy \
    deployments \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation,'\
'.items[].status)'
}

replicasets(){
  exportlist \
    replicasets \
    replicasets \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation,'\
'.items[].status,'\
'.items[].ownerReferences.uid)'
}

poddisruptionbudget(){
  exportlist \
    poddisruptionbudget \
    poddisruptionbudget \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation,'\
'.items[].status)'
}

daemonset(){
  exportlist \
    daemonset \
    daemonset \
    'del('\
'.items[].metadata.uid,'\
'.items[].metadata.selfLink,'\
'.items[].metadata.resourceVersion,'\
'.items[].metadata.creationTimestamp,'\
'.items[].metadata.generation,'\
'.items[].status)'
}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]
then
  usage
  die "projectname not provided" 2
fi

for i in jq oc
do
  command -v $i >/dev/null 2>&1 || die "$i required but not found" 3
done

warnuser

PROJECT=${1}

mkdir -p ${PROJECT}

ns
rolebindings
serviceaccounts
secrets
dcs
bcs
builds
is
imagestreamtags
rcs
svcs
pods
podpreset
cms
egressnetworkpolicies
rolebindingrestrictions
limitranges
resourcequotas
pvcs
pvcs_attachment
routes
templates
cronjobs
statefulsets
hpas
deployments
replicasets
poddisruptionbudget
daemonset

exit 0

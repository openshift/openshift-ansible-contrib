#!/bin/bash
set -eo pipefail

die(){
  echo "$1"
  exit $2
}

usage(){
  echo "$0 <projectname>"
  echo "  projectname  The OCP project to be exported"
  echo "Examples:"
  echo "    $0 myproject"
}

ns(){
  echo "Exporting namespace to ${PROJECT}/ns.json"
  oc get --export -o=json ns/${PROJECT} | jq '
    del(.status,
      .metadata.uid,
      .metadata.selfLink,
      .metadata.resourceVersion,
      .metadata.creationTimestamp,
      .metadata.generation
      )' > ${PROJECT}/ns.json
}

rolebindings(){
  echo "Exporting rolebindings to ${PROJECT}/rolebindings.json"
  oc get --export -o=json rolebindings -n ${PROJECT} | jq '.items[] |
  del(.metadata.uid,
      .metadata.selfLink,
      .metadata.resourceVersion,
      .metadata.creationTimestamp
      )' > ${PROJECT}/rolebindings.json
}

serviceaccounts(){
  echo "Exporting serviceaccounts to ${PROJECT}/serviceaccounts.json"
  oc get --export -o=json serviceaccounts -n ${PROJECT} | jq '.items[] |
    del(.metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp
        )' > ${PROJECT}/serviceaccounts.json
}

secrets(){
  echo "Exporting secrets to ${PROJECT}/secrets.json"
  oc get --export -o=json secrets -n ${PROJECT} | jq '.items[] |
    select(.type!="kubernetes.io/service-account-token") |
    del(.metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.annotations."kubernetes.io/service-account.uid"
        )' > ${PROJECT}/secrets.json
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
  echo "Exporting buildconfigs to ${PROJECT}/bcs.json"
  oc get --export -o=json bc -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .spec.triggers[].imageChangeParams.lastTriggeredImage
        )' > ${PROJECT}/bcs.json
}

builds(){
  echo "Exporting builds to ${PROJECT}/builds.json"
  oc get --export -o=json builds -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/builds.json
}

is(){
  echo "Exporting imagestreams to ${PROJECT}/iss.json"
  oc get --export -o=json is -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .metadata.annotations."openshift.io/image.dockerRepositoryCheck"
        )' > ${PROJECT}/iss.json
}

rcs(){
  echo "Exporting replicationcontrollers to ${PROJECT}/rcs.json"
  oc get --export -o=json rc -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/rcs.json
}

svcs(){
  echo "Exporting services to ${PROJECT}/svcs.json"
  oc get --export -o=json svc -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .spec.clusterIP
        )' > ${PROJECT}/svcs.json
}

pods(){
  echo "Exporting pods to ${PROJECT}/pods.json"
  oc get --export -o=json pod -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/pods.json
}

cms(){
  echo "Exporting configmaps to ${PROJECT}/cms.json"
  oc get --export -o=json configmaps -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/cms.json
}

pvcs(){
  echo "Exporting pvcs to ${PROJECT}/pvcs.json"
  oc get --export -o=json pvc -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/pvcs.json
}

routes(){
  echo "Exporting routes to ${PROJECT}/routes.json"
  oc get --export -o=json routes -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/routes.json
}

templates(){
  echo "Exporting templates to ${PROJECT}/templates.json"
  oc get --export -o=json templates -n ${PROJECT} | jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
        )' > ${PROJECT}/templates.json
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

PROJECT=${1}

mkdir ${PROJECT}

ns
rolebindings
serviceaccounts
secrets
dcs
bcs
builds
is
rcs
svcs
pods
cms
pvcs
routes
templates

exit 0

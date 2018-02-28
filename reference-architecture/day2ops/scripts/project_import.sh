#!/bin/bash

die(){
  echo "$1"
  exit $2
}

usage(){
  echo "$0 <projectdirectory>"
  echo "  projectdirectory  The directory where the exported objects are hosted"
  echo "Examples:"
  echo "    $0 ~/backup/myproject"
}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]
then
  usage
  die "Missing project directory" 3
fi

for i in oc
do
  command -v $i >/dev/null 2>&1 || die "$i required but not found" 3
done

PROJECTPATH=$1
oc create -f ${PROJECTPATH}/ns.json
sleep 2
PROJECT=$(jq -r .metadata.name ${PROJECTPATH}/ns.json)
oc create -f ${PROJECTPATH}/limitranges.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/resourcequotas.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/rolebindings.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/rolebindingrestrictions.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/secrets.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/serviceaccounts.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/podpreset.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/poddisruptionbudget.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/templates.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/cms.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/egressnetworkpolicies.json -n ${PROJECT}
for svc in ${PROJECTPATH}/svc_*.json
do
  oc create -f ${svc} -n ${PROJECT}
done
for endpoint in ${PROJECTPATH}/endpoint_*.json
do
  oc create -f ${endpoint} -n ${PROJECT}
done
oc create -f ${PROJECTPATH}/iss.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/imagestreamtags.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/pvcs.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/cms.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/bcs.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/builds.json -n ${PROJECT}
for dc in ${PROJECTPATH}/dc_*.json
do
  dcfile=$(echo ${dc##*/})
  [[ ${dcfile} == dc_*_patched.json ]] && continue
  DCNAME=$(echo ${dcfile} | sed "s/dc_\(.*\)\.json$/\1/")
  if [ -s ${PROJECTPATH}/dc_${DCNAME}_patched.json ]
  then
    oc create -f ${PROJECTPATH}/dc_${DCNAME}_patched.json -n ${PROJECT}
  else
    oc create -f ${dc} -n ${PROJECT}
  fi
done
oc create -f ${PROJECTPATH}/rcs.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/deployments.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/replicasets.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/pods.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/routes.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/cronjobs.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/statefulsets.json -n ${PROJECT}
oc create -f ${PROJECTPATH}/hpas.json -n ${PROJECT}

exit 0

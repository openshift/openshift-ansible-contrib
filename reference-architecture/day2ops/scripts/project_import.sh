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

# First we create optional objects
for object in limitranges resourcequotas rolebindings rolebindingrestrictions secrets serviceaccounts podpreset poddisruptionbudget templates cms egressnetworkpolicies iss imagestreams pvcs routes hpas
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    oc create -f ${PROJECTPATH}/${object}.json -n ${PROJECT}
done

# Services & endpoints
for svc in ${PROJECTPATH}/svc_*.json
do
  oc create -f ${svc} -n ${PROJECT}
done
for endpoint in ${PROJECTPATH}/endpoint_*.json
do
  oc create -f ${endpoint} -n ${PROJECT}
done

# More objects, this time those can create apps
for object in bcs builds
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    oc create -f ${PROJECTPATH}/${object}.json -n ${PROJECT}
done

# Restore DCs
# If patched exists, restore it, otherwise, restore the plain one
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

for object in replicasets deployments rcs pods cronjobs statefulsets daemonset
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    oc create -f ${PROJECTPATH}/${object}.json -n ${PROJECT}
done

exit 0

#!/bin/bash

die(){
  echo "$1"
  exit $2
}

usage(){
  echo "$0 <projectdirectory>"
  echo "  projectdirectory  The directory where the exported objects are hosted"
  echo "Examples:"
  echo "    $0 myproject"
}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]
then
  usage
  die "projectdirectory not provided" 2
fi

for i in oc
do
  command -v $i >/dev/null 2>&1 || die "$i required but not found" 3
done

PROJECT=$1
oc create -f ${PROJECT}/ns.json -n ${PROJECT}
sleep 2
oc create -f ${PROJECT}/rolebindings.json -n ${PROJECT}
oc create -f ${PROJECT}/secrets.json -n ${PROJECT}
oc create -f ${PROJECT}/serviceaccounts.json -n ${PROJECT}
oc create -f ${PROJECT}/templates.json -n ${PROJECT}
oc create -f ${PROJECT}/svcs.json -n ${PROJECT}
oc create -f ${PROJECT}/iss.json -n ${PROJECT}
oc create -f ${PROJECT}/pvcs.json -n ${PROJECT}
oc create -f ${PROJECT}/cms.json -n ${PROJECT}
oc create -f ${PROJECT}/bcs.json -n ${PROJECT}
oc create -f ${PROJECT}/builds.json -n ${PROJECT}
oc create -f ${PROJECT}/dcs.json -n ${PROJECT}
oc create -f ${PROJECT}/rcs.json -n ${PROJECT}
oc create -f ${PROJECT}/pods.json -n ${PROJECT}
oc create -f ${PROJECT}/routes.json -n ${PROJECT}

#!/bin/bash
set -eo pipefail

die(){
  echo "$1"
  exit $2
}

usage(){
  echo "$0 [path]"
  echo "  path  The directory where the backup will be stored"
  echo "        /backup/\$(hostname)/\$(date +%Y%m%d) by default"
  echo "Examples:"
  echo "    $0 /my/mountpoint/\$(hostname)"
}

ocpfiles(){
  mkdir -p ${BACKUPLOCATION}/sysconfig
  echo "Exporting OCP related files to ${BACKUPLOCATION}"
  cp -aR /etc/origin ${BACKUPLOCATION}
  cp -aR /etc/sysconfig/atomic-* ${BACKUPLOCATION}/sysconfig
}

otherfiles(){
  mkdir -p ${BACKUPLOCATION}/{sysconfig,external_certificates}
  echo "Exporting other important files to ${BACKUPLOCATION}"
  cp -aR /etc/sysconfig/{iptables,docker-*,flanneld} \
    ${BACKUPLOCATION}/sysconfig/
  cp -aR /etc/pki/ca-trust/source/anchors/* \
    ${BACKUPLOCATION}/external_certificates
}

packagelist(){
  echo "Creating a list of rpms installed in ${BACKUPLOCATION}"
  rpm -qa | sort > ${BACKUPLOCATION}/packages.txt
}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

BACKUPLOCATION=${1:-"/backup/$(hostname)/$(date +%Y%m%d)"}

mkdir -p ${BACKUPLOCATION}

ocpfiles
otherfiles
packagelist

exit 0

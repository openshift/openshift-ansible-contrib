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
  mkdir -p ${BACKUPLOCATION}/etc/sysconfig
  echo "Exporting OCP related files to ${BACKUPLOCATION}"
  cp -aR /etc/origin ${BACKUPLOCATION}/etc
  cp -aR /etc/sysconfig/atomic-* ${BACKUPLOCATION}/etc/sysconfig
}

otherfiles(){
  mkdir -p ${BACKUPLOCATION}/etc/sysconfig
  mkdir -p ${BACKUPLOCATION}/etc/pki/ca-trust/source/anchors
  echo "Exporting other important files to ${BACKUPLOCATION}"
  if [ -f /etc/sysconfig/flanneld ]
  then
    cp -a /etc/sysconfig/flanneld \
      ${BACKUPLOCATION}/etc/sysconfig/
  fi
  cp -aR /etc/sysconfig/{iptables,docker-*} \
    ${BACKUPLOCATION}/etc/sysconfig/
  if [ -d /etc/cni ]
  then
    cp -aR /etc/cni ${BACKUPLOCATION}/etc/
  fi
  cp -aR /etc/dnsmasq* ${BACKUPLOCATION}/etc/
  cp -aR /etc/pki/ca-trust/source/anchors/* \
    ${BACKUPLOCATION}/etc/pki/ca-trust/source/anchors/
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

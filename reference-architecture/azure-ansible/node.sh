#!/bin/bash

domain=$(grep search /etc/resolv.conf | awk '{print $2}')

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

#yum -y update
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion

cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/sdc
VG=docker-vg
EXTRA_DOCKER_STORAGE_OPTIONS="--storage-opt dm.basesize=3G"
EOF

mkdir -p /var/lib/origin/openshift.local.volumes
ZEROVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 )
parted -s -a optimal ${ZEROVG} mklabel gpt -- mkpart primary xfs 1 -1
sleep 5
mkfs.xfs -f ${ZEROVG}1
echo "${ZEROVG}1  /var/lib/origin/openshift.local.volumes xfs  defaults,grpquota  0  0" >> /etc/fstab
mount ${ZEROVG}1

touch /root/.updateok


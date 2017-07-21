#!/bin/bash

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion

mkdir -p /var/lib/origin/openshift.local.volumes
ZEROVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 | head -n1)
parted -s -a optimal ${ZEROVG} mklabel gpt -- mkpart primary xfs 1 -1
sleep 5
mkfs.xfs -f ${ZEROVG}1
echo "${ZEROVG}1  /var/lib/origin/openshift.local.volumes xfs  defaults,gquota  0  0" >> /etc/fstab
mount ${ZEROVG}1

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 | head -n1 )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=$DOCKERVG
VG=docker-vg
DATA_SIZE=95%VG
EXTRA_DOCKER_STORAGE_OPTIONS="--storage-opt dm.basesize=3G"
EOF

sed -i -e 's/ResourceDisk.EnableSwap.*/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf
sed -i -e 's/ResourceDisk.SwapSizeMB.*/ResourceDisk.SwapSizeMB=0/g' /etc/waagent.conf
swapoff -a
# Do not restart waagent as it will make the installation fail
#systemctl restart waagent.service

touch /root/.updateok

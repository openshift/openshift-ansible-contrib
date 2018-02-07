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
VG=docker_vol
DATA_SIZE=95%VG
STORAGE_DRIVER=overlay2
CONTAINER_ROOT_LV_NAME=dockerlv
CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
CONTAINER_ROOT_LV_SIZE=100%FREE
EOF

sed -i -e 's/ResourceDisk.EnableSwap.*/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf
sed -i -e 's/ResourceDisk.SwapSizeMB.*/ResourceDisk.SwapSizeMB=0/g' /etc/waagent.conf
swapoff -a
# Do not restart waagent as it will make the installation fail
#systemctl restart waagent.service

echo "Resize Root FS"
rootdev=`findmnt --target / -o SOURCE -n`
rootdrivename=`lsblk -no pkname $rootdev`
rootdrive="/dev/"$rootdrivename
majorminor=`lsblk  $rootdev -o MAJ:MIN | tail -1`
part_number=${majorminor#*:}
yum install -y cloud-utils-growpart.noarch
growpart $rootdrive $part_number -u on
xfs_growfs $rootdev

# to enable to suport of CNS this is required
modprobe dm_thin_pool

touch /root/.updateok

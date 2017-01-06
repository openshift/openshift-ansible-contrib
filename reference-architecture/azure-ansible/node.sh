#!/bin/bash

domain=$(grep search /etc/resolv.conf | awk '{print $2}')
sudo hostnamectl set-hostname ${HOSTNAME}.${domain}
<<<<<<< HEAD
ifdown eth0
ifup eth0
=======
>>>>>>> e4e85029d9dc0a20fba1b9bc57de715460933dac

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

#yum -y update
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion docker

sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker
                                                                                         
cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/sdc
VG=docker-vg
EXTRA_DOCKER_STORAGE_OPTIONS="--storage-opt dm.basesize=3G"
EOF

docker-storage-setup                                                                                                                                    
systemctl enable docker
touch /root/.updateok


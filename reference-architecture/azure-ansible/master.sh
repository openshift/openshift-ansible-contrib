#!/bin/bash

USERNAME=$1
PASSWORD=$2
HOSTNAME=$3
NODECOUNT=$4
ROUTEREXTIP=$5
RHNUSERNAME=$6
RHNPASSWORD=$7
RHNPOOLID=$8
SSHPRIVATEDATA=$9
SSHPUBLICDATA=${10}
SSHPUBLICDATA2=${11}
SSHPUBLICDATA3=${12}

domain=$(grep search /etc/resolv.conf | awk '{print $2}')

ps -ef | grep master.sh > cmdline.out

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

mkdir -p /home/$USERNAME/.ssh
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3 >  /home/$USERNAME/.ssh/id_rsa.pub
echo $SSHPRIVATEDATA | base64 --d > /home/$USERNAME/.ssh/id_rsa
chown $USERNAME /home/$USERNAME/.ssh/id_rsa.pub
chmod 600 /home/$USERNAME/.ssh/id_rsa.pub
chown $USERNAME /home/$USERNAME/.ssh/id_rsa
chmod 600 /home/$USERNAME/.ssh/id_rsa

mkdir -p /root/.ssh
echo $SSHPRIVATEDATA | base64 --d > /root/.ssh/id_rsa
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3   >  /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa

subscription-manager unregister 
subscription-manager register --username $RHNUSERNAME --password ${RHNPASSWORD}
subscription-manager attach --pool=$RHNPOOLID
subscription-manager repos --disable="*"
subscription-manager repos     --enable="rhel-7-server-rpms"     --enable="rhel-7-server-extras-rpms"
subscription-manager repos     --enable="rhel-7-server-ose-3.4-rpms"
yum -y install atomic-openshift-utils
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools
yum -y install docker
sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker
                                                                                         
touch /root/.updateok

cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/sdc
VG=docker-vg
EXTRA_DOCKER_STORAGE_OPTIONS="--storage-opt dm.basesize=3G"
EOF

docker-storage-setup                                                                                                                                    
systemctl enable docker
systemctl start docker


cat <<EOF > /home/${USERNAME}/.ansible.cfg
[defaults]
host_key_checking = False
EOF
chown ${USERNAME} /home/${USERNAME}/.ansible.cfg
  
cat <<EOF > /root/.ansible.cfg
[defaults]
host_key_checking = False
EOF



#!/bin/sh
#
# Execute these preparation steps on all hosts
# Run on the bastion host
#
OCP_VERSION=${OCP_VERSION:-3.2}

MASTERS="master-0 master-1 master-2"
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$MASTERS $INFRA_NODES $APP_NODES"

[ -r ./rhn_credentials ] && source ./rhn_credentials

RHN_USERNAME=${RHN_USERNAME:-testuser}
RHN_PASSWORD=${RHN_PASSWORD:-testpass}
POOL_ID=${POOL_ID:-''}

cat <<EOF >ifcfg-eth1
# /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE="eth1"
BOOTPROTO="dhcp"
BOOTPROTOv6="none"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="no"
PEERDNS="no"
IPV6INIT="no"
PERSISTENT_DHCLIENT="1"
EOF

cat <<EOF > docker-storage-setup
DEVS=/dev/vdb
VG=docker-vg
EOF

for H in $ALL_HOSTS ; do
    
    ssh $H sudo subscription-manager register \
        --username $RHN_USERNAME --password $RHN_PASSWORD
    if [ -n "$POOL_ID" ] ; then
        ssh $H sudo subscription-manager subscribe --pool $POOL_ID
    fi
    ssh $H sudo subscription-manager repos --disable="*"
    ssh $H sudo subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-rpms"

    ssh $H sudo subscription-manager repos \
        --enable="rhel-7-server-ose-${OCP_VERSION}-rpms"

    ssh $H sudo subscription-manager repos \
        --enable="rhel-7-server-openstack-8-director-rpms" \
        --enable="rhel-7-server-openstack-8-rpms"

    ssh $H sudo yum -y install \
        os-collect-config \
        python-zaqarclient \
        os-refresh-config \
        os-apply-config
 
    ssh $H sudo systemctl enable os-collect-config
    ssh $H sudo systemctl start --no-block os-collect-config

    ssh $H sudo sed -i -e '\$aGATEWAYDEV=eth0' /etc/sysconfig/network

    scp ifcfg-eth1 ${H}:
    ssh $H sudo cp ifcfg-eth1 /etc/sysconfig/network-scripts
    ssh $H sudo ifup eth1

    ssh $H sudo sed -i -e '/PEERDNS/s/=.*/=no/' \
        /etc/sysconfig/network-scripts/ifcfg-eth0

    ssh $H sudo /sbin/iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
    #ssh $H sudo /sbin/iptables -A DOCKER -p tcp -j ACCEPT
    #ssh $H sudo /usr/libexec/iptables/iptables.init save
done

for H in $NODES ; do
    ssh $H sudo yum -y install docker
    
    ssh $H sudo systemctl enable lvm2-lvmetad
    ssh $H sudo systemctl start lvm2-lvmetad
    
    scp docker-storage-setup ${H}:
    ssh $H sudo cp docker-storage-setup /etc/sysconfig
    ssh $H sudo /usr/bin/docker-storage-setup
    
    ssh $H sudo systemctl enable docker
    ssh $H sudo systemctl start docker
done

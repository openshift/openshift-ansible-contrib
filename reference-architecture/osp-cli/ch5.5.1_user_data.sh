#!/bin/sh

#set DOMAIN and SUBDOMAIN to override
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
CONTROL_DOMAIN=${CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}

BASTION="bastion"
MASTERS=$(for M in $(seq 0 $(($MASTER_COUNT-1))) ; do echo master-$M ; done)
INFRA_NODES=$(for I in $(seq 0 $(($INFRA_NODE_COUNT-1))) ; do echo infra-node-$I ; done)
APP_NODES=$(for A in $(seq 0 $(($APP_NODE_COUNT-1))) ; do echo app-node-$A ; done)
ALL_NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$BASTION $MASTERS $ALL_NODES"

function generate_userdata_mime() {
  cat <<EOF
From nobody Fri Oct  7 17:05:36 2016
Content-Type: multipart/mixed; boundary="===============6355019966770068462=="
MIME-Version: 1.0

--===============6355019966770068462==
MIME-Version: 1.0
Content-Type: text/cloud-config; charset="us-ascii"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="$1.yaml"

#cloud-config
hostname: $1
fqdn: $1.$2

write_files:
  - path: "/etc/sysconfig/network-scripts/ifcfg-eth1"
    permissions: "0644"
    owner: "root"
    content: |
      DEVICE=eth1
      TYPE=Ethernet
      BOOTPROTO=dhcp
      ONBOOT=yes
      DEFTROUTE=no
      PEERDNS=no

--===============6355019966770068462==
MIME-Version: 1.0
Content-Type: text/x-shellscript; charset="us-ascii"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="allow-sudo-ssh.sh"

#!/bin/sh
sed -i "/requiretty/s/^/#/" /etc/sudoers

--===============6355019966770068462==--

EOF
}

[ -d user-data ] || mkdir -p user-data
for HOST in $ALL_HOSTS
do
  generate_userdata_mime ${HOST} ${CONTROL_DOMAIN} > user-data/${HOST}.yaml
done

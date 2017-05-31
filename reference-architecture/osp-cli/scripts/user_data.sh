#!/bin/sh

#set DOMAIN and SUBDOMAIN to override
DOMAIN=${DOMAIN:-control.ocp3.example.com}

BASTION=bastion
MASTERS="master-0 master-1 master-2"
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
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

for HOST in $ALL_HOSTS
do
  generate_userdata_mime ${HOST} ${DOMAIN} > user-data/${HOST}.yaml
done

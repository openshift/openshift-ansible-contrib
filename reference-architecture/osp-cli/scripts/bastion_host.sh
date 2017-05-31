#!/bin/sh

OSP_VERSION=${OSP_VERSION:-8}
OCP_VERSION=${OCP_VERSION:-3.2}

if [ ! -d group_vars ] ; then
    mkdir group_vars
    [ -f OSv3.yml ] && mv OSv3.yml group_vars
fi

[ -f .ssh/id_rsa ] || [ -f ocp3_rsa ] && mv ocp3_rsa .ssh/id_rsa
cat <<EOF >.ssh/config
StrictHostKeyChecking no
EOF

chmod 600 .ssh/*

[ -r ./rhn_credentials ] && source ./rhn_credentials

sudo subscription-manager register \
  --username $RHN_USERNAME \
  --password $RHN_PASSWORD
sudo subscription-manager subscribe --pool $POOL_ID

sudo subscription-manager repos --disable="*"
sudo subscription-manager repos \
  --enable=rhel-7-server-rpms \
  --enable=rhel-7-server-extras-rpms \
  --enable=rhel-7-server-optional-rpms

sudo subscription-manager repos --enable="rhel-7-server-ose-${OCP_VERSION}-rpms"

sudo subscription-manager repos \
  --enable="rhel-7-server-openstack-${OSP_VERSION}-director-rpms" \
  --enable="rhel-7-server-openstack-${OSP_VERSION}-rpms"

sudo sed -i \
  '/secure_path = /s|=.*|= /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin|' \
  /etc/sudoers

sudo yum -y install atomic-openshift-utils

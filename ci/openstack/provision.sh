#!/bin/bash

set -euo pipefail

source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" != "true" ]; then
    echo RUN_OPENSTACK_CI is set to false, skipping the openstack end to end test.
    exit
fi

# Do we have ssh keys?

KEYPAIR_NAME="travis-ci-$TRAVIS_BUILD_NUMBER"
echo "Keypair name: $KEYPAIR_NAME"

openstack keypair create "$KEYPAIR_NAME" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

echo CONFIGURE THE INVENTORY

export INVENTORY="$PWD/playbooks/provisioning/openstack/sample-inventory"

mv "$INVENTORY"/clouds.yaml .
mv "$INVENTORY"/ansible.cfg .

sed -i "s/^openstack_ssh_public_key.*/openstack_ssh_public_key: $KEYPAIR_NAME/" "$INVENTORY"/group_vars/all.yml
sed -i 's/^openstack_external_network_name.*/openstack_external_network_name: "38.145.32.0\/22"/' "$INVENTORY"/group_vars/all.yml
sed -i 's/^openstack_default_image_name.*/openstack_default_image_name: "CentOS-7-x86_64-GenericCloud-1703"/' "$INVENTORY"/group_vars/all.yml

PUBLIC_IP="$(curl --silent https://api.ipify.org)"
echo "node_ingress_cidr: $PUBLIC_IP/32" >> "$INVENTORY"/group_vars/all.yml
echo "manage_packages: False" >> "$INVENTORY"/group_vars/all.yml

cat << EOF >> "$INVENTORY"/group_vars/OSEv3.yml
openshift_master_identity_providers:
- name: 'htpasswd_auth'
  login: 'true'
  challenge: 'true'
  kind: 'HTPasswdPasswordIdentityProvider'
  filename: '/etc/origin/master/htpasswd'
openshift_master_htpasswd_users:
  test: '\$apr1\$vUfm7jQS\$C6Vn0GDScgOjzvk1PSHe1/'
openshift_disable_check: disk_availability,memory_availability
EOF


echo GENERATED INVENTORY
echo group_vars/all.yml:
cat $INVENTORY/group_vars/all.yml

echo
echo group_vars/OSEv3.yml
cat $INVENTORY/group_vars/OSEv3.yml


echo INSTALL OPENSHIFT

ansible-galaxy install -r playbooks/provisioning/openstack/galaxy-requirements.yaml -p roles
ansible-playbook --timeout 180 --user openshift --private-key ~/.ssh/id_rsa -i "$INVENTORY" playbooks/provisioning/openstack/provision.yaml

echo
echo INVENTORY hosts file:
cat $INVENTORY/hosts


echo SET UP DNS

cp /etc/resolv.conf resolv.conf.orig
DNS_IP=$(openstack server show dns-0.openshift.example.com --format value --column addresses | awk '{print $2}')
grep -v '^nameserver' resolv.conf.orig > resolv.conf.openshift
echo nameserver "$DNS_IP" >> resolv.conf.openshift
sudo cp resolv.conf.openshift /etc/resolv.conf

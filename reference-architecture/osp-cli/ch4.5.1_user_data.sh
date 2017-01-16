#!/bin/sh

#set DOMAIN and SUBDOMAIN to override
DOMAIN=${DOMAIN:-ocp3.example.com}

BASTION=bastion
MASTERS="master-0 master-1 master-2"
INFRA_NODES="infra-node-0 infra-node-1"
APP_NODES="app-node-0 app-node-1 app-node-2"
ALL_NODES="$INFRA_NODES $APP_NODES"
ALL_HOSTS="$BASTION $MASTERS $ALL_NODES"

# Set the hostname and FQDN and allow sudo via SSH - all instances
function generate_host_info() {
  cat <<EOF
#cloud-config
hostname: $1
fqdn: $1.$2
write_files: 
  - path: /etc/sudoers.d/99-openshift_ssh_user-requiretty
    permissions: 440
    content: |
      Defaults:cloud-user !requiretty
EOF
}

# Add ifcfg-eth1 to all nodes
function generate_eth1() {
  cat <<EOF
  - path: /etc/sysconfig/network-scripts/ifcfg-eth1
    permissions: 444
    content: |
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
}

# Add docker_storage_setup to all nodes
function generate_docker_storage_setup() {
  cat <<EOF
  - path: /etc/sysconfig/docker-storage-setup
    permissions: 444
    content: |
      DEVS=/dev/vdb
      VG=docker-vg
EOF
}

# Create the user-data directory if needed
[ -d user-data ] || mkdir user-data

for HOST in $ALL_HOSTS ; do
  generate_host_info ${HOST} ${DOMAIN} > user-data/${HOST}.yaml
done

for HOST in $ALL_NODES ; do
  generate_eth1 >> user-data/${HOST}.yaml
  generate_docker_storage_setup >> user-data/${HOST}.yaml
done

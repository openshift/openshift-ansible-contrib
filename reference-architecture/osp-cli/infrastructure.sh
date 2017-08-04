#!/bin/sh
#
set -xue

SCRIPTS=$(dirname $0)

export OCP3_DNS_NAMESERVER=${OCP3_DNS_NAMESERVER:-10.0.0.210}
export OCP3_DOMAIN=${OSP3_DOMAIN:-ocp3.example.com}
export OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
export PUBLIC_NETWORK=${PUBLIC_NETWORK:-public_network}

function create_networks() {
    sh ${SCRIPTS}/ch5.3_control_network.sh
    sh ${SCRIPTS}/ch5.3_tenant_network.sh
}

function create_security_groups() {
    sh ${SCRIPTS}/ch5.4.2_bastion_security_group.sh
    sh ${SCRIPTS}/ch5.4.3_master_security_group.sh
    sh ${SCRIPTS}/ch5.4.6_app_node_security_group.sh
    sh ${SCRIPTS}/ch5.4.5_infra_node_security_group.sh
}

function boot_vms() {
    sh ${SCRIPTS}/ch5.5.1_user_data.sh

    sh ${SCRIPTS}/ch5.5.2_boot_bastion.sh

    sh ${SCRIPTS}/ch5.5.3_boot_masters.sh
    
    sh ${SCRIPTS}/ch5.5.4_cinder_volumes.sh

    sh ${SCRIPTS}/ch5.5.5_boot_infra_nodes.sh
    sh ${SCRIPTS}/ch5.5.5_boot_app_nodes.sh

    echo "Waiting for instances to boot"
    sleep 10
    
    sh ${SCRIPTS}/ch5.5.6_disable_port_security.sh

    sh ${SCRIPTS}/ch5.5.7_create_floating_ip_addresses.sh
}

create_networks
create_security_groups
boot_vms

#sh ${SCRIPTS}/generate_dns_updates.sh

#sh ${SCRIPTS}/generate_haproxy_config.sh

# 


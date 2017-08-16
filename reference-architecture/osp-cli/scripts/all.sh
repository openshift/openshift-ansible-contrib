#!/bin/sh
#
#
#
SCRIPTS=$(dirname $0)

export NAMESERVER=10.19.114.130
export DOMAIN=control.ocp3.e2e.bos.redhat.com

function create_networks() {
    sh ${SCRIPTS}/control_network.sh
    sh ${SCRIPTS}/tenant_network.sh
}

function create_security_groups() {
    sh ${SCRIPTS}/bastion_security_group.sh
    sh ${SCRIPTS}/master_security_group.sh
    sh ${SCRIPTS}/infra_node_security_group.sh
    sh ${SCRIPTS}/app_node_security_group.sh
}


function boot_vms() {
    sh ${SCRIPTS}/user_data.sh

    sh ${SCRIPTS}/boot_bastion.sh
    sh ${SCRIPTS}/boot_masters.sh

    sh ${SCRIPTS}/cinder_volumes.sh
    
    sh ${SCRIPTS}/boot_infra_nodes.sh
    sh ${SCRIPTS}/boot_app_nodes.sh

    sh ${SCRIPTS}/disable_port_security.sh

    sh ${SCRIPTS}/create_floating_ip_addresses.sh
}

create_networks
#create_security_groups
sh ${SCRIPTS}/security_groups.sh
boot_vms

sh ${SCRIPTS}/../manual/generate_dns_updates.sh

# sh ${SCRIPTS}/generate_haproxy_config.sh

# 


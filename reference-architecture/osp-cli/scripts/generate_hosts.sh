#!/bin/sh

function hostname() {
    # Remove everything from the first dot to the end.
    # $1 = FQDN
    echo $1 | sed -e 's/\..*$//'
}

function ip_name_map() {
    # For each VM get the VM name and the IP address from the control network
    nova list --field name,networks |
        grep control-network |
        sed -e 's/control-network=//' |
        tr -d , |
        awk '{print $7 ":" $4}'
}


for ENTRY in $(ip_name_map) ; do
    FQDN=$(echo $ENTRY | sed -e 's/^.*://')
    IPADDR=$(echo $ENTRY | sed -e 's/:.*$//')
    HOSTNAME=$(hostname $FQDN)
    echo $IPADDR $FQDN $HOSTNAME
done


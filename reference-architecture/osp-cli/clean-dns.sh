#!/bin/sh
OCP3_DOMAIN=${OCP3_DOMAIN:-ocp3.example.com}
OCP3_CONTROL_DOMAIN=${OCP3_CONTROL_DOMAIN:-control.${OCP3_DOMAIN}}
OCP3_TENANT_DOMAIN=${OCP3_TENANT_DOMAIN:-tenant.${OCP3_DOMAIN}}
[ -z "${OCP3_DNS_NAMESERVER}" ] && echo "Missing required value OCP3_DNS_NAMESERVER" && exit 1
[ -z ${OCP3_DNS_UPDATE_KEY} ] && echo "MIssing required value OCP3_DNS_UPDATE_KEY" && exit 1

function internal_names() {
    dig @${OCP3_DNS_NAMESERVER} ${OCP3_DOMAIN} axfr |
        grep -e "${OCP3_CONTROL_DOMAIN}\|${OCP3_TENANT_DOMAIN}" |
        cut -d' ' -f1 |
        sed -e 's/^/update delete /'
}

function public_names() {
    dig @${OCP3_DNS_NAMESERVER} ${OCP3_DOMAIN} axfr |
        grep "\(infra-node-\|master-\)[[:digit:]].${OCP3_DOMAIN}" |
        cut -d' ' -f1 |
        sed -e 's/^/update delete /'
}

nsupdate -k ${OCP3_DNS_UPDATE_KEY} <<EOF
server ${OCP3_DNS_NAMESERVER}
zone ${OCP3_DOMAIN}
$(internal_names)
$(public_names)
update delete bastion.${OCP3_DOMAIN}
update delete lb.${OCP3_DOMAIN}
update delete devs.${OCP3_DOMAIN}
update delete *.apps.${OCP3_DOMAIN}
send
quit
EOF

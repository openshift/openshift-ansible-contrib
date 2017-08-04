#!/bin/sh
# Define RHN_USERNAME, RHN_PASSWORD and RHN_POOL_ID in this file
[ -r ./rhn_credentials ] && source ./rhn_credentials

sh ./ch5.8.1.1_register.sh
sh ./ch5.8.1.2_enable_repos.sh
sh ./ch5.8.1.3_install_openshift-ansible-playbooks.sh

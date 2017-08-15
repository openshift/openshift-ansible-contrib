
#!/bin/sh
#
# Execute these preparation steps on all hosts
# Run on the bastion host
#

[ -r ./rhn_credentials ] && source ./rhn_credentials
[ -r ./rhn_versions ] && source ./rhn_versions

OCP3_VERSION=${OCP3_VERSION:-3.4}
OSP_VERSION=${OSP_VERSION:-10}

# This can take several passes to finish
for I in 1 .. 5 ; do
    sh ch5.8.3_rhn_subscribe_all_ansible.sh
    [ $? -eq 0 ] && break
done
#ssh $H sudo subscription-manager register \
#    --username $RHN_USERNAME --password $RHN_PASSWORD
#if [ -n "$POOL_ID" ] ; then
#    ssh $H sudo subscription-manager subscribe --pool $POOL_ID
#fi

sh ch5.8.3_enable_server_repos_all_ansible.sh
#ssh $H sudo subscription-manager repos --disable="*"
#ssh $H sudo subscription-manager repos \
#    --enable="rhel-7-server-rpms" \
#    --enable="rhel-7-server-extras-rpms" \
#    --enable="rhel-7-server-optional-rpms"

sh ch5.8.3_enable_ocp_repo_all_ansible.sh
#ssh $H sudo subscription-manager repos \
#  --enable="rhel-7-server-ose-${OCP3_VERSION}-rpms"

sh ch5.8.3_enable_osp_repos_all_ansible.sh
#ssh $H sudo subscription-manager repos \
#  --enable="rhel-7-server-openstack-8-director-rpms" \
#  --enable="rhel-7-server-openstack-8-rpms"

sh ch5.8.3_disable_peerdns_eth0_all_ansible.sh
#    ssh $H sudo sed -i -e '/PEERDNS/s/=.*/=no/' \
    #        /etc/sysconfig/network-scripts/ifcfg-eth0

sh ch5.8.3_enable_eth1_all_ansible.sh
#ssh $H sudo sed -i -e '\$aGATEWAYDEV=eth0' /etc/sysconfig/network
#ssh $H sudo ifup eth1
#ssh $H sudo /sbin/iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

sh ch5.8.4_enable_lvmetad_nodes_ansible.sh
#ssh $H sudo systemctl enable lvm2-lvmetad
#ssh $H sudo systemctl start lvm2-lvmetad

sh ch5.8.5_configure_docker_storage_ansible.sh

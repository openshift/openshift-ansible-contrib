#!/bin/sh

neutron security-group-create bastion-sg
neutron security-group-create master-sg
#neutron security-group-create etcd-sg
#neutron security-group-create router-sg
neutron security-group-create infra-sg
neutron security-group-create node-sg



#
# Bastion:
#  Port/Proto  From      Reason
#
#  22/TCP      anywhere  Secure Shell
#  53/TCP      anywhere  Nameservice
#  53/UDP      anywhere  Nameservice
neutron security-group-rule-create bastion-sg --protocol icmp
neutron security-group-rule-create bastion-sg \
    --protocol tcp --port-range-min 22 --port-range-max 22
neutron security-group-rule-create bastion-sg \
    --protocol tcp --port-range-min 53 --port-range-max 53
neutron security-group-rule-create bastion-sg \
    --protocol udp --port-range-min 53 --port-range-max 53


#
# Master:
#   Port/Proto  From      Reason
#
#  22/TCP      bastion   Secure Shell
#  8443/TCP    lb        WebUI/REST
#  8443/TCP    master    WebUI/REST     ??
#  8443/TCP    node      WebUI/REST     ??
#  8053/TCP    node      Name Service   ??
#  8053/UDP    node      Name Service   ??
neutron security-group-rule-create master-sg --protocol icmp
for PORT in 22 53 2379 4001 4789 8053 8443 10250 24224 ; do
    neutron security-group-rule-create master-sg \
            --protocol tcp --port-range-min $PORT --port-range-max $PORT
done

for PORT in 53 4789 8053 8443 24224 ; do
    neutron security-group-rule-create master-sg \
            --protocol udp --port-range-min $PORT --port-range-max $PORT
done

neutron security-group-rule-create master-sg \
     --protocol tcp --port-range-min 2380 --port-range-max 2380 \
     --remote-group-id master-sg

#neutron security-group-rule-create master-sg \
#     --protocol tcp --port-range-min 8443 --port-range-max 8443 \
#     --remote-group-id master-sg
#neutron security-group-rule-create master-sg \
#     --protocol tcp --port-range-min 8443 --port-range-max 8443 \
#     --remote-group-id node-sg
#neutron security-group-rule-create master-sg \
#     --protocol tcp --port-range-min 8053 --port-range-max 8053 \
#     --remote-group-id node-sg
#neutron security-group-rule-create master-sg \
#     --protocol udp --port-range-min 8053 --port-range-max 8053 \
#     --remote-group-id node-sg

#
# etcd:
#   Port/Proto  From      Reason
#
#  2379/TCP     etcd      etcd
#  2379/TCP     master    etcd
#  2380/TCP     etcd      etcd
#neutron security-group-rule-create etcd-sg \
#     --protocol tcp --port-range-min 2379 --port-range-max 2379 
#     --remote-group-id etcd-sg
#neutron security-group-rule-create etcd-sg \
#     --protocol tcp --port-range-min 2380 --port-range-max 2380 \
#     --remote-group-id etcd-sg



# router:
#   Port/Proto  From      Reason
#
#  80/TCP       lb        HTTP
#  443/TCP      lb        HTTPS
# infra:
#   Port/Proto  From      Reason
#
#  80/TCP       lb        HTTP
#  443/TCP      lb        HTTPS
#neutron security-group-rule-create router-sg \
#     --protocol tcp --port-range-min 80 --port-range-max 80
#neutron security-group-rule-create router-sg \
#     --protocol tcp --port-range-min 443 --port-range-max 443

# infra
neutron security-group-rule-create infra-sg --protocol icmp
for PORT in 22 80 443 5000 10250 ; do
    neutron security-group-rule-create infra-sg \
            --protocol tcp --port-range-min $PORT --port-range-max $PORT
done
neutron security-group-rule-create infra-sg \
            --protocol tcp --port-range-min 4789 --port-range-max 4789



# node:
#   Port/Proto  From      Reason
#  22/TCP       bastion   Secure Shell
#  10250/TCP    master    kubelet??
#  4789/UDP     node      ??
#neutron security-group-rule-create node-sg --protocol icmp
#neutron security-group-rule-create node-sg \
#     --protocol tcp --port-range-min 22 --port-range-max 22 \
#     --remote-group-id bastion-sg
#neutron security-group-rule-create node-sg \
#     --protocol tcp --port-range-min 10250 --port-range-max 10250 \
#     --remote-group-id master-sg
#neutron security-group-rule-create node-sg \
#     --protocol tcp --port-range-min 4789 --port-range-max 4789 \
#     --remote-group-id node-sg
neutron security-group-rule-create node-sg --protocol icmp
for PORT in 22 10250 ; do
    neutron security-group-rule-create node-sg \
            --protocol tcp --port-range-min $PORT --port-range-max $PORT
done
neutron security-group-rule-create node-sg \
            --protocol tcp --port-range-min 4789 --port-range-max 4789

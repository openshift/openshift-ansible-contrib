#!/bin/sh
for H in $ALL_HOSTS ; do
    scp ifcfg-eth1 $H:
    ssh $H sudo cp ifcfg-eth1 /etc/sysconfig/network-scripts
    ssh $H sudo ifup eth1
done 

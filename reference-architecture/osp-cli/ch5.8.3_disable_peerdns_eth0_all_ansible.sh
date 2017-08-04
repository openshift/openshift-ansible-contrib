ansible masters,nodes -i inventory -m script -a \
  "/usr/bin/sed -i -e '/PEERDNS/s/=.*/=no/' /etc/sysconfig/network-scripts/ifcfg-eth0"


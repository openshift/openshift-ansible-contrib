#ansible masters -i inventory \
#  -a '/usr/sbin/iptables -A DOCKER -p tcp -j ACCEPT'
ansible nodes -i inventory \
  -a '/usr/sbin/iptables -A DOCKER -p tcp -j ACCEPT'

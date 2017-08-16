export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles
export ANSIBLE_HOST_KEY_CHECKING=False
flannel_interface=eth1

ansible-playbook -vvv --inventory inventory \
  /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml

ansible masters -i inventory -m shell -a 'iptables -A DOCKER -p tcp -j ACCEPT'
ansible nodes -i inventory -m shell -a 'iptables -A DOCKER -p tcp -j ACCEPT'
ansible masters -i inventory -m shell -a 'iptables -t nat -A POSTROUTING -o '
${flannel_interface} ' -j MASQUERADE'
ansible nodes -i inventory -m shell -a 'iptables -t nat -A POSTROUTING -o '
${flannel_interface} ' -j MASQUERADE'

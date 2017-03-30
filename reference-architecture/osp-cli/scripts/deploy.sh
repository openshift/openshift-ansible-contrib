export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles
export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook -vvv --inventory inventory \
  /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml

ansible masters -i inventory -m shell -a 'iptables -A DOCKER -p tcp -j ACCEPT'
ansible nodes -i inventory -m shell -a 'iptables -A DOCKER -p tcp -j ACCEPT'

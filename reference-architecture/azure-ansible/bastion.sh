#!/bin/bash

export RESOURCEGROUP=$1
export WILDCARDZONE=$2
export AUSERNAME=$3
export PASSWORD=$4
export HOSTNAME=$5
export NODECOUNT=$6
export ROUTEREXTIP=$7
export RHNUSERNAME=$8
export RHNPASSWORD=$9
export RHNPOOLID=${10}
export SSHPRIVATEDATA=${11}
export SSHPUBLICDATA=${12}
export SSHPUBLICDATA2=${13}
export SSHPUBLICDATA3=${14}

domain=$(grep search /etc/resolv.conf | awk '{print $2}')

ps -ef | grep bastion.sh > cmdline.out

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

mkdir -p /home/$AUSERNAME/.ssh
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3 >  /home/$AUSERNAME/.ssh/id_rsa.pub
echo $SSHPRIVATEDATA | base64 --d > /home/$AUSERNAME/.ssh/id_rsa
chown $AUSERNAME /home/$AUSERNAME/.ssh/id_rsa.pub
chmod 600 /home/$AUSERNAME/.ssh/id_rsa.pub
chown $AUSERNAME /home/$AUSERNAME/.ssh/id_rsa
chmod 600 /home/$AUSERNAME/.ssh/id_rsa

mkdir -p /root/.ssh
echo $SSHPRIVATEDATA | base64 --d > /root/.ssh/id_rsa
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3   >  /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa

sleep 30
cat <<EOF > /root/setup_ssmtp.sh
# \$1 = Gmail Account (Leave off @gmail.com ie user)
# \$2 = Gmail Password
# \$3 = Notification email address
# Setup ssmtp mta agent for use with gmail
yum -y install wget
wget -c https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm
rpm -ivh epel-release-7-8.noarch.rpm
yum -y install ssmtp
alternatives --set mta  /usr/sbin/sendmail.ssmtp
systemctl stop postfix
systemctl disable postfix
cat <<EOFZ > /etc/ssmtp/ssmtp.conf
root=postmaster
mailhub=mail
TLS_CA_File=/etc/pki/tls/certs/ca-bundle.crt
mailhub=smtp.gmail.com:587   # SMTP server for Gmail
Hostname=localhost
UseTLS=YES
UseSTARTTLS=Yes
FromLineOverride=YES #TO CHANGE FROM EMAIL
Root=\${3} # Redirect root email
AuthUser=\${1}@gmail.com
AuthPass=\${2}
AuthMethod=LOGIN
RewriteDomain=gmail.com
EOFZ
cat <<EOFZ > /etc/ssmtp/revaliases
root:\${1}@gmail.com:smtp.gmail.com:587
EOFZ
EOF
chmod +x /root/setup_ssmtp.sh
# Continue even if ssmtp.sh script errors out
/root/setup_ssmtp.sh ${AUSERNAME} ${PASSWORD} ${RHNUSERNAME} || true

echo "${RESOURCEGROUP} Bastion Host is starting software update" | mail -s "${RESOURCEGROUP} Bastion Software Install" ${RHNUSERNAME} || true
# Continue Setting Up Bastion
subscription-manager unregister
yum -y remove RHEL7
rm -f /etc/yum.repos.d/rh-cloud.repo
# Found that wildcard disable not working all the time - make sure
yum-config-manager --disable epel
yum-config-manager --disable epel-testing
subscription-manager register --username $RHNUSERNAME --password ${RHNPASSWORD}
subscription-manager attach --pool=$RHNPOOLID
subscription-manager repos --disable="*"
subscription-manager repos     --enable="rhel-7-server-rpms"     --enable="rhel-7-server-extras-rpms"
subscription-manager repos     --enable="rhel-7-server-ose-3.4-rpms"
yum -y install atomic-openshift-utils
yum -y install git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools
touch /root/.updateok
cat <<EOF > /etc/ansible/hosts
[OSEv3:children]
masters
etcd
nodes
misc

[OSEv3:vars]
debug_level=2
console_port=8443
openshift_node_debug_level="{{ node_debug_level | default(debug_level, true) }}"
openshift_master_debug_level="{{ master_debug_level | default(debug_level, true) }}"
openshift_master_access_token_max_seconds=2419200
openshift_hosted_router_replicas=4
openshift_hosted_registry_replicas=1
openshift_hosted_router_selector='role=app'
openshift_hosted_registry_selector='role=app'
openshift_master_api_port="{{ console_port }}"
openshift_master_console_port="{{ console_port }}"
openshift_override_hostname_check=true
osm_use_cockpit=false
openshift_release=v3.4
azure_resource_group=${RESOURCEGROUP}
rhn_pool_id=${RHNPOOLID}
openshift_install_examples=true
deployment_type=openshift-enterprise
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

# default selectors for router and registry services
openshift_router_selector='role=infra'
openshift_registry_selector='role=infra'

# Select default nodes for projects
osm_default_node_selector="role=app"
ansible_become=yes
ansible_ssh_user=${AUSERNAME}
remote_user=${AUSERNAME}

openshift_master_default_subdomain=${WILDCARDZONE}.trafficmanager.net
openshift_use_dnsmasq=false
openshift_public_hostname=${RESOURCEGROUP}.trafficmanager.net

openshift_master_cluster_method=native
openshift_master_cluster_hostname=${RESOURCEGROUP}.trafficmanager.net
openshift_master_cluster_public_hostname=${RESOURCEGROUP}.trafficmanager.net

# default storage plugin dependencies to install, by default the ceph and
# glusterfs plugin dependencies will be installed, if available.
osn_storage_plugin_deps=['iscsi']

[masters]
master1.${domain} openshift_node_labels="{'role': 'master'}"
master2.${domain} openshift_node_labels="{'role': 'master'}"
master3.${domain}  openshift_node_labels="{'role': 'master'}"

[etcd]
master1.${domain}
master2.${domain}
master3.${domain}

[nodes]
master1.${domain} openshift_node_labels="{'role':'master','zone':'default'}"
master2.${domain} openshift_node_labels="{'role':'master','zone':'default'}"
master3.${domain} openshift_node_labels="{'role':'master','zone':'default'}"
node[01:${NODECOUNT}].${domain} openshift_node_labels="{'role': 'app', 'zone': 'default'}"
infranode1.${domain}  openshift_node_labels="{'role': 'infra', 'zone': 'default'}"
infranode2.${domain}  openshift_node_labels="{'role': 'infra', 'zone': 'default'}"
infranode3.${domain} openshift_node_labels="{'role': 'infra', 'zone': 'default'}"

[quotanodes]
master1.${domain} openshift_node_labels="{'role':'master','zone':'default'}"
master2.${domain} openshift_node_labels="{'role':'master','zone':'default'}"
master3.${domain} openshift_node_labels="{'role':'master','zone':'default'}"
node[01:${NODECOUNT}].${domain} openshift_node_labels="{'role': 'app', 'zone': 'default'}"

[misc]
store1.${domain}
EOF


cat <<EOF > /home/${AUSERNAME}/subscribe.yml
---
- hosts: all
  vars:
    description: "Subscribe OCP"
  tasks:
  - name: wait for .updateok
    wait_for: path=/root/.updateok
  - name: check connection
    ping:
  - name: Get rid of RHUI repos
    file: path=/etc/yum.repos.d/rh-cloud.repo state=absent
  - name: Get rid of RHUI load balancers
    file: path=/etc/yum.repos.d/rhui-load-balancers state=absent
  - name: remove the RHUI package
    yum: name=RHEL7 state=absent
  - name: Get rid of old subs
    shell: subscription-manager unregister
    ignore_errors: yes
  - name: register hosts
    shell: subscription-manager register --username ${RHNUSERNAME} --password ${RHNPASSWORD}
    register: task_result
    until: task_result.rc == 0
    retries: 10
    delay: 30
    ignore_errors: yes
  - name: attach sub
    shell: subscription-manager attach --pool=$RHNPOOLID
    register: task_result
    until: task_result.rc == 0
    retries: 10
    delay: 30
    ignore_errors: yes
  - name: disable all repos
    shell: subscription-manager repos --disable="*"
  - name: enable rhel7 repo
    shell: subscription-manager repos --enable="rhel-7-server-rpms"
  - name: enable extras repos
    shell: subscription-manager repos --enable="rhel-7-server-extras-rpms"
  - name: enable OCP repos
    shell: subscription-manager repos --enable="rhel-7-server-ose-3.4-rpms"
  - name: install the latest version of PyYAML
    yum: name=PyYAML state=latest
  - name: Install the OCP client
    yum: name=atomic-openshift-clients state=latest
  - name: Update all hosts
    command: yum -y update
    async: 1200
    poll: 10
  - name: Wait for Things to Settle
    pause:  minutes=5
EOF

cat <<EOF > /home/${AUSERNAME}/quota.yml
---
- hosts: quotanodes
  vars:
    description: "Fix EP Storage/Quota"
  tasks:
  - name: Change Node perFSGroup Qouta Setting
    lineinfile: dest=/etc/origin/noce/node-config.yaml regexp=^perFSGroup: line="    perFSGroup:512Mi"
  - name: Update Mount to Handle Quota
    mount: fstype=xfs name=/var/lib/origin/openshift.local/volumes src=/dev/sdd option="gquota" state="mounted"
EOF


cat <<EOF > /home/${AUSERNAME}/setupiscsi.yml
- hosts: all
  vars:
    description: "Subscribe OCP"
  tasks:
  - name: Install iSCSI initiator utils
    yum: name=iscsi-initiator-utils state=latest
  - name: add new initiator name
    lineinfile: dest=/etc/iscsi/initiatorname.iscsi create=yes regexp="InitiatorName=*" line="InitiatorName=iqn.2016-02.local.azure.nodes" state=present
  - name: restart iSCSI service
    shell: systemctl restart iscsi
    ignore_errors: yes
  - name: Enable iSCSI
    shell: systemctl enable iscsi
    ignore_errors: yes
  - name: Start iSCSI Initiator Service
    shell: systemctl start iscsi
    ignore_errors: yes
  - name: Discover iSCSI on all hosts
    shell: iscsiadm --mode discovery --type sendtargets --portal store1
    register: task_result
    until: task_result.rc == 0
    retries: 10
    delay: 30
    ignore_errors: yes
  - name: Login All Hosts
    shell: iscsiadm --mode node --portal store1 --login
    register: task_result
    until: task_result.rc == 0
    retries: 10
    delay: 30
    ignore_errors: yes
EOF


cat <<EOF > /home/${AUSERNAME}/postinstall.yml
---
- hosts: masters
  vars:
    description: "auth users"
  tasks:
  - name: Create Master Directory
    file: path=/etc/origin/master state=directory
  - name: add initial user to Red Hat OpenShift Container Platform
    shell: htpasswd -c -b /etc/origin/master/htpasswd ${AUSERNAME} ${PASSWORD}

EOF

cat <<EOF > /home/${AUSERNAME}/openshift-install.sh
export ANSIBLE_HOST_KEY_CHECKING=False
sleep 120
ansible all --module-name=ping > ansible-preinstall-ping.out || true
ansible-playbook  /home/${AUSERNAME}/subscribe.yml
echo "${RESOURCEGROUP} Bastion Host is starting ansible BYO" | mail -s "${RESOURCEGROUP} Bastion BYO Install" ${RHNUSERNAME} || true
ansible-playbook  /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml < /dev/null &> byo.out

wget http://master1:8443/api > healtcheck.out
ansible-playbook /home/${AUSERNAME}/quota.yml
ansible-playbook /home/${AUSERNAME}/postinstall.yml
ansible-playbook /home/${AUSERNAME}/setupiscsi.yml
cd /root
mkdir .kube
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${AUSERNAME}@master1:~/.kube/config /tmp/kube-config
cp /tmp/kube-config /root/.kube/config
mkdir /home/${AUSERNAME}/.kube
cp /tmp/kube-config /home/${AUSERNAME}/.kube/config
chown --recursive ${AUSERNAME} /home/${AUSERNAME}/.kube
rm -f /tmp/kube-config
ansible-playbook /home/${AUSERNAME}/setupiscsi.yml
echo "${RESOURCEGROUP} Installation Is Complete" | mail -s "${RESOURCEGROUP} Install Complete" ${RHNUSERNAME} || true
EOF

cat <<EOF > /home/${AUSERNAME}/.ansible.cfg
[defaults]
remote_tmp     = ~/.ansible/tmp
local_tmp      = ~/.ansible/tmp
host_key_checking = False
forks=30
gather_timeout=60
timeout=240
[ssh_connection]
control_path = ~/.ansible/cp/ssh%%h-%%p-%%r
ssh_args = -o ControlMaster=auto -o ControlPersist=600s -o ControlPath=~/.ansible/cp-%h-%p-%r
EOF
chown ${AUSERNAME} /home/${AUSERNAME}/.ansible.cfg

cat <<EOF > /root/.ansible.cfg
[defaults]
remote_tmp     = ~/.ansible/tmp
local_tmp      = ~/.ansible/tmp
host_key_checking = False
forks=30
gather_timeout=60
timeout=240
[ssh_connection]
control_path = ~/.ansible/cp/ssh%%h-%%p-%%r
ssh_args = -o ControlMaster=auto -o ControlPersist=600s -o ControlPath=~/.ansible/cp-%h-%p-%r
EOF


cd /home/${AUSERNAME}
chmod 755 /home/${AUSERNAME}/openshift-install.sh
echo "${RESOURCEGROUP} Bastion Host is starting OpenShift Install" | mail -s "${RESOURCEGROUP} Bastion OpenShift Install Starting" ${RHNUSERNAME} || true
/home/${AUSERNAME}/openshift-install.sh &> /home/${AUSERNAME}/openshift-install.out &
exit 0

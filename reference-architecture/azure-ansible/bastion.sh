#!/bin/bash

export MYARGS=$@
IFS=' ' read -r -a array <<< "$MYARGS"
export RESOURCEGROUP=$1
export WILDCARDZONE=$2
export AUSERNAME=$3
export PASSWORD=$4
export THEHOSTNAME=$5
export NODECOUNT=$6
export ROUTEREXTIP=$7
export RHNUSERNAME=$8
export RHNPASSWORD=$9
export RHNPOOLID=${10}
export SSHPRIVATEDATA=${11}
export SSHPUBLICDATA=${12}
export SSHPUBLICDATA2=${13}
export SSHPUBLICDATA3=${14}
export REGISTRYSTORAGENAME=${array[14]}
export REGISTRYKEY=${array[15]}
export LOCATION=${array[16]}
export SUBSCRIPTIONID=${array[17]}
export TENANTID=${array[18]}
export AADCLIENTID=${array[19]}
export AADCLIENTSECRET=${array[20]}
export RHSMMODE=${array[21]}
export FULLDOMAIN=${THEHOSTNAME#*.*}
export WILDCARDFQDN=${WILDCARDZONE}.${FULLDOMAIN}
export WILDCARDIP=`dig +short ${WILDCARDFQDN}`
export WILDCARDNIP=${WILDCARDIP}.nip.io
echo "Show wildcard info"
echo $WILDCARDFQDN
echo $WILDCARDIP
echo $WILDCARDNIP
echo $RHSMMODE

echo 'Show Registry Values'
echo $REGISTRYSTORAGENAME
echo $REGISTRYKEY
echo $LOCATION
echo $SUBSCRIPTIONID
echo $TENANTID
echo $AADCLIENTID
echo $AADCLIENTSECRET

domain=$(grep search /etc/resolv.conf | awk '{print $2}')

ps -ef | grep bastion.sh > cmdline.out

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

mkdir -p /home/$AUSERNAME/.azuresettings
echo $REGISTRYSTORAGENAME > /home/$AUSERNAME/.azuresettings/registry_storage_name
echo $REGISTRYKEY > /home/$AUSERNAME/.azuresettings/registry_key
echo $LOCATION > /home/$AUSERNAME/.azuresettings/location
echo $SUBSCRIPTIONID > /home/$AUSERNAME/.azuresettings/subscription_id
echo $TENANTID > /home/$AUSERNAME/.azuresettings/tenant_id
echo $AADCLIENTID > /home/$AUSERNAME/.azuresettings/aad_client_id
echo $AADCLIENTSECRET > /home/$AUSERNAME/.azuresettings/aad_client_secret
echo $RESOURCEGROUP > /home/$AUSERNAME/.azuresettings/resource_group
chmod -R 600 /home/$AUSERNAME/.azuresettings/*
chown -R $AUSERNAME /home/$AUSERNAME/.azuresettings

mkdir -p /home/$AUSERNAME/.ssh
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3 >  /home/$AUSERNAME/.ssh/id_rsa.pub
echo $SSHPRIVATEDATA | base64 --d > /home/$AUSERNAME/.ssh/id_rsa
chown $AUSERNAME /home/$AUSERNAME/.ssh/id_rsa.pub
chmod 600 /home/$AUSERNAME/.ssh/id_rsa.pub
chown $AUSERNAME /home/$AUSERNAME/.ssh/id_rsa
chmod 600 /home/$AUSERNAME/.ssh/id_rsa
cp /home/$AUSERNAME/.ssh/authorized_keys /root/.ssh/authorized_keys

mkdir -p /root/.azuresettings
echo $REGISTRYSTORAGENAME > /root/.azuresettings/registry_storage_name
echo $REGISTRYKEY > /root/.azuresettings/registry_key
echo $LOCATION > /root/.azuresettings/location
echo $SUBSCRIPTIONID > /root/.azuresettings/subscription_id
echo $TENANTID > /root/.azuresettings/tenant_id
echo $AADCLIENTID > /root/.azuresettings/aad_client_id
echo $AADCLIENTSECRET > /root/.azuresettings/aad_client_secret
echo $RESOURCEGROUP > /root/.azuresettings/resource_group
chmod -R 600 /root/.azuresettings/*
chown -R root /root/.azuresettings

mkdir -p /root/.ssh
echo $SSHPRIVATEDATA | base64 --d > /root/.ssh/id_rsa
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3   >  /root/.ssh/id_rsa.pub
cp /home/$AUSERNAME/.ssh/authorized_keys /root/.ssh/authorized_keys
chown root /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
chown root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys


sleep 30
cat <<EOF > /root/setup_ssmtp.sh
# \$1 = Gmail Account (Leave off @gmail.com ie user)
# \$2 = Gmail Password
# \$3 = Notification email address
# Setup ssmtp mta agent for use with gmail
yum -y install wget
wget -c https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -ivh epel-release-latest-7.noarch.rpm
yum -y install ssmtp
alternatives --set mta  /usr/sbin/sendmail.ssmtp
mkdir /etc/ssmtp
cat <<EOFZ > /etc/ssmtp/ssmtp.conf
root=${1}
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
rewriteDomain=azure.com
EOFZ
cat <<EOFZ > /etc/ssmtp/revaliases
root:\${1}@gmail.com:smtp.gmail.com:587
EOFZ
EOF
chmod +x /root/setup_ssmtp.sh
# Continue even if ssmtp.sh script errors out
/root/setup_ssmtp.sh ${AUSERNAME} ${PASSWORD} ${RHNUSERNAME} || true

sleep 30
echo "${RESOURCEGROUP} Bastion Host is starting software update" | mail -s "${RESOURCEGROUP} Bastion Software Install" ${RHNUSERNAME} || true
# Continue Setting Up Bastion
subscription-manager unregister
yum -y remove RHEL7
rm -f /etc/yum.repos.d/rh-cloud.repo
# Found that wildcard disable not working all the time - make sure
yum-config-manager --disable epel
yum-config-manager --disable epel-testing
sleep 30
if [[ $RHSMMODE == "usernamepassword" ]]
then
   subscription-manager register --username="${RHNUSERNAME}" --password="${RHNPASSWORD}"
else
   subscription-manager register --org="${RHNUSERNAME}" --activationkey="${RHNPASSWORD}"
fi
subscription-manager attach --pool=$RHNPOOLID
subscription-manager repos --disable="*"
subscription-manager repos     --enable="rhel-7-server-rpms"     --enable="rhel-7-server-extras-rpms rhel-7-fast-datapath-rpms"
subscription-manager repos     --enable="rhel-7-server-ose-3.5-rpms"
yum -y install atomic-openshift-utils git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools nodejs
touch /root/.updateok

# Create azure.conf file

cat > /home/${AUSERNAME}/azure.conf <<EOF
{
   "tenantId": "$TENANTID",
   "subscriptionId": "$SUBSCRIPTIONID",
   "aadClientId": "$AADCLIENTID",
   "aadClientSecret": "$AADCLIENTSECRET",
   "aadTenantID": "$TENANTID",
   "resourceGroup": "$RESOURCEGROUP",
   "location": "$LOCATION",
}
EOF

cat > /home/${AUSERNAME}/vars.yml <<EOF
g_tenantId: $TENANTID
g_subscriptionId: $SUBSCRIPTIONID
g_aadClientId: $AADCLIENTID
g_aadClientSecret: $AADCLIENTSECRET
g_resourceGroup: $RESOURCEGROUP
g_location: $LOCATION
EOF

# Create Azure Cloud Provider configuration Playbook

cat > /home/${AUSERNAME}/azure-config.yml <<EOF
#!/usr/bin/ansible-playbook
- hosts: all
  gather_facts: no
  serial: 1
  vars_files:
  - vars.yml
  become: yes
  vars:
    azure_conf_dir: /etc/azure
    azure_conf: "{{ azure_conf_dir }}/azure.conf"
    master_conf: /etc/origin/master/master-config.yaml
  tasks:
  - name: make sure /etc/azure exists
    file:
      state: directory
      path: "{{ azure_conf_dir }}"

  - name: populate /etc/azure/azure.conf
    copy:
      dest: "{{ azure_conf }}"
      content: |
        {
          "aadClientID" : "{{ g_aadClientId }}",
          "aadClientSecret" : "{{ g_aadClientSecret }}",
          "subscriptionID" : "{{ g_subscriptionId }}",
          "tenantID" : "{{ g_tenantId }}",
          "resourceGroup": "{{ g_resourceGroup }}",
        }
EOF

cat <<EOF > /etc/ansible/hosts
[OSEv3:children]
masters
nodes
etcd

[OSEv3:vars]
osm_controller_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/azure/azure.conf']}
osm_api_server_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/azure/azure.conf']}
openshift_node_kubelet_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/azure/azure.conf']}
debug_level=2
console_port=8443
docker_udev_workaround=True
openshift_node_debug_level="{{ node_debug_level | default(debug_level, true) }}"
openshift_master_debug_level="{{ master_debug_level | default(debug_level, true) }}"
openshift_master_access_token_max_seconds=2419200
openshift_hosted_router_replicas=3
openshift_hosted_registry_replicas=1
openshift_master_api_port="{{ console_port }}"
openshift_master_console_port="{{ console_port }}"
openshift_override_hostname_check=true
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
osm_use_cockpit=false
openshift_release=v3.5
openshift_cloudprovider_kind=azure
openshift_node_local_quota_per_fsgroup=512Mi
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

openshift_master_default_subdomain=${WILDCARDNIP}
#openshift_master_default_subdomain=${WILDCARDZONE}.${FULLDOMAIN}
# osm_default_subdomain=${WILDCARDZONE}.${FULLDOMAIN}
osm_default_subdomain=${WILDCARDNIP}
openshift_use_dnsmasq=false
openshift_public_hostname=${RESOURCEGROUP}.${FULLDOMAIN}

openshift_master_cluster_method=native
openshift_master_cluster_hostname=${RESOURCEGROUP}.${FULLDOMAIN}
openshift_master_cluster_public_hostname=${RESOURCEGROUP}.${FULLDOMAIN}


[masters]
master1 openshift_hostname=master1 openshift_node_labels="{'role': 'master'}"
master2 openshift_hostname=master2 openshift_node_labels="{'role': 'master'}"
master3 openshift_hostname=master3 openshift_node_labels="{'role': 'master'}"

[etcd]
master1
master2
master3

[nodes]
master1 openshift_hostname=master1 openshift_node_labels="{'role':'master','zone':'default'}" openshift_schedulable=false
master2 openshift_hostname=master2 openshift_node_labels="{'role':'master','zone':'default'}" openshift_schedulable=false
master3 openshift_hostname=master3 openshift_node_labels="{'role':'master','zone':'default'}" openshift_schedulable=false
infranode1 openshift_hostname=infranode1 openshift_node_labels="{'role': 'infra', 'zone': 'default'}"
infranode2 openshift_hostname=infranode2 openshift_node_labels="{'role': 'infra', 'zone': 'default'}"
infranode3 openshift_hostname=infranode3 openshift_node_labels="{'role': 'infra', 'zone': 'default'}"
EOF

# Loop to add Nodes

for (( c=01; c<$NODECOUNT+1; c++ ))
do
  pnum=$(printf "%02d" $c)
  echo "node${pnum} openshift_node_labels=\"{'role': 'app', 'zone': 'default'}\" openshift_hostname=node${pnum}" >> /etc/ansible/hosts
done


cat <<EOF > /home/${AUSERNAME}/subscribe.yml
---
- hosts: all
  vars:
    description: "Wait for nodes"
  tasks:
  - name: wait for .updateok
    wait_for: path=/root/.updateok
- hosts: all
  vars:
    description: "Subscribe OCP"
  tasks:
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
EOF
if [[ $RHSMMODE == "usernamepassword" ]]
then
    echo "    shell: subscription-manager register --username=\"${RHNUSERNAME}\" --password=\"${RHNPASSWORD}\"" >> /home/${AUSERNAME}/subscribe.yml
else
    echo "    shell: subscription-manager register --org=\"${RHNUSERNAME}\" --activationkey=\"${RHNPASSWORD}\"" >> /home/${AUSERNAME}/subscribe.yml
fi
cat <<EOF >> /home/${AUSERNAME}/subscribe.yml
    register: task_result
    until: task_result.rc == 0
    retries: 10
    delay: 30
    ignore_errors: yes
EOF
if [[ $RHSMMODE == "usernamepassword" ]]
then
    echo "  - name: attach sub" >> /home/${AUSERNAME}/subscribe.yml
    echo "    shell: subscription-manager attach --pool=$RHNPOOLID" >> /home/${AUSERNAME}/subscribe.yml
    echo "    register: task_result" >> /home/${AUSERNAME}/subscribe.yml
    echo "    until: task_result.rc == 0" >> /home/${AUSERNAME}/subscribe.yml
    echo "    retries: 10" >> /home/${AUSERNAME}/subscribe.yml
    echo "    delay: 30" >> /home/${AUSERNAME}/subscribe.yml
    echo "    ignore_errors: yes" >> /home/${AUSERNAME}/subscribe.yml
fi
cat <<EOF >> /home/${AUSERNAME}/subscribe.yml
  - name: disable all repos
    shell: subscription-manager repos --disable="*"
  - name: enable rhel7 repo
    shell: subscription-manager repos --enable="rhel-7-server-rpms"
  - name: enable extras repos
    shell: subscription-manager repos --enable="rhel-7-server-extras-rpms"
  - name: enable fastpath repos
    shell: subscription-manager repos --enable="rhel-7-fast-datapath-rpms"
  - name: enable OCP repos
    shell: subscription-manager repos --enable="rhel-7-server-ose-3.5-rpms"
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

npm install -g azure-cli
azure telemetry --disable
cat <<'EOF' > /home/${AUSERNAME}/createvhdcontainer.sh
# $1 is the storage account to create container
mkdir -p ~/.azuresettings/$1
export TENANT=$(< ~/.azuresettings/tenant_id)
export AAD_CLIENT_ID=$(< ~/.azuresettings/aad_client_id)
export AAD_CLIENT_SECRET=$(< ~/.azuresettings/aad_client_secret)
export RESOURCEGROUP=$(< ~/.azuresettings/resource_group)
azure login --service-principal --tenant ${TENANT}  -u ${AAD_CLIENT_ID} -p ${AAD_CLIENT_SECRET}
azure storage account connectionstring show ${1} --resource-group ${RESOURCEGROUP}  > ~/.azuresettings/$1/connection.out
sed -n '/connectionstring:/{p}' < ~/.azuresettings/${1}/connection.out > ~/.azuresettings/${1}/dataline.out
export DATALINE=$(< ~/.azuresettings/${1}/dataline.out)
export AZURE_STORAGE_CONNECTION_STRING=${DATALINE:27}
azure storage container create vhds > ~/.azuresettings/${1}/container.dat
EOF
chmod +x /home/${AUSERNAME}/createvhdcontainer.sh

cat <<EOF > /home/${AUSERNAME}/scgeneric.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: generic
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  storageAccount: sapv1${RESOURCEGROUP}
EOF

cat <<EOF > /home/${AUSERNAME}/openshift-install.sh
export ANSIBLE_HOST_KEY_CHECKING=False
sleep 120
ansible all --module-name=ping > ansible-preinstall-ping.out || true
ansible-playbook  /home/${AUSERNAME}/subscribe.yml
ansible-playbook  /home/${AUSERNAME}/azure-config.yml
echo "${RESOURCEGROUP} Bastion Host is starting ansible BYO" | mail -s "${RESOURCEGROUP} Bastion BYO Install" ${RHNUSERNAME} || true
ansible-playbook  /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml < /dev/null

wget http://master1:8443/api > healtcheck.out
ansible-playbook /home/${AUSERNAME}/postinstall.yml
cd /root
mkdir .kube
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${AUSERNAME}@master1:~/.kube/config /tmp/kube-config
cp /tmp/kube-config /root/.kube/config
mkdir /home/${AUSERNAME}/.kube
cp /tmp/kube-config /home/${AUSERNAME}/.kube/config
chown --recursive ${AUSERNAME} /home/${AUSERNAME}/.kube
rm -f /tmp/kube-config
yum -y install atomic-openshift-clients
echo "setup registry for azure"
oc env dc docker-registry -e REGISTRY_STORAGE=azure -e REGISTRY_STORAGE_AZURE_ACCOUNTNAME=$REGISTRYSTORAGENAME -e REGISTRY_STORAGE_AZURE_ACCOUNTKEY=$REGISTRYKEY -e REGISTRY_STORAGE_AZURE_CONTAINER=registry
sleep 30
echo "Setup Azure PVC"
/home/${AUSERNAME}/createvhdcontainer.sh sapv1${RESOURCEGROUP}
/home/${AUSERNAME}/createvhdcontainer.sh sapv2${RESOURCEGROUP}
oc create -f /home/${AUSERNAME}/scgeneric.yml
oc adm policy add-cluster-role-to-user cluster-admin ${AUSERNAME}
cat /home/${AUSERNAME}/openshift-install.out | tr -cd [:print:] |  mail -s "${RESOURCEGROUP} Install Complete" ${RHNUSERNAME} || true
touch /root/.openshiftcomplete
EOF

cat <<EOF > /home/${AUSERNAME}/.ansible.cfg
[defaults]
remote_tmp     = ~/.ansible/tmp
local_tmp      = ~/.ansible/tmp
host_key_checking = False
forks=30
gather_timeout=60
timeout=240
library = /usr/share/ansible:/usr/share/ansible/openshift-ansible/library
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
library = /usr/share/ansible:/usr/share/ansible/openshift-ansible/library
[ssh_connection]
control_path = ~/.ansible/cp/ssh%%h-%%p-%%r
ssh_args = -o ControlMaster=auto -o ControlPersist=600s -o ControlPath=~/.ansible/cp-%h-%p-%r
EOF


cd /home/${AUSERNAME}
chmod 755 /home/${AUSERNAME}/openshift-install.sh
echo "${RESOURCEGROUP} Bastion Host is starting OpenShift Install" | mail -s "${RESOURCEGROUP} Bastion OpenShift Install Starting" ${RHNUSERNAME} || true
/home/${AUSERNAME}/openshift-install.sh &> /home/${AUSERNAME}/openshift-install.out &
exit 0


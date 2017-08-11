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
export METRICS=${array[22]}
export LOGGING=${array[23]}
export OPSLOGGING=${array[24]}
export FULLDOMAIN=${THEHOSTNAME#*.*}
export WILDCARDFQDN=${RESOURCEGROUP}.${FULLDOMAIN}
export WILDCARDIP=`dig +short ${WILDCARDFQDN}`
export WILDCARDNIP=${WILDCARDIP}.nip.io
export LOGGING_ES_INSTANCES="3"
export OPSLOGGING_ES_INSTANCES="3"
export METRICS_INSTANCES="1"
export LOGGING_ES_SIZE="10"
export OPSLOGGING_ES_SIZE="10"
export METRICS_CASSANDRASIZE="10"
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

ps -ef | grep allinone.sh > cmdline.out

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

mkdir -p /var/lib/origin/openshift.local.volumes
ZEROVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 | head -n1)
parted -s -a optimal ${ZEROVG} mklabel gpt -- mkpart primary xfs 1 -1
sleep 5
mkfs.xfs -f ${ZEROVG}1
echo "${ZEROVG}1  /var/lib/origin/openshift.local.volumes xfs  defaults,gquota  0  0" >> /etc/fstab
mount ${ZEROVG}1

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 | head -n1 )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=$DOCKERVG
VG=docker-vg
DATA_SIZE=95%VG
EXTRA_DOCKER_STORAGE_OPTIONS="--storage-opt dm.basesize=3G"
EOF

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
echo "${RESOURCEGROUP} Host is starting software update" | mail -s "${RESOURCEGROUP} Software Install" ${RHNUSERNAME} || true
# Continue Setting Up Host
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
subscription-manager repos --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-fast-datapath-rpms"
subscription-manager repos --enable="rhel-7-server-ose-3.6-rpms"
yum -y install atomic-openshift-utils git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools nodejs qemu-img
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
  vars_files:
  - vars.yml
  become: yes
  vars:
    azure_conf_dir: /etc/azure
    azure_conf: "{{ azure_conf_dir }}/azure.conf"
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
new_nodes
new_masters

[OSEv3:vars]
osm_controller_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/azure/azure.conf']}
osm_api_server_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/azure/azure.conf']}
openshift_node_kubelet_args={'cloud-provider': ['azure'], 'cloud-config': ['/etc/azure/azure.conf'], 'enable-controller-attach-detach': ['true']}
debug_level=2
console_port=8443
docker_udev_workaround=True
openshift_node_debug_level="{{ node_debug_level | default(debug_level, true) }}"
openshift_master_debug_level="{{ master_debug_level | default(debug_level, true) }}"
openshift_master_access_token_max_seconds=2419200
openshift_hosted_router_replicas=1
openshift_hosted_registry_replicas=1
openshift_master_api_port="{{ console_port }}"
openshift_master_console_port="{{ console_port }}"
openshift_override_hostname_check=true
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
osm_use_cockpit=false
openshift_release=v3.6
openshift_cloudprovider_kind=azure
openshift_node_local_quota_per_fsgroup=512Mi
azure_resource_group=${RESOURCEGROUP}
rhn_pool_id=${RHNPOOLID}
openshift_install_examples=true
deployment_type=openshift-enterprise
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]
openshift_master_manage_htpasswd=false

# default selectors for router and registry services
openshift_router_selector='role=app'
openshift_registry_selector='role=app'

# Select default nodes for projects
osm_default_node_selector="role=app"
ansible_become=yes
ansible_ssh_user=${AUSERNAME}
remote_user=${AUSERNAME}

openshift_master_default_subdomain=${WILDCARDNIP}
#openshift_master_default_subdomain=${WILDCARDZONE}.${FULLDOMAIN}
# osm_default_subdomain=${WILDCARDZONE}.${FULLDOMAIN}
osm_default_subdomain=${WILDCARDNIP}
openshift_use_dnsmasq=true
openshift_public_hostname=${RESOURCEGROUP}.${FULLDOMAIN}

openshift_master_cluster_method=native
openshift_master_cluster_hostname=${RESOURCEGROUP}.${FULLDOMAIN}
openshift_master_cluster_public_hostname=${RESOURCEGROUP}.${FULLDOMAIN}

# Do not install metrics but post install
openshift_metrics_install_metrics=false
openshift_metrics_cassandra_storage_type=pv
openshift_metrics_cassandra_pvc_size="${METRICS_CASSANDRASIZE}G"
openshift_metrics_cassandra_replicas="${METRICS_INSTANCES}"
openshift_metrics_hawkular_nodeselector={"role":"app"}
openshift_metrics_cassandra_nodeselector={"role":"app"}
openshift_metrics_heapster_nodeselector={"role":"app"}

# Do not install logging but post install
openshift_logging_install_logging=false
openshift_logging_es_pv_selector={"usage":"elasticsearch"}
openshift_logging_es_pvc_dynamic="false"
openshift_logging_es_pvc_size="${LOGGING_ES_SIZE}G"
openshift_logging_es_cluster_size=${LOGGING_ES_INSTANCES}
openshift_logging_fluentd_nodeselector={"logging":"true"}
openshift_logging_es_nodeselector={"role":"app"}
openshift_logging_kibana_nodeselector={"role":"app"}
openshift_logging_curator_nodeselector={"role":"app"}

openshift_logging_use_ops=false
openshift_logging_es_ops_pv_selector={"usage":"opselasticsearch"}
openshift_logging_es_ops_pvc_dynamic="false"
openshift_logging_es_ops_pvc_size="${OPSLOGGING_ES_SIZE}G"
openshift_logging_es_ops_cluster_size=${OPSLOGGING_ES_INSTANCES}
openshift_logging_es_ops_nodeselector={"role":"app"}
openshift_logging_kibana_ops_nodeselector={"role":"app"}
openshift_logging_curator_ops_nodeselector={"role":"app"}

[masters]
${RESOURCEGROUP} openshift_hostname=${RESOURCEGROUP} 

[etcd]
${RESOURCEGROUP}

[new_nodes]
[new_masters]

[nodes]
${RESOURCEGROUP} openshift_hostname=${RESOURCEGROUP} openshift_node_labels="{'role':'app','zone':'default','logging':'true'}" openshift_schedulable=true
EOF

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
    shell: subscription-manager repos --enable="rhel-7-server-ose-3.6-rpms"
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
cat <<'EOF' > /home/${AUSERNAME}/create_azure_storage_container.sh
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
azure storage container create ${2} > ~/.azuresettings/${1}/container.dat
EOF
chmod +x /home/${AUSERNAME}/create_azure_storage_container.sh

cat <<EOF > /home/${AUSERNAME}/scgeneric.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: "generic"
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
    volume.beta.kubernetes.io/storage-class: "generic"
    volume.beta.kubernetes.io/storage-provisioner: kubernetes.io/azure-disk
provisioner: kubernetes.io/azure-disk
parameters:
  storageAccount: sapv${RESOURCEGROUP}
EOF

cat <<EOF > /home/${AUSERNAME}/openshift-install.sh
export ANSIBLE_HOST_KEY_CHECKING=False
sleep 120
ansible all --module-name=ping > ansible-preinstall-ping.out || true
ansible-playbook  /home/${AUSERNAME}/subscribe.yml
ansible-playbook  /home/${AUSERNAME}/azure-config.yml
echo "${RESOURCEGROUP} Host is starting ansible BYO" | mail -s "${RESOURCEGROUP} Host starting BYO Install" ${RHNUSERNAME} || true
ansible-playbook  /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml < /dev/null

wget http://${RESOURCEGROUP}:8443/api > healtcheck.out

ansible all -b -m command -a "nmcli con modify eth0 ipv4.dns-search $(domainname -d)"
ansible all -b -m service -a "name=NetworkManager state=restarted"

ansible-playbook /home/${AUSERNAME}/postinstall.yml
cd /root
mkdir .kube
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${AUSERNAME}@${RESOURCEGROUP}:~/.kube/config /tmp/kube-config
cp /tmp/kube-config /root/.kube/config
mkdir /home/${AUSERNAME}/.kube
cp /tmp/kube-config /home/${AUSERNAME}/.kube/config
chown --recursive ${AUSERNAME} /home/${AUSERNAME}/.kube
rm -f /tmp/kube-config
yum -y install atomic-openshift-clients
echo "setup registry for azure"
oc env dc docker-registry -e REGISTRY_STORAGE=azure -e REGISTRY_STORAGE_AZURE_ACCOUNTNAME=$REGISTRYSTORAGENAME -e REGISTRY_STORAGE_AZURE_ACCOUNTKEY=$REGISTRYKEY -e REGISTRY_STORAGE_AZURE_CONTAINER=registry
oc patch dc registry-console -p '{"spec":{"template":{"spec":{"nodeSelector":{"role":"app"}}}}}'
sleep 30
echo "Setup Azure PV"
/home/${AUSERNAME}/create_azure_storage_container.sh sapv${RESOURCEGROUP} "vhds"

echo "Setup Azure PV for metrics & logging"
/home/${AUSERNAME}/create_azure_storage_container.sh sapvlm${RESOURCEGROUP} "loggingmetricspv"

oc adm policy add-cluster-role-to-user cluster-admin ${AUSERNAME}
cat /home/${AUSERNAME}/openshift-install.out | tr -cd [:print:] |  mail -s "${RESOURCEGROUP} Install Complete" ${RHNUSERNAME} || true
touch /root/.openshiftcomplete
touch /home/${AUSERNAME}/.openshiftcomplete
EOF

cat <<EOF > /home/${AUSERNAME}/openshift-postinstall.sh
export ANSIBLE_HOST_KEY_CHECKING=False

DEPLOYMETRICS=${METRICS,,}
DEPLOYLOGGING=${LOGGING,,}
DEPLOYOPSLOGGING=${OPSLOGGING,,}

while true
do
  [ -e /home/${AUSERNAME}/.openshiftcomplete ] && break || sleep 10
done

if [ \${DEPLOYMETRICS} == "true" ]
then
  echo "Deploying Metrics"
  /home/${AUSERNAME}/create_pv.sh sapvlm${RESOURCEGROUP} loggingmetricspv metricspv ${METRICS_INSTANCES} ${METRICS_CASSANDRASIZE}
  ansible-playbook -e "openshift_metrics_install_metrics=\${DEPLOYMETRICS}" /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-cluster/openshift-metrics.yml
fi

if [ \${DEPLOYLOGGING} == "true" ] || [ \${DEPLOYOPSLOGGING} == "true" ]
then
  if [ \${DEPLOYLOGGING} == "true" ]
  then
    /home/${AUSERNAME}/create_pv.sh sapvlm${RESOURCEGROUP} loggingmetricspv loggingpv ${LOGGING_ES_INSTANCES} ${LOGGING_ES_SIZE}
    for ((i=0;i<${LOGGING_ES_INSTANCES};i++))
    do
      oc patch pv/loggingpv-\${i} -p '{"metadata":{"labels":{"usage":"elasticsearch"}}}'
    done
  fi

  if [ \${DEPLOYOPSLOGGING} == true ]
  then
    /home/${AUSERNAME}/create_pv.sh sapvlm${RESOURCEGROUP} loggingmetricspv loggingopspv ${OPSLOGGING_ES_INSTANCES} ${OPSLOGGING_ES_SIZE}
    for ((i=0;i<${OPSLOGGING_ES_INSTANCES};i++))
    do
      oc patch pv/loggingopspv-\${i} -p '{"metadata":{"labels":{"usage":"opselasticsearch"}}}'
    done
  fi
  ansible-playbook -e "openshift_logging_install_logging=\${DEPLOYLOGGING} openshift_logging_use_ops=\${DEPLOYOPSLOGGING}" /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-cluster/openshift-logging.yml
fi

oc create -f /home/${AUSERNAME}/scgeneric.yml
EOF

cat <<'EOF' > /home/${AUSERNAME}/create_pv.sh
# $1 is the storage account to create container
# $2 is the container
# $3 is the blob
# $4 is the times
# $5 is the size in gigabytes

mkdir -p ~/.azuresettings/$1
export TENANT=$(< ~/.azuresettings/tenant_id)
export AAD_CLIENT_ID=$(< ~/.azuresettings/aad_client_id)
export AAD_CLIENT_SECRET=$(< ~/.azuresettings/aad_client_secret)
export RESOURCEGROUP=$(< ~/.azuresettings/resource_group)
azure login --service-principal --tenant ${TENANT}  -u ${AAD_CLIENT_ID} -p ${AAD_CLIENT_SECRET}
azure storage account connectionstring show ${1} --resource-group ${RESOURCEGROUP} > ~/.azuresettings/$1/connection.out
sed -n '/connectionstring:/{p}' < ~/.azuresettings/${1}/connection.out > ~/.azuresettings/${1}/dataline.out
export DATALINE=$(< ~/.azuresettings/${1}/dataline.out)
export AZURE_STORAGE_CONNECTION_STRING=${DATALINE:27}

qemu-img create -f raw /tmp/image.raw ${5}G
mkfs.xfs /tmp/image.raw
qemu-img convert -f raw -o subformat=fixed -O vpc /tmp/image.raw /tmp/image.vhd
rm -f /tmp/image.raw

TIMES=$(expr ${4} - 1)

for ((i=0;i<=TIMES;i++))
do
  azure storage blob upload /tmp/image.vhd ${2} $3-${i}.vhd
  echo "https://${1}.blob.core.windows.net/${2}/$3-${i}.vhd"

  cat<<OEF | oc create -f -
apiVersion: "v1"
kind: "PersistentVolume"
metadata:
  name: "${3}-${i}"
spec:
  capacity:
    storage: "${5}Gi"
  accessModes:
    - "ReadWriteOnce"
  persistentVolumeReclaimPolicy: Delete
  azureDisk:
    diskName: "${3}-${i}"
    diskURI: "https://${1}.blob.core.windows.net/${2}/${3}-${i}.vhd"
    cachingMode: None
    fsType: xfs
    readOnly: false
OEF
done

rm -f /tmp/image.vhd
EOF

chmod +x /home/${AUSERNAME}/create_pv.sh

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
echo "${RESOURCEGROUP} Host is starting OpenShift Install" | mail -s "${RESOURCEGROUP} OpenShift Install Starting" ${RHNUSERNAME} || true
/home/${AUSERNAME}/openshift-install.sh &> /home/${AUSERNAME}/openshift-install.out &
chmod 755 /home/${AUSERNAME}/openshift-postinstall.sh
/home/${AUSERNAME}/openshift-postinstall.sh &> /home/${AUSERNAME}/openshift-postinstall.out &
exit 0

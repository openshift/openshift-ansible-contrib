#!/bin/bash
set -eo pipefail

usage(){
  echo "$0 [-t node|master|infranode] [-u username] [-p /path/to/publicsshkey] [-s vmsize] [-d extradisksize (in G)] [-d extradisksize] [-d...]"
  echo "  -t|--type           node, master or infranode"
  echo "                      If not specified: node"
  echo "  -u|--user           regular user to be created on the host"
  echo "                      If not specified: Current user"
  echo "  -p|--sshpub         path to the public ssh key to be injected in the host"
  echo "                      If not specified: ~/.ssh/id_rsa.pub"
  echo "  -s|--size           VM size"
  echo "                      If not specified:"
  echo "                        * Standard_DS12_v2 for nodes"
  echo "                        * Standard_DS12_v2 for infra nodes"
  echo "                        * Standard_DS3_v2 for masters"
  echo "  -d|--disk           Extra disk size in GB (it can be repeated a few times)"
  echo "                      If not specified: 2x128GB"
  echo "Examples:"
  echo "    $0 -t infranode -d 200 -d 10"
  echo "    $0"
}

login_azure(){
  export TENANT=$(< ~/.azuresettings/tenant_id)
  export AAD_CLIENT_ID=$(< ~/.azuresettings/aad_client_id)
  export AAD_CLIENT_SECRET=$(< ~/.azuresettings/aad_client_secret)
  export RESOURCEGROUP=$(< ~/.azuresettings/resource_group)
  export LOCATION=$(< ~/.azuresettings/location)
  echo "Logging into Azure..."
  azure login \
    --service-principal \
    --tenant ${TENANT} \
    -u ${AAD_CLIENT_ID} \
    -p ${AAD_CLIENT_SECRET} >/dev/null
}

create_nic_azure(){
  echo "Creating the VM NIC..."
  azure network nic create \
    --resource-group ${RESOURCEGROUP} \
    --name ${VMNAME}nic \
    --location ${LOCATION} \
    --subnet-id  "/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCEGROUP}/providers/Microsoft.Network/virtualNetworks/${NET}/subnets/${SUBNET}" \
    --ip-config-name ${IPCONFIG} \
    --internal-dns-name-label ${VMNAME} \
    --tags "displayName=NetworkInterface" >/dev/null
}
create_vm_azure(){
  # VM itself
  echo "Creating the VM..."
  azure vm create \
    --resource-group ${RESOURCEGROUP} \
    --name ${VMNAME} \
    --location ${LOCATION} \
    --image-urn ${IMAGE} \
    --admin-username ${ADMIN} \
    --ssh-publickey-file ${SSHPUB} \
    --vm-size ${VMSIZE} \
    --storage-account-name ${SA} \
    --storage-account-container-name ${SACONTAINER} \
    --os-disk-vhd http://${SA}.blob.core.windows.net/${SACONTAINER}/${VMNAME}.vhd \
    --nic-name ${VMNAME}nic \
    --availset-name ${TYPE}availabilityset \
    --os-type Linux \
    --disable-boot-diagnostics \
    --tags "displayName=VirtualMachine" >/dev/null
}

create_disks_azure(){
  # Disks
  echo "Creating the VM disks..."
  for ((i=0; i<${#DISKS[@]}; i++))
  do
    azure vm disk attach-new \
      --resource-group ${RESOURCEGROUP} \
      --vm-name ${VMNAME} \
      --size-in-gb ${DISKS[i]} \
      --vhd-name ${VMNAME}_datadisk${i}.vhd \
      --storage-account-name ${SA} \
      --storage-account-container-name ${SACONTAINER} \
      --host-caching ${HOSTCACHING} >/dev/null
  done
}

create_host_azure(){
  create_nic_azure
  create_vm_azure
  create_disks_azure
}

create_nsg_azure()
{
  echo "Creating the NGS..."
  azure network nsg create \
    --resource-group ${RESOURCEGROUP} \
    --name ${VMNAME}nsg \
    --location ${LOCATION} \
    --tags "displayName=NetworkSecurityGroup" >/dev/null
}

create_nsg_rules_master_azure()
{
  echo "Creating the NGS rules for a master host..."
  azure network nsg rule create \
    --resource-group ${RESOURCEGROUP} \
    --nsg-name ${VMNAME}nsg \
    --destination-port-range ${APIPORT} \
    --protocol tcp \
    --name default-allow-openshift-master \
    --priority 2000 >/dev/null
}

create_nsg_rules_infranode_azure()
{
  echo "Creating the NGS rules for an infranode..."
  azure network nsg rule create \
    --resource-group ${RESOURCEGROUP} \
    --nsg-name ${VMNAME}nsg \
    --destination-port-range ${HTTP} \
    --protocol tcp \
    --name default-allow-openshift-router-http \
    --priority 1000 >/dev/null
  azure network nsg rule create \
    --resource-group ${RESOURCEGROUP} \
    --nsg-name ${VMNAME}nsg \
    --destination-port-range ${HTTPS} \
    --protocol tcp \
    --name default-allow-openshift-router-https \
    --priority 2000 >/dev/null
}

attach_nsg_azure()
{
  echo "Attaching NGS rules to a NSG..."
  azure network nic set \
    --resource-group ${RESOURCEGROUP} \
    --name ${VMNAME}nic \
    --network-security-group-name ${VMNAME}nsg >/dev/null
}

attach_nic_lb_azure()
{
  echo "Attaching VM NIC to a LB..."
  BACKEND="loadBalancerBackEnd"
  azure network nic ip-config set \
    --resource-group ${RESOURCEGROUP} \
    --nic-name ${VMNAME}nic \
    --name ${IPCONFIG} \
    --lb-address-pool-ids "/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCEGROUP}/providers/Microsoft.Network/loadBalancers/${LB}/backendAddressPools/${BACKEND}" >/dev/null
}

create_node_azure()
{
  common_azure
  export SUBNET="nodeSubnet"
  export SA="sanod${RESOURCEGROUP}"
  create_host_azure
}

create_master_azure()
{
  common_azure
  export SUBNET="masterSubnet"
  export SA="samas${RESOURCEGROUP}"
  export LB="MasterLb${RESOURCEGROUP}"
  create_host_azure
  create_nsg_azure
  create_nsg_rules_master_azure
  attach_nsg_azure
  attach_nic_lb_azure
}

create_infranode_azure()
{
  common_azure
  export SUBNET="infranodeSubnet"
  export SA="sanod${RESOURCEGROUP}"
  export LB=$(azure network lb list ${RESOURCEGROUP} --json | jq -r '.[].name' | grep -v "MasterLb")
  create_host_azure
  create_nsg_azure
  create_nsg_rules_infranode_azure
  attach_nsg_azure
  attach_nic_lb_azure
}

common_azure()
{
  echo "Getting the VM name..."
  export LASTVM=$(azure vm list ${RESOURCEGROUP} | awk "/${TYPE}/ { print \$3 }" | tail -n1)
  if [ $TYPE == 'node' ]
  then
    # Get last 2 numbers and add 1
    LASTNUMBER=$((${LASTVM: -2}+1))
    # Format properly XX
    NEXT=$(printf %02d $LASTNUMBER)
  else
    # Get last number
    NEXT=$((${LASTVM: -1}+1))
  fi
  export VMNAME="${TYPE}${NEXT}"
  export SUBSCRIPTION=$(azure account list --json | jq -r '.[0].id')
}

BZ1469358()
{
  # https://bugzilla.redhat.com/show_bug.cgi?id=1469358
  echo "Workaround for BZ1469358..."
  ansible master1 -b -m fetch -a "src=/etc/origin/master/ca.serial.txt dest=/tmp/ca.serial.txt  flat=true" >/dev/null
  ansible masters -b -m copy -a "src=/tmp/ca.serial.txt dest=/etc/origin/master/ca.serial.txt mode=644 owner=root" >/dev/null
  ansible localhost -b -m file -a "path=/tmp/ca.serial.txt state=absent" >/dev/null
}

add_node_openshift(){
  echo "Adding the new node to the ansible inventory..."
  sudo sed -i "/\[new_nodes\]/a ${VMNAME} openshift_hostname=${VMNAME} openshift_node_labels=\"{'role':'${ROLE}','zone':'default','logging':'true'}\"" /etc/ansible/hosts
  echo "Preparing the host..."
  ansible new_nodes -m shell -a "curl -s https://raw.githubusercontent.com/openshift/openshift-ansible-contrib/master/reference-architecture/azure-ansible/node.sh | bash -x" >/dev/null
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -l new_nodes /home/${USER}/subscribe.yml
  ansible-playbook -l new_nodes -e@vars.yml /home/${USER}/azure-config.yml
  # Scale up
  echo "Scaling up the node..."
  ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml
  echo "Adding the node to the ansible inventory..."
  sudo sed -i "/^${VMNAME}.*/d" /etc/ansible/hosts
  sudo sed -i "/\[nodes\]/a ${VMNAME} openshift_hostname=${VMNAME} openshift_node_labels=\"{'role':'${ROLE}','zone':'default','logging':'true'}\"" /etc/ansible/hosts
}

add_master_openshift(){
  echo "Adding the new master to the ansible inventory..."
  sudo sed -i "/\[new_nodes\]/a ${VMNAME} openshift_hostname=${VMNAME} openshift_node_labels=\"{'role':'${ROLE}','zone':'default','logging':'true'}\" openshift_schedulable=false" /etc/ansible/hosts
  sudo sed -i "/\[new_masters\]/a ${VMNAME} openshift_hostname=${VMNAME} openshift_node_labels=\"{'role':'${ROLE}','zone':'default','logging':'true'}\"" /etc/ansible/hosts
  echo "Preparing the host..."
  ansible new_masters -m shell -a "curl -s https://raw.githubusercontent.com/openshift/openshift-ansible-contrib/master/reference-architecture/azure-ansible/master.sh | bash -x"
  # Copy ssh files as master.sh does
  ansible master1 -m fetch -a "src=/home/${USER}/.ssh/id_rsa.pub dest=/tmp/key.pub flat=true" >/dev/null
  ansible master1 -m fetch -a "src=/home/${USER}/.ssh/id_rsa dest=/tmp/key flat=true" >/dev/null
  # User
  ansible new_masters -m copy -a "src=/tmp/key.pub dest=/home/${ADMIN}/.ssh/id_rsa.pub mode=600  owner=${ADMIN}" >/dev/null
  ansible new_masters -m copy -a "src=/tmp/key dest=/home/${ADMIN}/.ssh/id_rsa mode=600  owner=${ADMIN}" >/dev/null
  # Root
  ansible new_masters -b -m copy -a "src=/tmp/key.pub dest=/root/.ssh/id_rsa.pub mode=600 owner=root" >/dev/null
  ansible new_masters -b -m copy -a "src=/tmp/key dest=/root/.ssh/id_rsa mode=600 owner=root" >/dev/null
  # Cleanup
  ansible localhost -b -m file -a "path=/tmp/key state=absent" >/dev/null
  ansible localhost -b -m file -a "path=/tmp/key.pub state=absent" >/dev/null
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -l new_masters /home/${USER}/subscribe.yml
  ansible-playbook -l new_masters -e@vars.yml /home/${USER}/azure-config.yml
  echo "Scaling up the master..."
  ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-master/scaleup.yml
  echo "Copying htpasswd..."
  ansible master1 -m fetch -a "src=/etc/origin/master/htpasswd dest=/tmp/htpasswd flat=true" >/dev/null
  ansible new_masters -b -m copy -a "src=/tmp/htpasswd dest=/etc/origin/master/htpasswd mode=600  owner=root" >/dev/null
  ansible localhost -m file -a "path=/tmp/htpasswd state=absent" >/dev/null
  echo "Adding the master to the ansible inventory..."
  sudo sed -i "/^${VMNAME}.*/d" /etc/ansible/hosts
  sudo sed -i "/\[masters\]/a ${VMNAME} openshift_hostname=${VMNAME} openshift_node_labels=\"{'role': '${ROLE}'}\"" /etc/ansible/hosts
  sudo sed -i "/\[nodes\]/a ${VMNAME} openshift_hostname=${VMNAME} openshift_node_labels=\"{'role':'${ROLE}','zone':'default','logging':'true'}\" openshift_schedulable=false" /etc/ansible/hosts
}

# Default values
export IPCONFIG="ipconfig1"
export HOSTCACHING="None"
export NET="openshiftVnet"
export IMAGE="RHEL"
export SACONTAINER="openshiftvmachines"
export APIPORT="8443"
export HTTP="80"
export HTTPS="443"

# Default values that can be overwritten with flags
DEFTYPE="node"
DEFSSHPUB="/home/${USER}/.ssh/id_rsa.pub"
DEFVMSIZENODE="Standard_DS12_v2"
DEFVMSIZEINFRANODE="Standard_DS12_v2"
DEFVMSIZEMASTER="Standard_DS3_v2"
declare -a DEFDISKS=(128 128)

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  opt="$1"
  shift;
  current_arg="$1"
  if [[ "$current_arg" =~ ^-{1,2}.* ]]; then
    echo "ERROR: You may have left an argument blank. Double check your command."
    usage; exit 1
  fi
  case "$opt" in
    "-t"|"--type")
      TYPE="${1,,}"
      shift
      ;;
    "-u"|"--user")
      ADMIN="$1"
      shift
      ;;
    "-p"|"--sshpub")
      SSHPUB="$1"
      shift
      ;;
    "-s"|"--size")
      VMSIZE="$1"
      shift
      ;;
    "-d"|"--disk")
      DISKS+=("$1")
      shift
      ;;
    *)
      echo "ERROR: Invalid option: \""$opt"\"" >&2
      usage
      exit 1
      ;;
  esac
done

export TYPE=${TYPE:-${DEFTYPE}}
export ADMIN=${ADMIN:-${USER}}
export SSHPUB=${SSHPUB:-${DEFSSHPUB}}
export DISKS=("${DISKS[@]:-${DEFDISKS[@]}}")

azure telemetry --disable 1>/dev/null
echo "Updating atomic-openshift-utils..."
sudo yum update -y atomic-openshift-utils 1>/dev/null
login_azure
BZ1469358

case "$TYPE" in
  'node')
    # NODE
    export VMSIZE=${VMSIZE:-$DEFVMSIZENODE}
    export ROLE="app"
    echo "Creating a new node..."
    create_node_azure
    echo "Adding the node to OCP..."
    add_node_openshift
    ;;
  'infranode')
    # INFRANODE
    export VMSIZE=${VMSIZE:-$DEFVMSIZEINFRANODE}
    export ROLE="infra"
    echo "Creating a new infranode..."
    create_infranode_azure
    echo "Adding the node to OCP..."
    add_node_openshift
    ;;
  'master')
    # MASTER
    export VMSIZE=${VMSIZE:-$DEFVMSIZEMASTER}
    export ROLE="master"
    echo "Creating a new master..."
    create_master_azure
    echo "Adding the master to OCP..."
    add_master_openshift
    ;;
  *)
    echo "Wrong argument"
    ;;
esac

BZ1469358

echo "Done"

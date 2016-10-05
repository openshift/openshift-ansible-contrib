
### CONFIG ###

# Path to a RHEL image on local machine, downloaded from Red Hat Customer Portal
RHEL_IMAGE_PATH="${HOME}/Downloads/rhel-guest-image-7.2-20160302.0.x86_64.qcow2"

# Username and password for Red Hat Customer Portal
RH_USERNAME='user@example.com'
RH_PASSWORD='xxx'
# Pool ID which shall be used to register the pre-registered image
RH_POOL_ID='xxx'

# Project ID and zone settings for Google Cloud
GCLOUD_PROJECT='project-1'
GCLOUD_ZONE='us-central1-a'

# DNS domain which will be configured in Google Cloud DNS
DNS_DOMAIN='ocp.example.com'
# DNS name for the Master service
MASTER_DNS_NAME='master.ocp.example.com'
# Internal DNS name for the Master service
INTERNAL_MASTER_DNS_NAME='internal-master.ocp.example.com'
# Domain name for the OpenShift applications
OCP_APPS_DNS_NAME='apps.ocp.example.com'
# Paths on the local system for the certificate files. If empty, self-signed
# certificate will be generated
MASTER_HTTPS_CERT_FILE="${HOME}/Downloads/master.ose.example.com.pem"
MASTER_HTTPS_KEY_FILE="${HOME}/Downloads/master.ose.example.com.key"

## DEFAULT VALUES ##

OCP_VERSION='3.3'

CONSOLE_PORT='443'

OCP_NETWORK='ocp-network'

MASTER_MACHINE_TYPE='n1-standard-2'
NODE_MACHINE_TYPE='n1-standard-2'
INFRA_NODE_MACHINE_TYPE='n1-standard-2'
BASTION_MACHINE_TYPE='n1-standard-1'

MASTER_INSTANCE_TEMPLATE='master-template'
NODE_INSTANCE_TEMPLATE='node-template'
INFRA_NODE_INSTANCE_TEMPLATE='infra-node-template'

BASTION_INSTANCE='bastion'

MASTER_INSTANCE_GROUP='ocp-master'
# How many instances should be created for this group
MASTER_INSTANCE_GROUP_SIZE='3'
MASTER_NAMED_PORT_NAME='web-console'
INFRA_NODE_INSTANCE_GROUP='ocp-infra'
INFRA_NODE_INSTANCE_GROUP_SIZE='2'
NODE_INSTANCE_GROUP='ocp-node'
NODE_INSTANCE_GROUP_SIZE='2'

NODE_DOCKER_DISK_SIZE='25'
NODE_DOCKER_DISK_POSTFIX='-docker'
NODE_OPENSHIFT_DISK_SIZE='50'
NODE_OPENSHIFT_DISK_POSTFIX='-openshift'

MASTER_HTTPS_LB_HEALTH_CHECK='master-https-lb-health-check'
MASTER_HTTPS_LB_BACKEND='master-https-lb-backend'
MASTER_HTTPS_LB_MAP='master-https-lb-map'
MASTER_HTTPS_LB_CERT='master-https-lb-cert'
MASTER_HTTPS_LB_TARGET='master-https-lb-target'
MASTER_HTTPS_LB_IP='master-https-lb-ip'
MASTER_HTTPS_LB_RULE='master-https-lb-rule'

MASTER_NETWORK_LB_HEALTH_CHECK='master-network-lb-health-check'
MASTER_NETWORK_LB_POOL='master-network-lb-pool'
MASTER_NETWORK_LB_IP='master-network-lb-ip'
MASTER_NETWORK_LB_RULE='master-network-lb-rule'

ROUTER_NETWORK_LB_HEALTH_CHECK='router-network-lb-health-check'
ROUTER_NETWORK_LB_POOL='router-network-lb-pool'
ROUTER_NETWORK_LB_IP='router-network-lb-ip'
ROUTER_NETWORK_LB_RULE='router-network-lb-rule'

REGISTRY_BUCKET="gs://${GCLOUD_PROJECT}-openshift-docker-registry"

TEMP_INSTANCE='ocp-rhel-temp'

GOOGLE_CLOUD_SDK_VERSION='129.0.0'

# Firewall rules in a form:
# ['name']='parameters for "gcloud compute firewall-rules create"'
# For all possible parameters see: gcloud compute firewall-rules create --help
declare -A FW_RULES=(
    ['icmp']='--allow icmp'
    ['ssh-external']='--allow tcp:22 --target-tags ssh-external'
    ['ssh-internal']='--allow tcp:22 --source-tags bastion'
    ['master-internal']='--allow tcp:53,udp:53,tcp:2224,tcp:2379,tcp:2380,tcp:4001,udp:4789,udp:5404,udp:5405,tcp:8053,udp:8053,tcp:8444,tcp:10250,tcp:10255,udp:10255,tcp:24224,udp:24224 --source-tags ocp --target-tags ocp-master'
    ['master-external']="--allow tcp:${CONSOLE_PORT} --target-tags ocp-master"
    ['node-internal']='--allow udp:4789,tcp:10250,tcp:10255,udp:10255 --source-tags ocp --target-tags ocp-node,ocp-infra-node'
    ['infra-node-internal']='--allow tcp:5000 --source-tags ocp --target-tags ocp-infra-node'
    ['infra-node-external']='--allow tcp:80,tcp:443,tcp:1936 --target-tags ocp-infra-node'
)
BASTION_SSH_FW_RULE='bastion-ssh-to-external-ip'

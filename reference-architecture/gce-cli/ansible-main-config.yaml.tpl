---
gcloud_project: ${GCLOUD_PROJECT}
gcloud_region: ${GCLOUD_REGION}
gcloud_zone: ${GCLOUD_ZONE}
prefix: ${OCP_PREFIX}
dns_domain: ${DNS_DOMAIN}
master_dns_name: ${MASTER_DNS_NAME}
internal_master_dns_name: ${INTERNAL_MASTER_DNS_NAME}
ocp_apps_dns_name: ${OCP_APPS_DNS_NAME}
wildcard_zone: ${OCP_APPS_DNS_NAME}
public_hosted_zone: ${DNS_DOMAIN}
rhel_image_path: ${RHEL_IMAGE_PATH}
console_port: ${CONSOLE_PORT}
master_https_key_file: ${MASTER_HTTPS_KEY_FILE}
master_https_cert_file: ${MASTER_HTTPS_CERT_FILE}
master_instance_group_size: ${MASTER_INSTANCE_GROUP_SIZE}
infra_node_instance_group_size: ${INFRA_NODE_INSTANCE_GROUP_SIZE}
node_instance_group_size: ${NODE_INSTANCE_GROUP_SIZE}
bastion_machine_type: ${BASTION_MACHINE_TYPE}
master_machine_type: ${MASTER_MACHINE_TYPE}
node_machine_type: ${NODE_MACHINE_TYPE}
bastion_disk_size: ${BASTION_DISK_SIZE}
master_boot_disk_size: ${MASTER_BOOT_DISK_SIZE}
node_boot_disk_size: ${NODE_BOOT_DISK_SIZE}
node_docker_disk_size: ${NODE_DOCKER_DISK_SIZE}
node_openshift_disk_size: ${NODE_OPENSHIFT_DISK_SIZE}
gcs_registry_bucket: ${REGISTRY_BUCKET}
openshift_sdn: ${OPENSHIFT_SDN}
openshift_master_identity_providers: ${OCP_IDENTITY_PROVIDERS}


rhel_image: '{{ rhel_image_path | basename | regex_replace("^(.*)\.qcow2$", "\1") }}'
rhel_image_gce: '{{ rhel_image | replace(".", "-") | replace("_", "-") }}'
gold_image: '{{ rhel_image_gce }}-gold'
gold_image_family: 'rhel-guest-gold'

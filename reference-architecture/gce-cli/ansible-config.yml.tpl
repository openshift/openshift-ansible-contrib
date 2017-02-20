---
public_hosted_zone: ${DNS_DOMAIN}
wildcard_zone: ${OCP_APPS_DNS_NAME}
openshift_master_cluster_public_hostname: ${MASTER_DNS_NAME}
openshift_master_cluster_hostname: ${INTERNAL_MASTER_DNS_NAME}
console_port: ${CONSOLE_PORT}
openshift_hosted_router_replicas: ${INFRA_NODE_INSTANCE_GROUP_SIZE}
openshift_hosted_registry_replicas: ${INFRA_NODE_INSTANCE_GROUP_SIZE}
openshift_deployment_type: openshift-enterprise
ansible_pkg_mgr: yum
gcs_registry_bucket: ${REGISTRY_BUCKET}
gce_project_id: ${GCLOUD_PROJECT}
gce_network_name: ${OCP_NETWORK}
openshift_master_identity_providers: ${OCP_IDENTITY_PROVIDERS}
openshift_sdn: ${OPENSHIFT_SDN}

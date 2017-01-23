---
public_hosted_zone: ${DNS_DOMAIN}
wildcard_zone: ${OS_APPS_DNS_NAME}
openshift_master_cluster_public_hostname: ${MASTER_DNS_NAME}
openshift_master_cluster_hostname: ${INTERNAL_MASTER_DNS_NAME}
console_port: ${CONSOLE_PORT}
openshift_hosted_router_replicas: ${INFRA_NODE_INSTANCE_GROUP_SIZE}
openshift_hosted_registry_replicas: ${INFRA_NODE_INSTANCE_GROUP_SIZE}
openshift_deployment_type: ${OS_DEPLOYMENT_TYPE}
openshift_release: ${OS_VERSION}
containerized: ${OS_CONTAINERIZED}
ansible_pkg_mgr: yum
gcs_registry_bucket: ${REGISTRY_BUCKET}
gce_project_id: ${GCLOUD_PROJECT}
gce_network_name: ${OS_NETWORK}
openshift_master_identity_providers: ${OS_IDENTITY_PROVIDERS}

imports:
- path: deployment-core.jinja
resources:
- name: deployment-core
  type: deployment-core.jinja
  properties:
    prefix: ${OCP_PREFIX}
    project: ${GCLOUD_PROJECT}
    region: ${GCLOUD_REGION}
    zone: ${GCLOUD_ZONE}
    gold_image: ${GOLD_IMAGE}
    console_port: ${CONSOLE_PORT}
    bastion_machine_type: ${BASTION_MACHINE_TYPE}
    bastion_disk_size: ${BASTION_DISK_SIZE}
    master_machine_type: ${MASTER_MACHINE_TYPE}
    master_boot_disk_size: ${MASTER_BOOT_DISK_SIZE}
    node_machine_type: ${NODE_MACHINE_TYPE}
    node_boot_disk_size: ${NODE_BOOT_DISK_SIZE}
    master_instance_group_size: ${MASTER_INSTANCE_GROUP_SIZE}
    infra_node_instance_group_size: ${INFRA_NODE_INSTANCE_GROUP_SIZE}
    node_instance_group_size: ${NODE_INSTANCE_GROUP_SIZE}

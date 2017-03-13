imports:
- path: deployment-net.jinja
resources:
- name: deployment-net
  type: deployment-net.jinja
  properties:
    prefix: ${OCP_PREFIX}
    region: ${GCLOUD_REGION}
    console_port: ${CONSOLE_PORT}

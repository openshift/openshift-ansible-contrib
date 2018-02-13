OpenShift Grafana
=================

OpenShift Grafana Installation

Requirements
------------


Role Variables
--------------

For default values, see [`defaults/main.yaml`](defaults/main.yaml).

- `openshift_grafana_state`: present - install/update. absent - uninstall.

- `openshift_grafana_namespace`: project (i.e. namespace) where the components will be
  deployed.

- `openshift_grafana_node_selector`: Selector for the nodes grafana will be deployed on.

- `openshift_grafana_<COMPONENT>_image_prefix`: specify image prefix for the component

- `openshift_grafana_<COMPONENT>_image_version`: specify image version for the component

- `openshift_grafana_hostname`: specify the hostname for the route to grafana `grafana-{{openshift_grafana_namespace}}.{{openshift_master_default_subdomain}}`

## Additional variables to control resource limits
Cpu and memory limits and requests by setting the corresponding role variable:
```
openshift_grafana_(limits|requests)_(memory|cpu): <VALUE>
```
e.g
```
openshift_grafana_limits_memory: 1Gi
openshift_grafana_requests_cpu: 100
```

Dependencies
------------

openshift_facts


Example Playbook
----------------

```
- name: Configure openshift-grafana
  hosts: oo_first_master
  roles:
  - role: openshift_grafana
```

License
-------

Apache License, Version 2.0

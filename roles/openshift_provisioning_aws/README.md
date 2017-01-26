OpenShift Provisioning AWS
=========

This is an opinionated AWS provisioning role. It includes other more
specialized roles and presents a simplified interface for provisioning
compared to using the individual specialized roles.

Requirements
------------

boto

Role Variables
--------------

| Name                                   | Default value                                       |                     |
|----------------------------------------|-----------------------------------------------------|---------------------|

Dependencies
------------

openshift_provisioning_aws_facts
openshift_provisioning_aws_vpc

Example Playbook
----------------

```
- hosts: localhost
  become: no
  gather_facts: no
  vars:
    openshift_cluster_id: test
    openshift_env_id: test
  roles:
  - openshift_provisioning_aws
  
```

License
-------

Apache License, Version 2.0

Author Information
-----------------
TODO

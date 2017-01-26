OpenShift Provisioning AWS VPC
=========

This is a specialized role for provisioning AWS VPCs and is meant for advanced use only. The openshift_provisioning_aws role provides a simplified interface for basic and opinionated provisioning and should be preferred to this role.

Requirements
------------

boto

Role Variables
--------------

| Name                                   | Default value                                       |                     |
|----------------------------------------|-----------------------------------------------------|---------------------|
| openshift_provisioning_aws_vpc_id      | UNDEF                                               | Existing VPC ID to use |
| openshift_provisioning_aws_vpc_name    | openshift_<openshift_cluster_id>_<openshift_env_id> | name for the created vpc |
| openshift_provisioning_aws_vpc_cidr    | 172.18.0.0/16 | cidr for the created vpc |
| openshift_provisioning_aws_vpc_tenancy | default | type of tenancy for VPC (default or dedicated) |

Dependencies
------------

openshift_provisioning_aws_facts

Example Playbook
----------------
Un-managed pre-existing VPC

```
- hosts: localhost
  become: no
  gather_facts: no
  vars:
    openshift_cluster_id: test
    openshift_env_id: test
    openshift_provisioning_aws_vpc_id: my_vpc_id
  roles:
  - openshift_provisioning_aws_facts
  - openshift_provisioning_aws_vpc

```

Managed VPC
```
- hosts: localhost
  become: no
  gather_facts: no
  vars:
    openshift_cluster_id: test
    openshift_env_id: test
  roles:
  - openshift_provisioning_aws_facts
  - openshift_provisioning_aws_vpc

```

License
-------

Apache License, Version 2.0

Author Information
-----------------
TODO

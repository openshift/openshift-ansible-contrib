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
| openshift_cluster_id                   | UNDEF | cluster identifier       |
| openshift_env_id                       | UNDEF | env identifier           |
| openshift_provisioning_aws_region      | UNDEF | aws region to use        |
| openshift_provisioning_aws_vpc_name    | UNDEF | name for the created vpc |
| openshift_provisioning_aws_vpc_cidr    | UNDEF | cidr for the created vpc |
| openshift_provisioning_aws_vpc_tenancy | UNDEF | type of tenancy for VPC (default or dedicated) |

Dependencies
------------

None

Example Playbook
----------------
```
- hosts: localhost
  become: no
  gather_facts: no
  vars:
    openshift_cluster_id: test_cluster
    openshift_env_id: test_env
    openshift_provisioning_aws_region: us-east-1
    openshift_provisioning_aws_vpc_name: my_vpc
    openshift_provisioning_aws_vpc_cidr: 172.18.0.0/16
    openshift_provisioning_aws_vpc_tenancy: default
  roles:
  - openshift_provisioning_aws_vpc

```

License
-------

Apache License, Version 2.0

Author Information
-----------------
TODO

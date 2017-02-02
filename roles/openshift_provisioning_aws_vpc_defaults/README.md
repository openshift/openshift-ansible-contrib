OpenShift Provisioning AWS VPC Defaults
=========

This role provides default values for AWS VPCs provisioned for OpenShift

Requirements
------------

boto

Role Variables
--------------

| Name                                   | Default value                                       |                     |
|----------------------------------------|-----------------------------------------------------|---------------------|
| openshift_provisioning_aws_vpc_name    | openshift_<openshift_cluster_id>_<openshift_env_id> | name for the created vpc |
| openshift_provisioning_aws_vpc_cidr    | 172.18.0.0/16 | cidr for the created vpc |
| openshift_provisioning_aws_vpc_tenancy | default | type of tenancy for VPC (default or dedicated) |

Dependencies
------------

openshift_provisioning_aws_defaults

Example Playbook
----------------

TODO

License
-------

Apache License, Version 2.0

Author Information
-----------------
TODO

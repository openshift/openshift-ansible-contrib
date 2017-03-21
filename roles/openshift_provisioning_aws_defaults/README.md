OpenShift Provisioning AWS Defaults
=========

Provides common defaults for other AWS provisioning roles.

Requirements
------------

None

Role Variables
--------------

| Name                                   | Default value |                     |
|----------------------------------------|---------------|---------------------|
| openshift_cluster_id                   | UNDEF         | Cluster ID (combination of openshift_cluster_id and openshift_env_id are expected to be unique for all OpenShift clusters) |
| openshift_env_id                       | UNDEF         | Environment ID      |
| openshift_provisioning_aws_region      | us-east-1     | ec2 region to use   |

Dependencies
------------

None

Example Playbook
----------------

```
- hosts: localhost
  become: no
  gather_facts: no
  roles:
  - openshift_provisioning_aws_defaults
```

Running Tests
-------------

```
molecule test
```

License
-------

Apache License, Version 2.0

Author Information
-----------------
TODO

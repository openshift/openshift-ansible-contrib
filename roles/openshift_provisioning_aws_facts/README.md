OpenShift Provisioning AWS Facts
=========

Provides common facts and defaults for other AWS provisioning roles.

Requirements
------------

None

Role Variables
--------------

| Name                                   | Default value                                       |                     |
|----------------------------------------|-----------------------------------------------------|---------------------|
| openshift_cluster_id                   | default                                             | Cluster ID (combination of openshift_cluster_id and openshift_env_id are expected to be unique for all OpenShift clusters) |
| openshift_env_id                       | default                                             | Environment ID      |
| openshift_provisioning_aws_region      | us-east-1                                           | ec2 region to use |

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
  - openshift_provisioning_aws_facts
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

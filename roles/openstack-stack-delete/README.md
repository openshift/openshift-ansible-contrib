# openstack-stack-delete

Role used to decomission, delete, a Heat provisioned OpenStack Stack.

## Test

Make sure to set the `stack_name` inventory variable, then run:

```
> ansible-playbook -i <inventory> roles/openstack-stack-delete/tests/test.yml

```
... where `roles/openstack-stack-delete` is the path from the top level of this repo.

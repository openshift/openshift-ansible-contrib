## **NOTE: This repository contains unsupported scripts. Refer to the official documentation [Deploying and Managing OpenShift 3.9 on Google Cloud Platform](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_google_cloud_platform/)**

To simplify the infrastructure creation/deletion, a couple of scripts has been
created by wrapping up the commands on the official documentation.

# Requisites
A proper variables file is required. See [Environment configuration section in the official documentation](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_google_cloud_platform/#environment_configuration) for more information.

An example file [infrastructure.vars](infrastructure.vars) has been included as
a reference.

**NOTE:** A [bastion.vars](bastion.vars) file is created as well to help bastion
hosts tasks.

**IMPORTANT:** The image is not created as part of this process. It should be
created prior to running the
[create_infrastructure.sh](create_infrastructure.sh) script.

## [create_infrastructure.sh](create_infrastructure.sh)
This script creates all the required infrastructure in GCP as explained in the
official documentation, including CNS nodes.

Usage:
```
./create_infrastructure.sh <vars_file>
```

After the infrastructure has been created, configure your `~/.ssh/config` as
explained in the [reference architecture](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_google_cloud_platform/#configuring_ssh_config_to_use_bastion_as_jumphost)

Copy the [bastion.sh](bastion.sh) and your bastion.vars files to the
bastion host:

```
scp bastion.sh my.vars user@BASTIONIP:
```

Connect to the bastion host and run the bastion.sh script:

```
ssh user@BASTIONIP
./bastion.sh ./my.vars
```

**NOTE:** The last step reboots all the nodes and the script ends as it seems to
fail.

After it finishes run the installation prerrequisites and the installation
itself from the bastion host (using tmux is optional but recommended):

```
tmux
ansible-playbook -i inventory \
  /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -i inventory \
  /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
```

## [delete_infrastructure.sh](delete_infrastructure.sh)
This script removes all the required infrastructure in GCP as explained in the
official documentation, including CNS nodes.

USE IT WITH CAUTION AS SETTING A VARIABLE INCORRECTLY CAN HAVE DISASTROUS
CONSEQUENCES

First, remove the PVs (as cluster-admin):

```
for i in $(oc get pv -o name); do
  oc delete $i
done
```

Unsubscribe the instances from the bastion host:

```
sudo subscription-manager remove --all
sudo subscription-manager unregister

ansible all -b -i inventory -m shell -a "subscription-manager remove --all"
ansible all -b -i inventory -m shell -a "subscription-manager unregister"
```

And remove all the infrastructure objects (from your workstation)

```
./delete_infrastructure.sh <vars_file>
```

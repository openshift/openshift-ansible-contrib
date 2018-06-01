# Reference Architecture:  OpenShift Container Platform on Red Hat Virtualization
This subdirectory contains the Ansible playbooks used to deploy 
an OpenShift Container Platform environment on Red Hat Virtualization

Current versions:

* OpenShift Container Platform 3.9
* Red Hat Virtualization 4.2 (beta)
* Red Hat Enterprise Linux 7.5

## Overview
This reference architecture provides a comprehensive example demonstrating how Red Hat OpenShift Container Platform
can be set up to take advantage of the native high availability capabilities of Kubernetes and Red Hat Virtualization
in order to create a highly available OpenShift Container Platform environment.

## Prerequisites

### Preparing the Bastion Host

Ensure the bastion host is running Red Hat Enterprise Linux 7 and is registered and
subscribed to at least the following channels:

* rhel-7-server-rpms
* rhel-7-server-extras-rpms

The following commands should be issued from the bastion host (by preference from a
regular user account with sudo access):

```
$ sudo yum install -y git ansible
$ mkdir -p ~/git
$ cd ~/git/ && git clone https://github.com/openshift/openshift-ansible-contrib
$ cd ~/git/openshift-ansible-contrib && ansible-playbook playbooks/deploy-host.yaml -e provider=rhv
```

All subsequent work will be performed from the reference-architecture/rhv-ansible sub directory.

### oVirt Ansible roles
RPMs providing the [oVirt Ansible roles](https://github.com/ovirt/ovirt-ansible) will be installed
into your system's Ansible role path, typically `/usr/share/ansible/roles`.
These are required for playbooks to interact with RHV/oVirt to create VMs.

### Dynamic Inventory
A copy of [`ovirt4.py`](inventory/ovirt4.py) from the Ansible project is provided under the [`reference-architecture/rhv-ansible/inventory`](inventory) directory. This script will, given credentials to a RHV 4 engine, populate the Ansible inventory with facts about all virtual machines in the cluster. In order to use this dynamic inventory, see the [`ovirt.ini.example`](inventory/ovirt.ini.example) file, either providing the relevant Python secrets via environment variables, or by copying it to `ovirt.ini` and filling in the values.

This reference architecture uses the dynamic inventory to establish DNS entries in the form of either an /etc/hosts file or nsupdate script for the provisioned virtual machines. All other playbooks are performed using a static inventory. If DNS updates are to be performed manually, the dynamic inventory script may be unnecessary.

### Red Hat Virtualization Certificate
A copy of the `/etc/pki/ovirt-engine/ca.pem` from the RHV engine will need to be added to the
`reference-architecture/rhv-ansible` directory. Replace the example server in the following command to download the certificate:

```
$ curl --output ca.pem 'http://engine.example.com/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA'

```

### RHEL QCOW2 Image
The oVirt-ansible role, oVirt.image-template requires a URL to download a QCOW2 KVM image to use as
the basis for the VMs on which OpenShift will be installed.

If a CentOS image is desired, a suitable URL is commented out in the static inventory under `localhost`.

If a RHEL image is preferred, log in at <https://access.redhat.com/>, navigate to Downloads, Red Hat Enterprise Linux,
select the latest release (at this time, 7.5), and copy the URL for "KVM Guest Image". If possible, download
this file to the bastion host, and set the `image_path` variable to its location. Otherwise, it is
preferable to download the image to a local server, e.g. the /pub/ directory of a satellite if
available, and provide that URL to the Ansible playbook, because the download link will expire
after a short while and need to be refreshed.

### Ansible Vault
A number of variables used by the OpenShift and oVirt Ansible installers are prefixed with `vault_`. Those 
variables are expected to be populated in an Ansible Vault file and stored in a safe location.
For more information, please see the
[Ansible Vault Documentation](http://docs.ansible.com/ansible/2.5/user_guide/vault.html).

## Usage

### Populate Values

Three files will need to be copied from examples and edited:

* As mentioned above, protected values should be created in an ansible vault, e.g. [`vault.yaml`](vault.yaml) in the user's home directory. A template is provided in the examples directory. This will hold RHV credentials and, in the case of RHEL hosts, subscription credentials.

* The [`ovirt-infra-vars.yaml`](ovirt-infra-vars.yaml) file defines the virtual machines created by the `ovirt-vm-infra.yaml` playbook. The host names created here must match those in the static inventory.

* A copy of a static inventory is provided as [yaml](example/inventory.yaml) or [ini](example/inventory), populated with hosts in the example.com domain along with variables pertaining to the reference architecture. This inventory should be added to /etc/ansible/hosts (or added manually using the -i flag during each `ansible-playbook` run).

### Set up virtual machines in RHV
From the `reference-architecture/rhv-ansible` directory, run

```
ansible-playbook -e@~/vault.yaml playbooks/ovirt-vm-infra.yaml
```
### Optionally output DNS entries and update DNS records with dynamically provisioned information (Note the use of two inventories here, localhost variables like `openshift_master_default_subdomain` are required to form the output files)

```
ansible-playbook -e@~/vault.yaml -i /etc/ansible/hosts -i inventory playbooks/output-dns.yaml

```

### Set up OpenShift Container Platform on the VMs from the previous step

```
ansible-playbook -e@~/vault.yaml /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml

ansible-playbook -e@~/vault.yaml /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
```


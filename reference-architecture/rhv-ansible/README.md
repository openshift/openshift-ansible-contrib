# Reference Architecture:  OpenShift Container Platform on Red Hat Virtualization
This repository contains the Ansible playbooks used to deploy 
an OpenShift Container Platform environment on Red Hat Virtualization

## Overview
This reference architecture provides a comprehensive example demonstrating how Red Hat OpenShift Container Platform
can be set up to take advantage of the native high availability capabilities of Kubernetes and Red Hat Virtualization
in order to create a highly available OpenShift Container Platform environment.

## Prerequisites

### Preparing the Deployment Host

Ensure the deployment host (aka workstation host) is running Red Hat Enterprise
Linux 7 and is registered and subscribed to at least the following channels:

* rhel-7-server-rpms
* rhel-7-server-extras-rpms

The following commands should be issued from the deployment host (by preference from a
regular user account with sudo access):

```
$ sudo yum install -y git ansible
$ mkdir -p ~/git
$ cd ~/git/ && git clone https://github.com/openshift/openshift-ansible-contrib
$ cd ~/git/openshift-ansible-contrib && ansible-playbook playbooks/deploy-host.yaml -e provider=rhv
```

### oVirt Ansible roles
A copy of the [oVirt Ansible](https://github.com/ovirt/ovirt-ansible) repository will be cloned in a directory
alongside this repository. Roles from within the ovirt-ansible repository will be called by playbooks in this one.

### Dynamic Inventory
A copy of `ovirt4.py` from the Ansible project is provided under the inventory directory. This script will, given credentials to a RHV 4 engine, populate the Ansible inventory with facts about all virtual machines in the cluster. In order to use this dynamic inventory, see the `ovirt.ini.example` file, either providing the relevant Python secrets via environment variables, or by copying it to `ovirt.ini` and filling in the values.

### Red Hat Virtualization Certificate
A copy of the `/etc/pki/ovirt-engine/ca.pem` from the RHV engine will need to be added to the
`reference-architecture/rhv-ansible` directory. Replace the example server in the following command to download the certificate:

```
$ curl --output ca.pem 'http://engine.example.com/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA'

```

### RHEL QCOW2 Image
The ovirt-ansible role, ovirt-image-template requires a URL to download a QCOW2 KVM image to use as
the basis for the VMs on which OpenShift will be installed. If a CentOS image is desired, a suitable
URL is commented out in the variable file, `playbooks/vars/ovirt-infra-vars.yaml`. If a RHEL image
is preferred, log in at <https://access.redhat.com/>, navigate to Downloads, Red Hat Enterprise Linux,
select the latest release (at this time, 7.3), and copy the URL for "KVM Guest Image". It is
preferable to download the image to a local server, e.g. the /pub/ directory of a satellite if
available, and provide that URL to the Ansible playbook, because the download link will expire
after a short while and need to be refreshed.

## Usage

Edit the `ocp-vars.yaml` file in this directory, and fill in any blank values.

Check variables listed in `playbooks/vars/ovirt-infra-vars.yaml`

### Set up virtual machines in RHV
From the `reference-architecture/rhv-ansible` directory, run

```
ansible-playbook playbooks/ovirt-vm-infra.yaml -e@ocp-vars.yaml
```

### Set up OpenShift Container Platform on the VMs from the previoius step

```
ansible-playbook playbooks/openshift-install.yaml -e@ocp-vars.yaml
```



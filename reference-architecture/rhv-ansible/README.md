# The Reference Architecture OpenShift on RHV
This repository contains the scripts and ansible playbooks used to deploy 
an OpenShift Container Platform environment on Red Hat Virtualization

## Overview

## Prerequisites

Red Hat Virtualization Certificate
: A copy of the '/etc/pki/ovirt-engine/ca.pem' from the RHV engine will need to be added to the
: 'reference-architecture/rhv-ansible/playbooks/vars' directory.

RHEL QCOW2 Image
: The ovirt-ansible role, ovirt-image-template requires a URL to download a QCOW2 KVM image to use as
: the basis for the VMs on which OpenShift will be installed. If a CentOS image is desired, a suitable
: URL is commented out in the variable file, 'playbooks/vars/ovirt_infra_vars.yml'. If a RHEL image
: is preferred, log in at [https://access.redhat.com/], navigate to Downloads, Red Hat Enterpise Linux,
: select the latest release (at this time, 7.3), and copy the URL for "KVM Guest Image". It is
: preferable to download the image to a local server, e.g. the /pub/ directory of a satellite if
: available, and provide that URL to the Ansible playbook, because the download link will expire
: after a short while and need to be refreshed.

## Usage

From the 'reference-architecture/rhv-ansible' directory, run

  ansible-playbook playbooks/ovirt-infra.yml -e@playbooks/vars/main.yaml

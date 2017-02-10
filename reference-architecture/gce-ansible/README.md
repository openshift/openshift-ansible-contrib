# The Reference Architecture OpenShift on Google Cloud Engine

This directory contains the scripts used to deploy an OpenShift environment based off of the Reference Architecture Guide for OpenShift 3.4 on Google Cloud Engine.

## Overview

The directory contains Ansible playbooks which deploy 3 Masters in different availability zones, 2 infrastructure nodes and 2 application nodes. The Infrastructure and Application nodes are split between two availability zones.  The playbooks deploy a Docker registry and scale the router to the number of Infrastructure nodes.

## Prerequisites

A registered domain must be configured in the Google Cloud DNS.

### OpenShift Playbooks

The code in this directory handles the installation of OpenShift. It utilizes the OpenShift playbooks from the openshift-ansible-playbooks rpm. These playooks are meant to be run from `bastion` host in the GCE cloud, where the `bastion` has read and write access scope to the Compute API.

## Usage

Once the infrastructure is prepared with the `gcloud.sh` utility, copy all playbooks from this directory to the `bastion` host and execute the `openshift-install.yaml` playbook from the `gce-ansible` directory:

```
ansible-playbook -e 'public_hosted_zone=ocp.example.com \
    wildcard_zone=apps.ocp.example.com \
    openshift_deployment_type=openshift-enterprise \
    gcs_registry_bucket=example-openshift-docker-registry \
    gce_project_id=example \
    gce_network_name=ocp-network' \
    playbooks/openshift-install.yaml
```

### Creating a static inventory
The need may arise for a static Ansible inventory to be used. The Ansible playbook below will query Google Cloud Engine to list the OpenShift instances. The playbook generates a file named static-inventory.

```
ansible-playbook -e @~/ansible-config.yml \
playbooks/create-inventory-file.yaml
```
This script will output the file static-inventory to the current directory. The static inventory can then be called by using the -i parameter with ansible. Below is an example running the uninstall playbook with the newly generated static-inventory.

```
ansible-playbook -i static-inventory /usr/share/ansible/openshift-ansible/playbooks/adhoc/uninstall.yml
```

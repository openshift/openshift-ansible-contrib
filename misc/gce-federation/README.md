# GCE Federation Quickstart

This tutorial serves as a quickstart to help you stand up a federated cluster running OpenShift Origin on Centos.  The playbooks deploy the necessary infrastructure in GCE (firewalls, VMs, etc...), initialize federation, and finally, deploy an application onto the federated environment.

## Host prepration

These tests were run from a RHEL 7.3 host. Install the required packages:

```
$ sudo rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
$ sudo yum -y install ansible git python-libcloud git openssl python2-jmespath 
```

Clone the repository:

```
$ git clone https://github.com/openshift/openshift-ansible-contrib.git
$ cd openshift-ansible-contrib/misc/gce-federation
```

## GCE Prerequisites

### Project
The deployment requires a project be configured. Follow the steps using the link below to ensure that a project
is created.

https://cloud.google.com/resource-manager/docs/creating-managing-projects

To confirm which project's you have available:

```
$ gcloud projects list
PROJECT_ID                NAME                      PROJECT_NUMBER
federation-project        Federation-project        43xxx2735x35
```

### DNS
A DNS zone is required for this demo. The link below provides the steps to create the zone.
https://cloud.google.com/dns/quickstart

To confirm which managed DNS zones you have available:

```
$ gcloud dns managed-zones list 
NAME                    DNS_NAME                     DESCRIPTION
scollier-fed-sysdeseng  sysdeseng.com.               federation testing
```

### Service Account

The deployment requires that a service account be created. If a service account does not exist browse to
https://cloud.google.com/iam/docs/managing-service-accounts#creating_a_service_account

Choose the prefered method API, Console, or GCloud to create the Service Account. Ensure that the project that
will be used for federation is selected.

After you have configured your service accounts, you can check them with `gcloud`:

```
$ gcloud iam service-accounts list 
NAME                                    EMAIL
scollier-REDACTED-service-act         scollier-REDACTED-service-ac@scott-collier-federation.iam.gserviceaccount.com
```

Once the account is created a key must be created. Select the key type of JSON. If using the browser, the
json file will be placed in the home directory under Downloads.


### GCE.INI

The gce.ini file must reside in the `openshift-ansible-contrib/misc/gce-federation/inventory` directory.  Modify the `gce.ini` file to represent the values of the service account which will be used for the deployment.

NOTE: Use the value of the email address defined in the JSON file. 

The values below are example values. Modify the values to represent the values defined in the JSON file. 

```
[gce]
gce_service_account_email_address = deployment@fedconnect-8675309.iam.gserviceaccount.com
gce_service_account_pem_file_path = /home/admin/Downloads/federation-8675309.json
gce_project_id = federation-8675309
```

### Set up Environment Variables

There are two ways you can pass variables to the playbooks in this exmaple. The first is to set environment variables as described below. Make sure to substitute your values for what's given here. The other way is to pass the variables to the playbooks via -e at the command line.  More information to follow below on that.

```
export FEDERATION_ID=fed
export FEDERATION_DNS_ZONE=sysdeseng.com
export GCE_CREDS_FILE=/home/admin/Downloads/federation-8675309.json
export GCE_SERVICE_ACCOUNT=deployer
export GCE_PROJECT_ID=federation-8675309
```

### Private Key
In the event that your private key for GCE is not the same as the id_rsa on the deployment system then the following must be added to the `openshift-ansible-contrib/misc/gce-federation/ansible.cfg` file.

```
private_key_file=/home/admin/.ssh/google_compute_engine
```

### Ansible SSH User

Modify the following files and specify the ansible_ssh_user. The ansible_ssh_user value will be based on the project-wide SSH keys. See the following link for more about using SSH keys with GCE.

https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys

You can list your keys with the following command:

```
$ gcloud compute project info describe
```

Now make the appropriate modifications.

```
$ vi inventory/group_vars/federation
ansible_ssh_user: admin
```

```
$ vi templates/inventory.yaml.j2
ansible_ssh_user: admin
```

## Deployment

Now that the environment is set up, you are ready to deploy.  Put on your helmet!  The quick and easy way to do the deployment is with the following string of commands.

```
$ ansible-playbook init.yaml && ./inventory/gce.py --refresh-cache && ansible-playbook install.yaml && ansible-playbook federate.yaml && ansible-playbook deploy-app.yaml 
```

A breakdown of what those commands are abstracting away is given here.

```
$ ansible-playbook init.yaml
```

- provisioning of the VMs in GCE

```
$ ./inventory/gce.py --refresh-cache
```
- Forces a refresh of the cache by making API requests

```
$ ansible-playbook install.yaml
```

- Installs packages: git, ansible, pip
- Installs pxepect from pip
- Pulls openshift-ansible from git
- Creates remote inventory file
- Runs openshift-ansible on each node


```
$ ansible-playbook federate.yaml
```

- Updates cloud provider config
- Handles certificates
- Adds clusters to client config
- Initializes federation
- Adds project admin role
- Adds clusters to federation


```
$ ansible-playbook deploy-app.yaml
```

- Creates namespace for app
- Creates PVCs
- Creates federated services
- Creates federated deployment
- Creates scale deployment
- Configures and tests mongodb


## General Configuration

### Required variables
Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | description |
|---------------|---------|-------------|
| federation_id | FEDERATION_ID | Unique ID for this federation |

### Optional variables
Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | default | description |
|---------------|---------|---------|-------------|
|               |         |         |             |

### GCE Provisioning Configuration

GCE Provisioning is enabled when gce_cluster_count > 0

### Required variables

Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | description |
|---------------|---------|-------------|
| gce_creds_file | GCE_CREDS_FILE | Path to the GCE credentials file to use for provisioning |
| gce_service_account | GCE_SERVICE_ACCOUNT | GCE service account to use for provisioning |
| gce_project_id | GCE_PROJECT_ID | GCE project id to use for provisioning |

### Optional variables

Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | default | description |
|---------------|---------|---------|-------------|
| gce_cluster_count | GCE_CLUSTER_COUNT | 3 | Number of GCE Clusters to create |
| gce_regions | GCE_REGIONS | us-east1,us-central1,us-west1 | Comma separated list of regions to deploy clusters to |

## Cluster teardown

ansible-playbook teardown.yaml

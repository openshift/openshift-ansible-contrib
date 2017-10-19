# The Reference Architecture OpenShift on Google Cloud Platform

This repository contains the code used to deploy an OpenShift Container Platform or OpenShift Origin environment based off of the [Reference Architecture Guide for OCP 3 on Google Cloud Platform](https://access.redhat.com/articles/2751521).

## Overview

The repository contains Ansible playbooks which deploy 3 masters, 3 infrastructure nodes and 3 application nodes in different availability zones.

![Architecture](images/arch.png)

## Usage

Described usage is for RHEL 7 based operating system.

### Prerequisites

You can use the `deploy-host.yaml` playbook provided within the repository to install all required packages on the deployment host:
```
sudo subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-3.6-rpms
sudo yum update
sudo yum install git ansible
git clone https://github.com/openshift/openshift-ansible-contrib
cd openshift-ansible-contrib
ansible-playbook playbooks/deploy-host.yaml -e provider=gcp
```

Alternatively, you can install all packages manually:
```
# Enable repos for RHEL
sudo subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-3.6-rpms

# Install EPEL repo
sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Install packages
sudo yum install curl python which tar qemu-img openssl git ansible java-1.8.0-openjdk-headless httpd-tools python2-passlib python-libcloud python2-jmespath atomic-openshift-utils
```

Note: It's possible to deploy OCP without the `atomic-openshift-utils` package installed (`openshift-ansible` installer will be then downloaded directly from [GitHub](https://github.com/openshift/openshift-ansible)). This may be convenient when you don't want to consume your OpenShift subscription on your deployment host, or when you are running the deployment from CentOS or Fedora.

Note 2: You need to have GNU tar because the BSD version will not work. Also, it may be necessary to update qemu-img if the package is already installed. If the package is not updated, errors may occur when uploading the RHEL image to GCP.

### RHEL KVM Guest Image

For OpenShift Cloud Platform deployment, you need to have RHEL 7 KVM Guest Image locally downloaded from [Red Hat Access Portal](https://access.redhat.com/downloads/content/69/ver=/rhel---7/latest/x86_64/product-software). This is because RHEL 7 image available in the GCP doesn't support custom subscriptions and the OCP is not available there.

For OpenShift Origin deployment, KVM Guest Image is not needed, CentOS 7 image available in the GCP will be used directly.

### Setup Google Cloud Account and SDK

You need to have an account in the [Google Cloud Platform](https://cloud.google.com/). Unfortunately, it's not possible to use trial version of the account as it contains only one static IP address, but the reference architecture requires two.

#### Google Cloud SDK

Google provides a repository which can be used to install Google Cloud SDK on RHEL 7 or Fedora based OS:
```
sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
```

Now it's easy to install the SDK and initialize the gcloud utility:
```
sudo yum install google-cloud-sdk
gcloud init
```

More information about the Google Cloud SDK (with info about repositories for other Linux distributions) can be found in [the documentation](https://cloud.google.com/sdk/docs/).

### Configuration file

Now copy the `config.yaml.example` file to `config.yaml`:
```
cd openshift-ansible-contrib/reference-architecture/gcp
cp config.yaml.example config.yaml
```

### Setting variables

Variables can be set to customize the OpenShift infrastructure and deployment. The most important variables can be found in the `config.yaml.example` file, but any Ansible variable used during the deployment can be placed in the `config.yaml` file, where it will override the default value. It's also possible to override Ansible variables directly on the command line when invoking the `ocp-on-gcp.sh` script, e.g. `./ocp-on-gcp.sh -e 'openshift_debug_level=4'`

### Launching the `ocp-on-gcp.sh` script

By default, running the script without parameters will create the infrastructure in the GCP and deploys OpenShift on top of it:
```
./ocp-on-gcp.sh
```

However, the script supports couple of parameters which can modify its behavior. For complete documentation see:
```
./ocp-on-gcp.sh --help
```

## Additional supported operations

The following section sums up couple of additional operations supported by the `ocp-on-gcp.sh` script.

### Scaling up the OpenShift cluster

To scale up the OpenShift cluster, update the `config.yaml` file with desired number of nodes:

```
# How many instances should be created for each group
master_instance_group_size: 3
infra_node_instance_group_size: 4
node_instance_group_size: 5
```

Scaling up masters, infrastructure and application nodes is supported. Adding more than one node at a time works as well. Scaling down is not supported.

To perform the scale up once the config file is updated, run following:
```
./ocp-on-gcp.sh --scaleup
```

Note: Scaling of pods (router, registry..) running on infrastructure nodes is not performed during the scale up. It is expected that the administrator will perform the scale up once the new nodes are deployed. For example, to scale router run: `oc scale dc/router --replicas=4` from any master node.

### Static inventory

A static inventory can be used for other Ansible playbooks not defined in this repository. To create the static inventory, run:
```
./ocp-on-gcp.sh --static-inventory
```

Afterwards, the static inventory will be placed in the `ansible` directory with file name `static-inventory`.

### Tearing down the infrastructure

If you want to tear down the infrastructure to start over with different settings, or just to clean up the resources, you can use `--teardown` option:
```
./ocp-on-gcp.sh --teardown
```

### Multiple OpenShift deployments

Multiple OpenShift deployments under single project in GCP are supported. Every OpenShift cluster then must have different `prefix` and DNS names configured in `config.yaml` file. It's possible to specify config file `ocp-on-gcp.sh` script uses with `-c | --config FILE` parameter, so deploying two different cluster can look like this:

```
./ocp-on-gcp.sh -c ../config-dev.yaml

./ocp-on-gcp.sh -c ../config-prod.yaml
```

# The Reference Architecture Script
The bash script provided in this repository will create the infrastructure required to install OpenShift and once the infrastructure is deployed, Ansible playbooks in gce-ansible directory are called from the bastion instance in GCE to automatically deploy OpenShift and all required components.

Complete documentation for this script can be found in [reference architecture](https://access.redhat.com/articles/2751521).

## Usage

Described usage is for RHEL 7 based operating system.

### Setup gcloud utility

Installation of gcloud utility is interactive, usually you will want to answer positively to asked questions.
```
sudo yum -y install curl python which tar qemu-img openssl git ansible python-libcloud python2-jmespath
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud components install beta
gcloud init
```

Note: You need to have GNU tar because the BSD version will not work. Also, it may be necessary to update qemu-img if the package is already installed. If the package is not updated errors may occur when uploading the RHEL image to GCE.

### Ansible Installer

Currently, we are in a process of migrating away from shell to pure Ansible deployment. Most notable change of this process is that the whole deployment will be run from the local machine and not partly from the bastion host. Because of this change, we now require Ansible installer locally available. If you are running RHEL-7 with proper subscription, just install the `atomic-openshift-utils` package:
```
subscription-manager repos --enable rhel-7-server-optional-rpms
subscription-manager repos --enable rhel-7-server-ose-3.5-rpms
subscription-manager repos --enable rhel-7-fast-datapath-rpms

yum -y install atomic-openshift-utils
```

For Fedora, clone the `openshift-ansible` repo next to the `openshift-ansible-contrib` repo (info below) and **switch to the correct tag**, currently it's `openshift-ansible-3.5.53-1`:
```
git clone https://github.com/openshift/openshift-ansible.git
cd openshift-ansible
git checkout openshift-ansible-3.5.53-1
cd ..
```

### Clone this repository

Now clone this repository to your local directory and copy the `config.yaml.example` file to `config.yaml`

```
git clone https://github.com/openshift/openshift-ansible-contrib.git
cd openshift-ansible-contrib/reference-architecture/gce-cli
cp config.yaml.example config.yaml
```

### Setting variables

Variables can be set to customize the OpenShift infrastructure. All available variables can be found in the `config.yaml` file. In the first part of that file you can find essential variables which need to be modified (like credentials for Red Hat account and DNS). In the second part of the file all default values are available, which can be optionally tweaked.

### Launching the Bash script

```
./gcloud.sh
```

### Static inventory
A static inventory can be used for other Ansible playbooks not defined in this repository. To create the static inventory follow the steps in the link [Creating a static inventory](../gce-ansible/README.md)

### Tearing down the infrastructure

If you want to tear down the infrastructure to start over with differrent settings, or just to clean up the resources, you can use `--revert` option:

```
./gcloud.sh --revert
```

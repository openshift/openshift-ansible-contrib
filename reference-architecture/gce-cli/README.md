# The Reference Architecture Script
The bash script provided in this repository will create the infrastructure required to install OpenShift and once the infrastructure is deployed, Ansible playbooks in gce-ansible directory are called from the bastion instance in GCE to automatically deploy OpenShift and all required components.

Complete documentation for this script can be found in [reference architecture](https://access.redhat.com/articles/2751521).

## Usage

Described usage is for RHEL 7 based operating system.

### Setup gcloud utility

Installation of gcloud utility is interactive, usually you will want to answer positively to asked questions.
```
sudo yum -y install curl python which tar qemu-img openssl gettext git
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud components install beta
gcloud init
```

Note: You need to have GNU tar because the BSD version will not work. Also, it may be necessary to update qemu-img if the package is already installed. If the package is not updated errors may occur when uploading the RHEL image to GCE.

### Clone this repository

Now clone this repository to your local directory and copy the `config.sh.example` file to `config.sh`

```
git clone https://github.com/openshift/openshift-ansible-contrib.git
cd openshift-ansible-contrib/reference-architecture/gce-cli
cp config.sh.example config.sh
```

### Setting variables

Variables can be set to customize the OpenShift infrastructure. All available variables can be found in the `config.sh` file. In the first part of that file you can find essential variables which need to be modified (like credentials for Red Hat account and DNS). In the second part of the file all default values are available, which can be optionally tweaked.

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

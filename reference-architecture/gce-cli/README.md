# The Reference Architecture Bash Script
The bash script provided in this repository will create the infrastructure required to install OpenShift. Once the infrastructure is deployed, the Ansible playbooks in gce-ansible directory will deploy OpenShift and the required components.

## Usage

Described usage is for RHEL 7 based operating system.

### Setup gcloud utility

Installation of gcloud utility is interactive, usually you will want to answer positively to the asked questions.
```
yum install curl python which
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud components install beta
gcloud init
```

### Setting variables

Variables can be set to customize the OpenShift infrastructure. All available variables can be found in the `config.sh` file. In the first part of that file you can find essential variables which need to be modified (like credentials for Red Hat account). In the second part of the file all default values are available, which can be optionally tweaked.

### Launching the Bash script

```
./gcloud.sh
```

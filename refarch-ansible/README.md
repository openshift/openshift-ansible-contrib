# The Reference Architecture Ansible Script
This collection of Ansible playbooks can be kicked off by using the python script ose-on-aws. The script contains options to allow for OSE to be installed into a new AWS environment or an already existing environment.

## Overview
These scripts will deploy the environment defined in the upcoming Reference Architecture guide for deploying OpenShift 3.2 on AWS [Amazon Web Services]. The Ansible playbook deploys 3 Masters in different availability zones, 2 infrastructure nodes and 2 applcation nodes.  The Infrastrucute and Application nodes are split between two availbility zones.  The playbooks deploy a Docker registry and scale the router to the number of Infrastruture nodes.

## Prerequisites
A registered domain must be added to Route53 as a Hosted Zone before installation.  This registered domain can be purchased through AWS.

## Software Requirements
### Packaged Software
- [Python](https://www.python.org) version 2.7.x (3.x untested and may not work)
- [Python Click](https://github.com/mitsuhiko/click) version 4.0 or greater
- [Python Boto](http://docs.pythonboto.org) version 2.38.0 or greater
- [Ansible](https://github.com/ansible/ansible) version 1.9.4

### GitHub Repositories
The code in this repository handles all of the components except for the installation of OpenShift. We rely on the OpenShift installer which lives in a separate repository. You will need both of
them to perform the installation using ose-on-aws.py.

- `openshift-ansible`
    - [openshift/openshift-ansible](https://github.com/openshift/openshift-ansible)
    - You will want to check out tag `openshift-ansible-3.0.90-1`

The folders for these repositories are expected to live in the same
subdirectory. An example tree structure is below:
```
/home/user/git/
|-- openshift-ansible-contrib
|-- openshift-ansible
```

In this case, you could do something like the following:
```
cd /home/user/git
git clone https://github.com/openshift/openshift-ansible-contrib.git
git clone https://github.com/openshift/openshift-ansible.git
cd openshift-ansible
git checkout openshift-ansible-3.0.90-1
```

## Usage
### Export the EC2 Credentials
You will need to export your EC2 credentials before attempting to use the
scripts:
```
export AWS_ACCESS_KEY_ID=foo
export AWS_SECRET_ACCESS_KEY=bar
```
### Region
The default region is us-east-1 but can be changed when running the ose-on-aws script by specifying --region=us-west-2 for example.

### New AWS Environment (Greenfield)
When installing into an new AWS environment perform the following.   This will create the SSH key, bastion host, and VPC for the new environment.
```
./ose-on-aws.py --keypair=OSE-key --create-key=yes --ssh-key=/path/to/ssh/key --rhn-user=rh-user --rhn-password=password --public-hosted-zone=sysdeseng.com
```

If the SSH key that you plan on using in AWS already exists then perform the following.
```
./ose-on-aws.py --keypair=OSE-key --rhn-user=rh-user --rhn-password=password --public-hosted-zone=sysdeseng.com

```
### Existing AWS Environment (Brownfield)
If installion OpenShift into an existing AWS VPC perfrom the following.  This assumes that you already have a bastion host with the Security Group name of bastion-sg.  The script will prompt for vpc and subnet IDs.
```
./ose-on-aws.py --create-vpc=no --byo-bastion=yes --keypair=OSE-key --rhn-user=rh-user --rhn-password=password --public-hosted-zone=sysdeseng.com
```

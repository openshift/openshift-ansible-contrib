# The Reference Architecture OpenShift on Amazon Web Services
This repository contains the scripts used to deploy an OpenShift Container Platform or OpenShift Origin environment based off of the Reference Architecture Guide for OpenShift 3.3 on Amazon Web Services.

## Overview
The repository contains Ansible playbooks which deploy 3 Masters in different availability zones, 2 infrastructure nodes and 2 applcation nodes. The Infrastrucute and Application nodes are split between two availbility zones.  The playbooks deploy a Docker registry and scale the router to the number of Infrastruture nodes.

![Architecture](images/arch.jpg)

## Prerequisites
A registered domain must be added to Route53 as a Hosted Zone before installation.  This registered domain can be purchased through AWS.

### Deploying OpenShift Container Platform
The code in this repository handles all of the AWS specific components except for the installation of OpenShift. We rely on the OpenShift playbooks from the openshift-ansible-playbooks rpm. You will need the rpm installed on the workstation before using ose-on-aws.py.

```
$ subscription-manager repos --enable rhel-7-server-optional-rpms
$ subscription-manager repos --enable rhel-7-server-ose-3.2-rpms
$ subscription-manager repos --enable rhel-7-server-ose-3.3-rpms
$ rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
$ yum -y install atomic-openshift-utils \
                 python2-boto \
                 git \
                 ansible-2.2.0-0.5.prerelease.el7.noarch \
                 python-netaddr \
                 python-httplib2
```

### Deploying Origin
The playbooks in the repository also have the ability to configure CentOS or RHEL instances to prepare for the installation of Origin. Due to the OpenShift playbooks not being available in RPM format outside of a OpenShift Container Platform subscription the openshift-ansible repository must be cloned.

```
$ rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
$ yum -y install python-pip git python2-boto \ 
python-netaddr python-httplib2 python-devel \
gcc libffi-devel openssl-devel
$ pip install git+https://github.com/ansible/ansible.git@stable-2.2
$ mkdir -p /usr/share/ansible/openshift-ansible
$ git clone https://github.com/openshift/openshift-ansible.git /usr/share/ansible/openshift-ansible
```

### Deploying Origin
The playbooks in the repository also have the ability to configure CentOS or RHEL instances to prepare for the installation of Origin. Due to the OpenShift playbooks not being available in RPM format outside of a OpenShift Container Platform subscription the openshift-ansible repository must be cloned.

```
$ *rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm*
$ yum -y install python-pip python-devel gcc libffi-devel openssl-devel
$ pip install git+https://github.com/ansible/ansible.git@stable-2.2
$ mkdir -p /usr/share/ansible/openshift-ansible
$ git clone https://github.com/openshift/openshift-ansible.git /usr/share/ansible/openshift-ansible
```

## Usage
The Ansible script will launch infrastructure and flow straight into installing the OpenShift application and components.

### Before Launching the Ansible script
Due to the installations use of a bastion server the ssh config must be modified.
```
$ vim /home/user/.ssh/config
Host *.sysdeseng.com
     ProxyCommand               ssh ec2-user@bastion -W %h:%p
     IdentityFile               /path/to/ssh/key

Host bastion
     Hostname                   bastion.sysdeseng.com
     user                       ec2-user
     StrictHostKeyChecking      no
     CheckHostIP                no
     ForwardAgent               yes
     IdentityFile               /path/to/ssh/key

```
### Export the EC2 Credentials
You will need to export your EC2 credentials before attempting to use the
scripts:
```
export AWS_ACCESS_KEY_ID=foo
export AWS_SECRET_ACCESS_KEY=bar
```
### Region
The default region is us-east-1 but can be changed when running the ose-on-aws script by specifying --region=us-west-2 for example. The region must contain at least 3 Availability Zones. 

### AMI ID
The AMI ID may need to change if the AWS IAM account does not have access to the Red Hat Cloud Access gold image, deploying CentOS, or if deploying outside of the us-east-1 region.

### New AWS Environment (Greenfield)
When installing into an new AWS environment perform the following.   This will create the SSH key, bastion host, and VPC for the new environment.

**OpenShift Container Platform**
```
./ose-on-aws.py --keypair=OSE-key --create-key=yes --key-path=/path/to/ssh/key.pub --rhsm-user=rh-user --rhsm-password=password --public-hosted-zone=sysdeseng.com --rhsm-pool="Red Hat OpenShift Container Platform, Standard, 2-Core"
```
**OpenShift Origin**
```
./ose-on-aws.py --keypair=OSE-key --create-key=yes --key-path=/path/to/ssh/key.pub --public-hosted-zone=sysdeseng.com --deployment-type=origin --ami=ami-6d1c2007 
```

If the SSH key that you plan on using in AWS already exists then perform the following.

**OpenShift Container Platform**
```
./ose-on-aws.py --keypair=OSE-key --rhsm-user=rh-user --rhsm-password=password --public-hosted-zone=sysdeseng.com --rhsm-pool="Red Hat OpenShift Container Platform, Standard, 2-Core"

```

**OpenShift Origin**
```
./ose-on-aws.py --keypair=OSE-key --public-hosted-zone=sysdeseng.com --deployment-type=origin --ami=ami-6d1c2007

```
### Existing AWS Environment (Brownfield)
If installing OpenShift Container Platform or Openshift Origin into an existing AWS VPC perform the following. The script will prompt for vpc and subnet IDs.  The Brownfield deployment can also skip the creation of a Bastion server if one already exists. For mappings of security groups make sure the bastion security group is named bastion-sg.

**OpenShift Container Platform**
```
./ose-on-aws.py --create-vpc=no --byo-bastion=yes --keypair=OSE-key --rhsm-user=rh-user --rhsm-password=password --public-hosted-zone=sysdeseng.com --rhsm-pool="Red Hat OpenShift Container Platform, Standard, 2-Core" --bastion-sg=sg-a32fa3
```

**OpenShift Origin**
```
./ose-on-aws.py --create-vpc=no --byo-bastion=yes --keypair=OSE-key --public-hosted-zone=sysdeseng.com --deployment-type=origin --ami=ami-6d1c2007 --bastion-sg=sg-a32fa3
```

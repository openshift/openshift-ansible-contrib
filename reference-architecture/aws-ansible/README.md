# The Reference Architecture OpenShift on Amazon Web Services
This repository contains the scripts used to deploy an OpenShift environment based off of the Reference Architecture Guide for OpenShift 3.3 on Amazon Web Services.

## Overview
The repository contains Ansible playbooks which deploy 3 Masters in different availability zones, 2 infrastructure nodes and 2 applcation nodes. The Infrastrucute and Application nodes are split between two availbility zones.  The playbooks deploy a Docker registry and scale the router to the number of Infrastruture nodes.

![Architecture](images/arch.jpg)

## Prerequisites
A registered domain must be added to Route53 as a Hosted Zone before installation.  This registered domain can be purchased through AWS.

### OpenShift Playbooks
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
The AMI ID may need to change if the AWS IAM account does not have access to the Red Hat Cloud Access gold image or if deploying outside of the us-east-1 region.

### Containerized Installation
The option to install OpenShift is possible by providing the trigger --containerized=true. Using the --containerized=true also allows for the use of Atomic Host.

### New AWS Environment (Greenfield)
When installing into an new AWS environment perform the following.   This will create the SSH key, bastion host, and VPC for the new environment.
```
./ose-on-aws.py --keypair=OSE-key --create-key=yes --key-path=/path/to/ssh/key.pub --rhsm-user=rh-user --rhsm-password=password --public-hosted-zone=sysdeseng.com --rhsm-pool="Red Hat OpenShift Container Platform, Standard, 2-Core"
```

If the SSH key that you plan on using in AWS already exists then perform the following.
```
./ose-on-aws.py --keypair=OSE-key --rhsm-user=rh-user --rhsm-password=password --public-hosted-zone=sysdeseng.com --rhsm-pool="Red Hat OpenShift Container Platform, Standard, 2-Core"

```
### Existing AWS Environment (Brownfield)
If the installing OpenShift into an existing AWS VPC perform the following. The script will prompt for vpc and subnet IDs.  The Brownfield deployment can also skip the creation of a Bastion server if one already exists. For mappings of security groups make sure the bastion security group is named bastion-sg.
```
./ose-on-aws.py --create-vpc=no --byo-bastion=yes --keypair=OSE-key --rhsm-user=rh-user --rhsm-password=password --public-hosted-zone=sysdeseng.com --rhsm-pool="Red Hat OpenShift Container Platform, Standard, 2-Core" --bastion-sg=sg-a32fa3
```

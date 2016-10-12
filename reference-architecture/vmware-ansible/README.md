# The Reference Architecture OpenShift on VMware
This repository contains the scripts used to deploy an OpenShift environment based off of the Reference Architecture Guide for OpenShift 3.3 on VMware

## Overview
The repository contains Ansible playbooks which deploy 3 Masters, 2 infrastructure nodes and 3 application nodes. All nodes could utilize anti-affinity rules to separate them on the number of hypervisors you have allocated for this deployment. The playbooks deploy a Docker registry and scale the router to the number of Infrastruture nodes.

![Architecture](images/OSE-on-VMware-Architecture.jpg)

## Prerequisites
Internal DNS should be set up to reflect the number of nodes in the environment. The default VM network should have a DHCP server set up for initial provisioning. 

### OpenShift Playbooks
The code in this repository handles all of the VMware specific components except for the installation of OpenShift. We rely on the OpenShift playbooks from the openshift-ansible-playbooks rpm. You will need the rpm installed on the workstation before using ose-on-vmware.py.

```
subscription-manager repos --enable rhel-7-server-optional-rpms
subscription-manager repos --enable rhel-7-server-ose-3.3-rpms
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm*
yum -y install atomic-openshift-utils \
                  git \
                  pyOpenSSL \
                  python-simplejson \
                  python-ldap \
                  python-iptools \
                  python-netaddr \
                  python-httplib2
git clone https://github.com/dannvix/pySphere && cd pySphere/ && python setup.py install
git clone https://github.com/vmware/pyvmomi && cd pyvmomi/ && python setup.py install

# Grabbed the patched vsphere_guest until the PR is merged
cp vsphere_guest.py /usr/lib/python2.7/site-packages/ansible/modules/core/cloud/vmware/
```
Alternatively, I've provided a Dockerfile should you want to use a container for deployment. This
is the method that the reference implementation uses.

```
FROM registry.access.redhat.com/rhel7

MAINTAINER Davis Phillips <dphillip@redhat.com>


RUN yum -y --disablerepo=\* --enablerepo=rhel-7-server-rpms install yum-utils && \
  yum-config-manager --disable \* && \
  yum-config-manager --enable rhel-7-server-rpms && \
  yum-config-manager --enable rhel-7-server-extras-rpms  && \
  yum-config-manager --enable rhel-7-server-ose-3.3-rpms && \
  yum-config-manager --enable rhel-7-server-satellite-tools-6.2-rpms && \
  yum-config-manager --enable rhel-7-server-optional-rpms && \
  yum clean all


# install all that is required to use http://docs.ansible.com/ansible/vsphere_guest_module.html
RUN yum install -y --setopt=tsflags=nodocs atomic-openshift-utils git python-iptools python-ldap python-simplejson python-netaddr python-pip pyOpenSSL &&  \
    yum clean all

RUN rm /etc/ansible/hosts
RUN git clone https://github.com/dannvix/pySphere && cd pySphere/ && python setup.py install
RUN git clone https://github.com/vmware/pyvmomi && cd pyvmomi/ && python setup.py install

VOLUME [ "/etc/ansible/hosts", "/opt/ansible" ]

# Add in patched version of vsphere_guest.py
# Awaiting PR merge
COPY vsphere_guest.py /usr/lib/python2.7/site-packages/ansible/modules/core/cloud/vmware/
#COPY vi_virtual_machine.py /usr/lib/python2.7/site-packages/pysphere/
WORKDIR "/opt/ansible"

ENTRYPOINT [ "ansible-playbook" ]

```

## Usage
The Ansible script will launch infrastructure and flow straight into installing the OpenShift application and components.

### Before Launching the Ansible script
Before launching the ansible scripts ensure that your ssh keys are imported properly. Your private key should be located here ssh_keys/ose3-installer. Make sure your public key is copied to your template.
```
ssh-keygen

cp ~/.ssh/id_rsa ose-on-vmware/vmware-ansible/ssh_key/ose3-installer

```
Additionally, you will need to use ose-on-vmware.py to configure your LDAP authentication credentials for the OpenShift install and to create your inventory to define the number of nodes for reach role: app, infra, master. Also, the create inventory will help you with your DNS configuration and will allow you to assign a starting static IP address point for your configuration. 

### VMware Template Name
This is your VMware template name. The template should be configured with open-vm-tools installed on RHEL 7.2. The deployment assumes that initially DHCP will be configured. Once the new VM is started with vmtoolsd running, we extract out the DHCP address then use our infrastructure vars for the static ip addresses to use.

### New VMware Environment (Greenfield)
When installing all components into your VMware environment perform the following.   This will create the haproxy, the nfs server for the registry, and all the production OpenShift VMs. Additionally, the installer script will attempt to copy your existing public key to the VMs.
```
 ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ose-on-vmware.py  \
--vcenter_host=vcenter.example.com --vcenter_password=password \
--rhsm_user=rhnuser --rhsm_password=password  \
--vm_dns=10.19.114.5 --vm_gw=10.19.114.1 --vm_interface_name=eth0 \
--public_hosted_zone=example.com --local
```

### Existing VM Environment and Deployment (Brownfield)
The `ose-on-vmware.py` script allows for deployments into an existing environment
in which VMs already exists and are subscribed to the proper `RHEL` [channels].(https://docs.openshift.com/enterprise/3.3/install_config/install/prerequisites.html#software-prerequisites)
The prerequisite packages will be installed. The script expects the proper VM annotations are
created on your VMs. App nodes will be labeled "app", infra nodes labeled
"infra" and master nodes labeled as "master."

Lastly, the prepared VMs must also have 2 additional hard disks as the OpenShift setup needs those
for both docker storage and OpenShift volumes.


The ose-install tag will install OpenShift on your pre-existing environment. The dynamic inventory script sorts your
VMs by their annotations and that is how the proper OpenShift labels are applied.

The ose-configure will configured your persistent registry and scale your nodes.

Notice in the instance below we are supplying our own external NFS server and load balancer.

```
~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ose-on-vmware.py  \
--vcenter_host=vcenter.example.com --vcenter_password=password \
--rhsm_activation_key=my_sat6_key --rhsm_org_id=Default_Organization  \
--vm_dns=10.19.114.5 --vm_gw=10.19.114.1 --vm_interface_name=eth0 \
--byo_lb=yes --lb_fqdn=loadbalancer.example.com \
--byo_nfs=yes --nfs_registry_host=nfs.example.com --nfs_registry_mountpoint=/nfs-registry \
--public_hosted_zone=vcenter.e2e.bos.redhat.com \
--tag ose-install,ose-configure --local
```

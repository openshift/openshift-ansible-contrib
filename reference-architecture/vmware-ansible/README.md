# The Reference Architecture OpenShift on VMware
This repository contains the scripts used to deploy an OpenShift environment based off of the Reference Architecture Guide for OpenShift 3.11 on VMware

## Overview
The repository contains Ansible playbooks which deploy 3 masters, 3 infrastructure nodes and 3 application nodes. All nodes could utilize anti-affinity rules to separate them on the number of hypervisors you have allocated for this deployment. The playbooks deploy a Docker registry and scale the router to the number of Infrastruture nodes. 

![Architecture](images/OCP-on-VMware-Architecture.jpg)

## Prerequisites and Usage

- Make sure your public key is copied to your template.

- Internal DNS should be set up to reflect the number of nodes in the environment. The inventory file should be customized for ipv4addr to be assigned.

- The code in this repository handles all of the deployment of virtual machines and their pre-requisites.

- Add your private key  **ssh_keys/ocp-installer** so Ansible can customize the guest OSs.

## Deploying a working vSphere Environment

The VMs will be created with the following properties:


|Node Type | CPUs | Memory | Disk 1 | Disk 2 | Disk 3 | Disk 4 |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| Master  | 2 vCPU | 16GB RAM | 1 x 60GB - OS RHEL 7.4 | 1 x 40GB - Docker volume | 1 x 40Gb -  EmptyDir volume | 1 x 40GB - ETCD volume |
| Node | 2 vCPU | 8GB RAM | 1 x 60GB - OS RHEL 7.4 | 1 x 40GB - Docker volume | 1 x 40Gb - EmptyDir volume | |

To deploy a working vSphere environment on the deployment host, first prepare it. 

```
# yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# yum install -y python2-pyvmomi
$ git clone -b vmw-3.11 https://github.com/openshift/openshift-ansible-contrib
$ cd openshift-ansible-contrib/reference-architecture/vmware-ansible/
```

Verify that the inventory file has the appropriate variables including IPv4 addresses
for the virtual machines in question and logins for the Red Hat Subscription Network.
All of the appropriate nodes should be listed in the proper groups: masters, infras, apps.

NOTE: A sample inventory file has been provided in openshift-ansible-contrib/reference-architecture/vmware-ansible/inventory/inventory311

```
$ cat /etc/ansible/hosts | egrep 'rhsub|ip'
rhsub_user=rhn_username
rhsub_pass=rhn_password
rhsub_pool=8a85f9815e9b371b015e9b501d081d4b
infra-0.example.com openshift_node_labels="{'region': 'infra'}" ipv4addr=10.x.y.8 vm_name=infr-0
infra-1.example.com openshift_node_labels="{'region': 'infra'}" ipv4addr=10.x.y.9 vm_name=infra-1
infra-2.example.com openshift_node_labels="{'region': 'infra'}" ipv4addr=10.x.y.13 vm_name=infra-2
app-0.example.com openshift_node_labels="{'region': 'app'}" ipv4addr=10.x.y.10 vm_name=app-0
app-1.example.com openshift_node_labels="{'region': 'app'}" ipv4addr=10.x.y.11 vm_name=app-1
...omitted...
$ ansible-playbook playbooks/provision.yaml
```

If an HAproxy instance is required it can also be deployed.

```
$ ansible-playbook playbooks/haproxy.yaml
```

This will provide the necessary nodes to fulfill the node requirements for OpenShift. 

After deployment, install OCP with the following plays:

```
$ ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
$ ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
```

## Deploying a working vSphere CNS Environment

Next, make sure that the appropriate variables are assigned in the inventory file:

```
$ cat /etc/ansible/hosts
rhsub_user=rhn_username
rhsub_pass=rhn_password
rhsub_pool=8a85f9815e9b371b015e9b501d081d4b
[gluster_fs]
cns-0.example.com  openshift_node_labels="{'region': 'infra'}" ipv4addr=10.x.y.33 vm_name=cns-0
cns-1.example.com  openshift_node_labels="{'region': 'infra'}" ipv4addr=10.x.y.34 vm_name=cns-1
cns-2.example.com  openshift_node_labels="{'region': 'infra'}" ipv4addr=10.x.y.35 vm_name=cns-2
```

Note the storage group for the `CNS` nodes.

```
$ ansible-playbook playbooks/cns-storage.yaml
```

During the OCP Installation, the following inventory variables are used
to add `Gluster CNS` to the registry for persistent storage:

```
$ cat /etc/ansible/hosts
...omitted...
# CNS registry storage
openshift_hosted_registry_storage_kind=glusterfs
openshift_hosted_registry_storage_volume_size=30Gi

# CNS storage cluster for applications
openshift_storage_glusterfs_namespace=app-storage
openshift_storage_glusterfs_storageclass=true
openshift_storage_glusterfs_block_deploy=false

# CNS storage for OpenShift infrastructure
openshift_storage_glusterfs_registry_namespace=infra-storage
openshift_storage_glusterfs_registry_storageclass=false
openshift_storage_glusterfs_registry_block_deploy=true
openshift_storage_glusterfs_registry_block_storageclass=true
openshift_storage_glusterfs_registry_block_storageclass_default=false
openshift_storage_glusterfs_registry_block_host_vol_create=true
openshift_storage_glusterfs_registry_block_host_vol_size=100
# 100% Dependent on sizing for logging and metrics

[glusterfs]
cns-0.example.com glusterfs_devices='[ "/dev/sdd" ]' vm_name=cns-0 ip4addr=10.x.y.99
cns-1.example.com glusterfs_devices='[ "/dev/sdd" ]' vm_name=cns-1 ip4addr=10.x.y.100
cns-2.example.com glusterfs_devices='[ "/dev/sdd" ]' vm_name=cns-2 ip4addr=10.x.y.101
[glusterfs_registry]
infra-0.example.com glusterfs_devices='[ "/dev/sdd" ]'
infra-1.example.com glusterfs_devices='[ "/dev/sdd" ]'
infra-2.example.com glusterfs_devices='[ "/dev/sdd" ]' 
```

Verify connectivity to the `PVC` for services:

```
$ oc get pvc --all-namespaces
NAMESPACE           NAME                      STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS               AGE
default             registry-claim            Bound     registry-volume                            25Gi       RWX                                       31d
logging             logging-es-0              Bound     pvc-22ee4dbf-48bf-11e8-b36e-005056b17236   10Gi       RWO            glusterfs-registry-block   8d
logging             logging-es-1              Bound     pvc-38495e2d-48bf-11e8-b36e-005056b17236   10Gi       RWO            glusterfs-registry-block   8d
logging             logging-es-2              Bound     pvc-5146dfb8-48bf-11e8-b871-0050568ed4f5   10Gi       RWO            glusterfs-registry-block   8d
mysql               mysql                     Bound     pvc-b8139d85-4735-11e8-b3c3-0050568ede15   10Gi       RWO            glusterfs-storage          10d
openshift-metrics   prometheus                Bound     pvc-1b376ff8-489d-11e8-b871-0050568ed4f5   100Gi      RWO            glusterfs-registry-block   8d
openshift-metrics   prometheus-alertbuffer    Bound     pvc-1c9c0ba1-489d-11e8-b871-0050568ed4f5   10Gi       RWO            glusterfs-registry-block   8d
openshift-metrics   prometheus-alertmanager   Bound     pvc-1be3bf3f-489d-11e8-b36e-005056b17236   10Gi       RWO            glusterfs-registry-block   8d
```

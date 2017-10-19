# The Reference Architecture OpenShift on VMware
This repository contains the scripts used to deploy an OpenShift environment based off of the Reference Architecture Guide for OpenShift 3.6 on VMware

## Overview
The repository contains Ansible playbooks which deploy 3 masters, 3 infrastructure nodes and 3 application nodes. All nodes could utilize anti-affinity rules to separate them on the number of hypervisors you have allocated for this deployment. The playbooks deploy a Docker registry and scale the router to the number of Infrastruture nodes. 

![Architecture](images/OCP-on-VMware-Architecture.jpg)

## Prerequisites and Usage

- Make sure your public key is copied to your template.

- Internal DNS should be set up to reflect the number of nodes in the environment. The default "VM network" should have a contiguous static IP addresses set up for initial provisioning.

- The code in this repository handles all of the VMware specific components except for the installation of OpenShift.

- The deploy-host playbook will create an SSH key and move it into place at **ssh_keys/ocp-installer**.

The following commands should be issued from the deployment host:
```
# yum install -y ansible git
$ mkdir ~/git/ && git clone https://github.com/openshift/openshift-ansible-contrib
$ cd ~/git/openshift-ansible-contrib && ansible-playbook playbooks/deploy-host.yaml -e provider=vsphere
```

Copy the SSH pub key to the template:
```bash
ssh-copy-id root@template_ip_address
```

Next fill out the variables in ocp-on-vmware.ini and run the installer

The Ansible script will launch infrastructure and flow straight into installing the OpenShift application and components.
Additionally, ocp-on-vmware.py will configure LDAP authentication credentials for the OpenShift install create an inventory file to define the number of nodes for each **role**: *app, infra, master*.
Lastly, the script will help with the DNS configuration and will facilitate static IP configuration.

```bash
$ vim  ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.ini
$ cd ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ && ./ocp-on-vmware.py
```

### VMware Template Name
The variable `vcenter_template_name` is the VMware template name it should have RHEL 7.4 installed with the open-vm-tools package.

### New VMware Environment (Greenfield)
When configuring a Greednfield cluster the following components are installed by default:

- HAproxy VM
- NFS VM for registry
- 3 Master OpenShift VMs
- 3 Infrastructure OpenShift VMs
- 3 Application nodes OpenShift VMs

```bash
$ cd ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/

$ vim ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.ini

[vmware]
# console port and install type for OpenShift
console_port=8443
# choices are: openshift-enterprise or origin
deployment_type=openshift-enterprise

# vCenter host address/username and password
vcenter_host=myvcenter.example.com
vcenter_username=administrator@vsphere.local
vcenter_password=password
... ommitted ...

./ocp-on-vmware.py  

Configured values:

     cluster_id:  0klgsla
     console_port:  8443
     deployment_type:  openshift-enterprise
     openshift_vers:  v3_6
     vcenter_host:  10.*.*.25
     vcenter_username:  administrator@vsphere.local
... ommitted ...
     master_nodes:  3
     infra_nodes:  3
     app_nodes:  3
     storage_nodes:  0
     vm_ipaddr_start:  10.*.*.225
... ommitted ...
     ini_path:  ./ocp-on-vmware.ini
     tag:  None
Continue using these values? [y/N]:
```

### Existing VM Environment and Deployment (Brownfield)
The `ocp-on-vmware.py` script allows for deployments into an existing environment
in which VMs already exists and are subscribed to the proper `RHEL` [channels](https://access.redhat.com/documentation/en/openshift-container-platform/3.6/single/installation-and-configuration/#installing-base-packages).
The prerequisite packages will be installed. The script expects the proper VM annotations are created on the existing VMs. 

The annotation is a combination of a unique` cluster_id` plus the node type:

* app nodes will be labeled with **"-app"** 
* infra nodes labeled with **"-infra"**
* master nodes labeled with **"-master"**

Lastly, the prepared VMs must correspond to the following hardware requirements:

|Node Type | CPUs | Memory | Disk 1 | Disk 2 | Disk 3 | Disk 4 | 
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| Master  | 2 vCPU | 16GB RAM | 1 x 60GB - OS RHEL 7.4 | 1 x 40GB - Docker volume | 1 x 40Gb -  EmptyDir volume | 1 x 40GB - ETCD volume |
| Node | 2 vCPU | 8GB RAM | 1 x 60GB - OS RHEL 7.4 | 1 x 40GB - Docker volume | 1 x 40Gb - EmptyDir volume | |

The *ocp-install* tag will install OpenShift on a pre-existing environment. The dynamic inventory script sorts the VMs by annotations, this is how the proper OpenShift labels are applied.

The *ocp-configure* tag will configure persistent registry and scale nodes.

Notice in the instance below we are supplying our own external NFS server and load balancer.
```bash
$ cd ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/

$ vim ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.ini

cluster_id=my_cluster
... content abbreviated ...

# bringing your own load balancer?
byo_lb=True
lb_host=my-load-balancer.lb.example.com

# bringing your own NFS server for registry?
byo_nfs=True
nfs_registry_host=my-nfs-server.nfs.example.com
nfs_registry_mountpoint=/my-registry

... content abbreviated ...

$ ./ocp-on-vmware.py --tag ocp-install,ocp-configure

Configured values:
... content abbreviated ...
    app_dns_prefix: apps
    vm_dns: 10.*.*.5
    vm_gw: 10.*.*.254
    vm_netmask: 255.255.254.0
    byo_lb: yes
    lb_host: my-load-balancer.lb.example.com
    byo_nfs: yes
    nfs_registry_host: my-nfs-server.nfs.example.com
    nfs_registry_mountpoint: /my-registry
    apps_dns: apps.vcenter.e2e.bos.redhat.com
    Using values from: ./ocp-on-vmware.ini

Continue using these values? [y/N]:

```
### Adding a node to an existing OCP cluster
By default, the reference architecture playbooks are configured to deploy 3 master, 3 application, and 3 infrastructure nodes. As the cluster begins to be utilized by more teams and projects,
it will be become necessary to provision more application or infrastructure nodes to support the expanding environment.  To facilitate easily growing the cluster, the `add-node.py` python script
(similar to `ocp-on-vmware.py`) is provided in the `openshift-ansible-contrib` repository. It will allow for provisioning either an Application or Infrastructure node per run and
can be ran as many times as needed.

#### Adding an app node to the cluster
```bash
$ ./add-node.py --node_type=app
Configured inventory values:
     cluster_id:  0klgsla 
     console_port:  8443
     deployment_type:  openshift-enterprise
     openshift_vers:  v3_6
...omitted...
     node_number:  1
     ini_path:  ./ocp-on-vmware.ini
     node_type:  app

Continue creating the inventory file with these values? [y/N]: y

Inventory file created: add-node.json
host_inventory:
  app-1:
    guestname: app-1
    ip4addr: 10.x.x.230
    tag: app

Continue adding nodes with these values? [y/N]:
```
The process for adding an infra node is identical.

### Container Storage

#### Using CNS or CRS - Container Native Storage or Container Ready Storage

```bash
$ cd /root/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/
$ cat ocp-on-vmware.ini
...omitted...
# folder/cluster/resource pool in vCenter to organize VMs
vcenter_folder=ocp
vcenter_cluster=devel
vcenter_datacenter=Boston
vcenter_resource_pool=OCP3
vcenter_datastore=ose3-vmware
...omitted...
# persistent container storage: none, crs, cns
container_storage=cns

$ ./add-node.py --node_type=storage
Configured inventory values:
     cluster_id:  0klgsla 
     console_port:  8443
     deployment_type:  openshift-enterprise
     openshift_vers:  v3_6
...omitted...
     node_type:  storage

Continue creating the inventory file with these values? [y/N]: y
Gluster topology file created using /dev/sdd: topology.json
Inventory file created: add-node.json
host_inventory:
  app-cns-0:
    guestname: app-cns-0
    ip4addr: 10.*.*.240
    tag: storage
  app-cns-1:
    guestname: app-cns-1
    ip4addr: 10.*.*.241
    tag: storage
  app-cns-2:
    guestname: app-cns-2
    ip4addr: 10.*.*.242
    tag: storage

Continue adding nodes with these values? [y/N]:
```
The process for CRS is different in the playbooks but performed identically. Simply replace container_storage=cns to crs.

### Upgrading an existing OCP cluster

To upgrade an existing cluster to a newer version:

```bash
$ cd ~/openshift-ansible-contrib/reference-architecture/vmware-ansible/ && ./ocp-on-vmware.py --tag ocp-update
```

### TLDR: Steps to install Red Hat OpenShift Cluster Platform

* Clone the git repo and prepare the deploy host.

```bash
# yum install -y git ansible
$ cd ~/git/ && git clone https://github.com/openshift/openshift-ansible-contrib
$ cd ~/git/openshift-ansible-contrib && ansible-playbook playbooks/deploy-host.yaml -e provider=vsphere 
```

* Fill out the variables in the ocp-on-vmware.ini file and run ocp installer.

```bash
$ vim ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.ini
$ cd ~/openshift-ansible-contrib/reference-architecture/vmware-ansible/ && ./ocp-on-vmware.py
```

* Test the install by running ocp-on-vmware.py --tag ocp-demo

```bash
$ cd ~/openshift-ansible-contrib/reference-architecture/vmware-ansible/ && ./ocp-on-vmware.py --tag ocp-demo
```

If installation failures occuring during the ./ocp-on-vmware.py run, simply rerun it.

# OpenStack Provisioning

This repository contains playbooks and Heat templates to provision
OpenStack resources (servers, networking, volumes, security groups,
etc.). The result is an environment ready for openshift-ansible.


## Dependencies for localhost (ansible admin node)

* [Ansible 2.3](https://pypi.python.org/pypi/ansible)
* [shade](https://pypi.python.org/pypi/shade)
* python-dns / [dnspython](https://pypi.python.org/pypi/dnspython)
* Become (sudo) is not required.

## Dependencies for OpenStack hosted cluster nodes (servers)

There are no additional dependencies for the cluster nodes. Required
configuration steps are done by Heat given a specific user data config
that normally should not be changed.

## What does it do

* Create Nova servers with floating IP addresses attached
* Assigns Cinder volumes to the servers
* Set up an `openshift` user with sudo privileges
* Optionally attach Red Hat subscriptions
* Set up a bind-based DNS server
* When deploying more than one master, set up a HAproxy server


## Set up

### Copy the sample inventory

    cp -r openshift-ansible-contrib/playbooks/provisioning/openstack/sample-inventory inventory

### Copy clouds.yaml

    cp openshift-ansible-contrib/playbooks/provisioning/openstack/sample-inventory/clouds.yaml clouds.yaml

### Copy ansible config

    cp openshift-ansible-contrib/playbooks/provisioning/openstack/sample-inventory/ansible.cfg ansible.cfg

### Update `inventory/group_vars/all.yml`

Pay special attention to the values in the first paragraph -- these
will depend on your OpenStack environment.

The `env_id` and `public_dns_domain` will form the cluster's DNS domain all
your servers will be under. With the default values, this will be
`openshift.example.com`. For workloads, the default subdomain is 'apps'.
That sudomain can be set as well by the `openshift_app_domain` variable in
the inventory.

The `public_dns_nameservers` is a list of DNS servers accessible from all
the created Nova servers. These will be serving as your DNS forwarders for
external FQDNs that do not belong to the cluster's DNS domain and its subdomains.

The `openshift_use_dnsmasq` controls either dnsmasq is deployed or not.
By default, dnsmasq is deployed and comes as the hosts' /etc/resolv.conf file
first nameserver entry that points to the local host instance of the dnsmasq
daemon that in turn proxies DNS requests to the authoritative DNS server.
When Network Manager is enabled for provisioned cluster nodes, which is
normally the case, you should not change the defaults and always deploy dnsmasq.

`openstack_ssh_key` is a Nova keypair -- you can see your keypairs with
`openstack keypair list`.

`openstack_default_image_name` is the name of the Glance image the
servers will use. You can
see your images with `openstack image list`.

`openstack_default_flavor` is the Nova flavor the servers will use.
You can see your flavors with `openstack flavor list`.

`openstack_external_network_name` is the name of the Neutron network
providing external connectivity. It is often called `public`,
`external` or `ext-net`. You can see your networks with `openstack
network list`.

The `openstack_num_masters`, `openstack_num_infra` and
`openstack_num_nodes` values specify the number of Master, Infra and
App nodes to create.

The `openstack_flat_secgrp`, controls Neutron security groups creation for Heat
stacks. Set it to true, if you experience issues with sec group rules
quotas. It trades security for number of rules, by sharing the same set
of firewall rules for master, node, etcd and infra nodes.

### Update the DNS names in `inventory/hosts`

The different server groups are currently grouped by the domain name,
so if you end up using a different domain than
`openshift.example.com`, you will need to update the `inventory/hosts`
file.

For example, if your final domain is `my.cloud.com`, you can run this
command to fix update the `hosts` file:

    sed -i 's/openshift.example.com/my.cloud.com/' inventory/hosts

### Configure the OpenShift parameters

Finally, you need to update the DNS entry in
`inventory/group_vars/OSEv3.yml` (look at
`openshift_master_default_subdomain`).

In addition, this is the place where you can customise your OpenShift
installation for example by specifying the authentication.

The full list of options is available in this sample inventory:

https://github.com/openshift/openshift-ansible/blob/master/inventory/byo/hosts.ose.example

Note, that in order to deploy OpenShift origin, you should update the following
variables for the `inventory/group_vars/OSEv3.yml`, `all.yml`:

    deployment_type: origin
    origin_release: 1.5.1
    openshift_deployment_type: "{{ deployment_type }}"

## Deployment

### Run the playbook

Assuming your OpenStack (Keystone) credentials are in the `keystonerc`
file, this is how you stat the provisioning process:

    . keystonerc
    ansible-playbook -i inventory --timeout 30  --private-key ~/.ssh/openshift openshift-ansible-contrib/playbooks/provisioning/openstack/provision.yaml

### Install OpenShift

Once it succeeds, you can install openshift by running:

    ansible-playbook --become --user openshift --private-key ~/.ssh/openshift -i inventory/ openshift-ansible/playbooks/byo/openshift-node/network_manager.yml
    ansible-playbook --become --user openshift --private-key ~/.ssh/openshift -i inventory/ openshift-ansible/playbooks/byo/config.yml

Note, the `network_manager.yml` step is required in order to persist the hosts' DNS config.

## License

As the rest of the openshift-ansible-contrib repository, the code here is
licensed under Apache 2. However, the openstack.py file under
`sample-inventory` is GPLv3+. See the INVENTORY-LICENSE.txt file for the full
text of the license.

#!/usr/bin/env python
# vim: sw=4 ts=4 et

import argparse, click, fileinput, iptools, os, six, sys, yaml

from collections import defaultdict
from six.moves import configparser
from time import time

try:
    import json
except ImportError:
    import simplejson as json

class VMWareAddNode(object):

    __name__ = 'VMWareAddNode'

    openshift_vers=None
    vcenter_host=None
    vcenter_username=None
    vcenter_password=None
    vcenter_template_name=None
    vcenter_folder=None
    vcenter_cluster=None
    vcenter_datacenter=None
    vcenter_resource_pool=None
    vm_dns=None
    vm_gw=None
    vm_netmask=None
    rhel_subscription_server=None
    openshift_sdn=None
    byo_lb=None
    lb_host=None
    byo_nfs=None
    nfs_registry_host=None
    nfs_registry_mountpoint=None
    master_nodes=None
    infra_nodes=None
    app_nodes=None
    vm_ipaddr_start=None
    ocp_hostname_prefix=None
    auth_type=None
    ldap_user=None
    ldap_user_password=None
    ldap_fqdn=None
    deployment_type=None
    console_port=8443
    rhel_subscription_user=None
    rhel_subscription_pass=None
    rhel_subscription_pool=None
    public_hosted_zone=None
    app_dns_prefix=None
    wildcard_zone=None
    inventory_file='add-node.json'
    support_nodes=None
    node_type=None
    node_number=None
    verbose=0

    def __init__(self, load=True):

        if load:
            self.parse_cli_args()
            self.read_ini_settings()
        if not os.path.exists(self.inventory_file) or self.args.create_inventory:
            self.create_inventory_file()
        if os.path.exists(self.inventory_file):
            self.launch_refarch_env()

    def parse_cli_args(self):

        ''' Command line argument processing '''

        parser = argparse.ArgumentParser(description='Add new nodes to an existing OCP deployment')
        parser.add_argument('--node_type', action='store', default='app', help='Specify the node label')
        parser.add_argument('--node_number', action='store', default='1', help='Specify the number of nodes to add')
        parser.add_argument('--create_inventory', action='store_true', help='Helper script to create json inventory file and exit')
        parser.add_argument('--no_confirm', default=None, help='Skip confirmation prompt')
        parser.add_argument('--verbose', default=None, action='store_true', help='Verbosely display commands')
        self.args = parser.parse_args()
        self.verbose = self.args.verbose

    def read_ini_settings(self):

        ''' Read ini file settings '''

        scriptbasename = "ocp-on-vmware"
        defaults = {'vmware': {
            'ini_path': os.path.join(os.path.dirname(__file__), '%s.ini' % scriptbasename),
            'console_port':'8443',
            'deployment_type':'openshift-enterprise',
            'openshift_vers':'v3_4',
            'vcenter_host':'',
            'vcenter_username':'administrator@vsphere.local',
            'vcenter_password':'',
            'vcenter_template_name':'ocp-server-template-2.0.2',
            'vcenter_folder':'ocp',
            'vcenter_cluster':'devel',
            'vcenter_cluster':'',
            'vcenter_resource_pool':'/Resources/OCP3',
            'public_hosted_zone':'',
            'app_dns_prefix':'apps',
            'vm_dns':'',
            'vm_gw':'',
            'vm_netmask':'',
            'vm_network':'VM Network',
            'rhel_subscription_user':'',
            'rhel_subscription_pass':'',
            'rhel_subscription_server':'',
            'rhel_subscription_pool':'Red Hat OpenShift Container Platform, Premium*',
            'openshift_sdn':'redhat/openshift-ovs-subnet',
            'byo_lb':'no',
            'lb_host':'haproxy-',
            'byo_nfs':'no',
            'nfs_registry_host':'nfs-0',
            'nfs_registry_mountpoint':'/exports',
            'master_nodes':'3',
            'infra_nodes':'2',
            'app_nodes':'3',
            'vm_ipaddr_start':'',
            'ocp_hostname_prefix':'',
            'auth_type':'ldap',
            'ldap_user':'openshift',
            'ldap_user_password':'',
            'node_type': self.args.node_type,
            'node_number':self.args.node_number,
            'ldap_fqdn':'' }
            }
        if six.PY3:
            config = configparser.ConfigParser()
        else:
            config = configparser.SafeConfigParser()

        # where is the config?
        vmware_ini_path = os.environ.get('VMWARE_INI_PATH', defaults['vmware']['ini_path'])
        vmware_ini_path = os.path.expanduser(os.path.expandvars(vmware_ini_path))
        config.read(vmware_ini_path)

        # apply defaults
        for k,v in defaults['vmware'].iteritems():
            if not config.has_option('vmware', k):
                config.set('vmware', k, str(v))

        self.console_port = config.get('vmware', 'console_port')
        self.deployment_type = config.get('vmware','deployment_type')
        self.openshift_vers = config.get('vmware','openshift_vers')
        self.vcenter_host = config.get('vmware', 'vcenter_host')
        self.vcenter_username = config.get('vmware', 'vcenter_username')
        self.vcenter_password = config.get('vmware', 'vcenter_password')
        self.vcenter_template_name = config.get('vmware', 'vcenter_template_name')
        self.vcenter_folder = config.get('vmware', 'vcenter_folder')
        self.vcenter_cluster = config.get('vmware', 'vcenter_cluster')
        self.vcenter_datacenter = config.get('vmware', 'vcenter_datacenter')
        self.vcenter_resource_pool = config.get('vmware', 'vcenter_resource_pool')
        self.public_hosted_zone= config.get('vmware', 'public_hosted_zone')
        self.app_dns_prefix = config.get('vmware', 'app_dns_prefix')
        self.vm_dns = config.get('vmware', 'vm_dns')
        self.vm_gw = config.get('vmware', 'vm_gw')
        self.vm_netmask = config.get('vmware', 'vm_netmask')
        self.vm_network = config.get('vmware', 'vm_network')
        self.rhel_subscription_user = config.get('vmware', 'rhel_subscription_user')
        self.rhel_subscription_pass = config.get('vmware', 'rhel_subscription_pass')
        self.rhel_subscription_server = config.get('vmware', 'rhel_subscription_server')
        self.rhel_subscription_pool = config.get('vmware', 'rhel_subscription_pool')
        self.openshift_sdn = config.get('vmware', 'openshift_sdn')
        self.byo_lb = config.get('vmware', 'byo_lb')
        self.lb_host = config.get('vmware', 'lb_host')
        self.byo_nfs = config.get('vmware', 'byo_nfs')
        self.nfs_registry_host = config.get('vmware', 'nfs_registry_host')
        self.nfs_registry_mountpoint = config.get('vmware', 'nfs_registry_mountpoint')
        self.master_nodes = config.get('vmware', 'master_nodes')
        self.infra_nodes = config.get('vmware', 'infra_nodes')
        self.app_nodes = config.get('vmware', 'app_nodes')
        self.vm_ipaddr_start = config.get('vmware', 'vm_ipaddr_start')
        self.ocp_hostname_prefix = config.get('vmware', 'ocp_hostname_prefix')
        self.auth_type = config.get('vmware', 'auth_type')
        self.ldap_user = config.get('vmware', 'ldap_user')
        self.ldap_user_password = config.get('vmware', 'ldap_user_password')
        self.ldap_fqdn = config.get('vmware', 'ldap_fqdn')
        self.node_type = config.get('vmware', 'node_type')
        self.node_number = config.get('vmware', 'node_number')
        err_count=0

        required_vars = {'public_hosted_zone':self.public_hosted_zone, 'vcenter_host':self.vcenter_host, 'vcenter_password':self.vcenter_password, 'vm_ipaddr_start':self.vm_ipaddr_start, 'ldap_fqdn':self.ldap_fqdn, 'ldap_user_password':self.ldap_user_password, 'vm_dns':self.vm_dns, 'vm_gw':self.vm_gw, 'vm_netmask':self.vm_netmask, 'vcenter_datacenter':self.vcenter_datacenter}
        for k, v in required_vars.items():
            if v == '':
                err_count += 1
                print "Missing %s " % k
        if err_count > 0:
            print "Please fill out the missing variables in %s " %  vmware_ini_path
            exit (1)
        self.wildcard_zone="%s.%s" % (self.app_dns_prefix, self.public_hosted_zone)
        self.support_nodes=0

        print 'Configured inventory values:'
        for each_section in config.sections():
            for (key, val) in config.items(each_section):
                print '\t %s:  %s' % ( key,  val )

    def create_inventory_file(self):

        if not self.args.no_confirm:
            if not click.confirm('Continue creating the inventory file with these values?'):
                sys.exit(0)
        if self.byo_nfs == "no":
            self.support_nodes=self.support_nodes+1
        if self.byo_lb == "no":
            self.support_nodes=self.support_nodes+1

        total_nodes=int(self.master_nodes)+int(self.app_nodes)+int(self.infra_nodes)+int(self.support_nodes)+int(self.node_number)
        nodes_remove=int(self.master_nodes)+int(self.app_nodes)+int(self.infra_nodes)+int(self.support_nodes)

        ip4addr = []
        for i in range(total_nodes):
            p = iptools.ipv4.ip2long(self.vm_ipaddr_start) + i
            ip4addr.append(iptools.ipv4.long2ip(p))

        unusedip4addr = []
        for i in range(0, int(self.node_number)):
            unusedip4addr.insert(0, ip4addr.pop())

        d = {}
        d['host_inventory'] = {}
        for i in range(0, int(self.node_number)):
            #determine node_number increment on the number of nodes 
            if self.node_type == 'app':
                node_ip = int(self.app_nodes) + i
                guest_name = self.node_type + '-' + str(node_ip)
            if self.node_type == 'infra':
                node_ip = int(self.infra_nodes) + i
                guest_name = self.node_type + '-' + str(node_ip)
            if self.ocp_hostname_prefix:
                guest_name = self.ocp_hostname_prefix + guest_name
            d['host_inventory'][guest_name] = {}
            d['host_inventory'][guest_name]['guestname'] = guest_name
            d['host_inventory'][guest_name]['ip4addr'] = unusedip4addr[0]
            d['host_inventory'][guest_name]['tag'] = self.node_type
            del unusedip4addr[0]
        with open(self.inventory_file, 'w') as outfile:
            json.dump(d, outfile)

        print 'Inventory file created: %s' % self.inventory_file

        if self.byo_lb == "no":
            lb_host_fqdn = "%s.%s" % (self.lb_host, self.public_hosted_zone)
            self.lb_host = lb_host_fqdn
        # Provide values for update and add node playbooks       
        update_file = ["playbooks/node-setup.yaml"]
        for line in fileinput.input(update_file, inplace=True):
            if line.startswith("    load_balancer_hostname:"):
                print "    load_balancer_hostname: " + self.lb_host
            elif line.startswith("    deployment_type:"):
                print "    deployment_type: " + self.deployment_type
            else:
                print line,

    def launch_refarch_env(self):

        print '\n'
        inventory_file = open(self.inventory_file, 'r')
        print inventory_file.read()

        if not self.args.no_confirm:
            if not click.confirm('Continue adding nodes with these values?'):
                sys.exit(0)

        playbooks = ['playbooks/add-node.yaml']

        for playbook in playbooks:

            devnull='> /dev/null'

            if self.verbose > 0:
                devnull=''

            # refresh the inventory cache to prevent stale hosts from
            # interferring with re-running
            command='inventory/vsphere/vms/vmware_inventory.py %s' % (devnull)
            os.system(command)

            # remove any cached facts to prevent stale data during a re-run
            command='rm -rf .ansible/cached_facts'
            os.system(command)

            command='ansible-playbook'
            command=command + ' --extra-vars "@./add-node.json" -e \' add_node=yes vcenter_host=%s \
            vcenter_username=%s \
            vcenter_password=%s \
            vcenter_template_name=%s \
            vcenter_folder=%s \
            vcenter_cluster=%s \
            vcenter_datacenter=%s \
            vcenter_resource_pool=%s \
            public_hosted_zone=%s \
            app_dns_prefix=%s \
            vm_dns=%s \
            vm_gw=%s \
            vm_netmask=%s \
            vm_network=%s \
            wildcard_zone=%s \
            console_port=%s \
            deployment_type=%s \
            openshift_vers=%s \
            rhel_subscription_user=%s \
            rhel_subscription_pass=%s \
            rhel_subscription_server=%s \
            rhel_subscription_pool="%s" \
            openshift_sdn=%s \
            lb_host=%s \
            nfs_registry_host=%s \
            nfs_registry_mountpoint=%s \' %s' % ( self.vcenter_host,
                            self.vcenter_username,
                            self.vcenter_password,
                            self.vcenter_template_name,
                            self.vcenter_folder,
                            self.vcenter_cluster,
                            self.vcenter_datacenter,
                            self.vcenter_resource_pool,
                            self.public_hosted_zone,
                            self.app_dns_prefix,
                            self.vm_dns,
                            self.vm_gw,
                            self.vm_netmask,
                            self.vm_network,
                            self.wildcard_zone,
                            self.console_port,
                            self.deployment_type,
                            self.openshift_vers,
                            self.rhel_subscription_user,
                            self.rhel_subscription_pass,
                            self.rhel_subscription_server,
                            self.rhel_subscription_pool,
                            self.openshift_sdn,
                            self.lb_host,
                            self.nfs_registry_host,
                            self.nfs_registry_mountpoint,
                            playbook)

            if self.verbose > 0:
                command += " -vvvvv" 
                click.echo('We are running: %s' % command)

            status = os.system(command)
            if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
                return os.WEXITSTATUS(status)

if __name__ == '__main__':

    VMWareAddNode()

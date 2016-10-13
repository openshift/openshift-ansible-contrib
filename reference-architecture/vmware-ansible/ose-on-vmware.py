#!/usr/bin/env python
# vim: sw=2 ts=2

import click, os, sys, fileinput, json, iptools, ldap

@click.command()

### Cluster options
@click.option('--console_port', default='8443', type=click.IntRange(1,65535), help='OpenShift web console port',
              show_default=True)
@click.option('--deployment_type', default='openshift-enterprise', help='OpenShift deployment type',
              show_default=True)

### VMware  options
@click.option('--vcenter_host', default='10.19.114.221', help='vCenter IP Address',
              show_default=True)
@click.option('--vcenter_username', default='administrator@vsphere.local', help='vCenter Username',
              show_default=True)
@click.option('--vcenter_password', default='P@ssw0rd', help='vCenter Password',
              show_default=True, hide_input=True)
@click.option('--vcenter_template_name', default='ose3-server-template-2.0.2', help='Pre-created VMware Template with RHEL 7.2',
              show_default=True)
@click.option('--vcenter_folder', default='ose3', help='Folder in vCenter to store VMs',
              show_default=True)
@click.option('--vcenter_cluster', default='devel', help='vCenter cluster to utilize',
              show_default=True)
@click.option('--vcenter_resource_pool', default='/Resources/OSE3', help='Resource Pools to use in vCenter',
              show_default=True)

### DNS options
@click.option('--public_hosted_zone', default='vcenter.e2e.bos.redhat.com', help='hosted zone for accessing the environment')
@click.option('--app_dns_prefix', default='apps', help='application dns prefix',
              show_default=True)
@click.option('--vm_dns', default='10.19.114.5', help='DNS server for OpenShift nodes to utilize',
              show_default=True)
@click.option('--vm_gw', default='10.19.115.254', help='Gateway network address for VMs',
              show_default=True)
@click.option('--vm_interface_name', default='eno16780032', help='Network Interace card in template',
              show_default=True)

### Subscription and Software options
@click.option('--rhsm_user', help='Red Hat Subscription Management User')
@click.option('--rhsm_password', help='Red Hat Subscription Management Password',
                hide_input=True,)
@click.option('--rhsm_activation_key',  help='Red Hat Subscription Management User')
@click.option('--rhsm_org_id',  help='Red Hat Subscription Management Password')
@click.option('--rhsm_pool', help='Red Hat Subscription Management Pool ID or Subscription Name', default="OpenShift Enterprise, Premium*", show_default=True)

### Miscellaneous options
@click.option('--byo_lb', default='no', help='skip haproxy install when one exists within the environment',
              show_default=True)
@click.option('--lb_fqdn', default='haproxy-0', help='Used for OpenShift cluster hostname and public hostname',
              show_default=True)

@click.option('--byo_nfs', default='no', help='skip nfs install when one exists within the environment',
              show_default=True)
@click.option('--nfs_registry_host', default='nfs-0', help='NFS server for persistent registry',
              show_default=True)
@click.option('--nfs_registry_mountpoint', default='/registry', help='NFS share for persistent registry',
              show_default=True)

@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)
@click.option('-t', '--tag', help='Ansible playbook tag for specific parts of playbook')
@click.option('-l', '--local', is_flag=True,help='Local installation of ansible instead of our container')
# Create inventory options
@click.option('--create_inventory', is_flag=True, help='Helper script to create json inventory file and exit')
@click.option('--master_nodes', default='3', help='Number of master nodes to create', show_default=True)
@click.option('--infra_nodes', default='2', help='Number of infra nodes to create', show_default=True)
@click.option('--app_nodes', default='3', help='Number of app nodes to create', show_default=True)
@click.option('--vm_ipaddr_start', default='10.19.114.224', help='Starting IP address to use')
@click.option('--ose_hostname_prefix', default=None, help='A prefix for your VM guestnames and DNS names: e.g. ose3-', show_default=True)

#Create OpenShift Ansible variables
@click.option('--create_ose_vars', is_flag=True, help='Helper script to modify OpenShift ansible install variables and exit')
@click.option('--ldap_user', default='openshift', help='User to bind LDAP to')
@click.option('--ldap_user_password', default='password', help='LDAP User password')
@click.option('--ldap_fqdn', default='e2e.bos.redhat.com', help='LDAP FQDN to build bindURL')
# Need load balancer FQDN here and to check for byo_lb

def launch_refarch_env(console_port=8443,
                    deployment_type=None,
                    vcenter_host=None,
                    vcenter_username=None,
                    vcenter_password=None,
                    vcenter_template_name=None,
		    vcenter_folder=None,
                    vcenter_cluster=None,
                    vcenter_resource_pool=None,
                    public_hosted_zone=None,
                    app_dns_prefix=None,
                    vm_dns=None,
                    vm_gw=None,
                    vm_interface_name=None,
                    rhsm_user=None,
                    rhsm_password=None,
                    rhsm_activation_key=None,
                    rhsm_org_id=None,
                    rhsm_pool=None,
                    byo_lb=None,
                    lb_fqdn=None,
                    byo_nfs=None,
                    nfs_registry_host=None,
                    nfs_registry_mountpoint=None,
                    no_confirm=False,
		    tag=None,
                    verbose=0,
		    local=None,
		    create_inventory=None,
		    master_nodes=None,
		    infra_nodes=None,
		    app_nodes=None,
		    vm_ipaddr_start=None,
		    ose_hostname_prefix=None,
	  	    create_ose_vars=None,
		    ldap_user=None,
		    ldap_user_password=None,
		    ldap_fqdn=None):

  # Need to prompt for the DNS zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  # If tag exists skip the auth portion
  if not tag:
  # If the user already provided values, don't bother asking again
  	if rhsm_user is None and rhsm_activation_key is None:
    		rhsm_user = click.prompt("RHSM username?")
  	if rhsm_password is None and rhsm_user:
    		rhsm_password = click.prompt("RHSM password?", hide_input=True, confirmation_prompt=True)

	if rhsm_activation_key is None and rhsm_user is None:
    		rhsm_activation_key = click.prompt("Satellite Server Activation Key?")
  	if rhsm_org_id is None and rhsm_activation_key:
    		rhsm_org_id = click.prompt("Organization ID for Satellite Server?")
  	if rhsm_pool is None:
    		rhsm_pool = click.prompt("RHSM Pool ID or Subscription Name?")
  # Calculate various DNS values
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  tags = []
  
  # Our initial support node is the wildcard_ip
  support_nodes=1
  if byo_nfs == "no":
      support_nodes=support_nodes+1
      nfs_host = nfs_registry_host
      nfs_registry_host = nfs_host + '.' + public_hosted_zone
      nfs_registry_mountpoint ='/registry'
      tags.append('nfs')
  else:
  	if nfs_registry_host is None:
  		nfs_registry_host = click.prompt("Please enter the NFS Server fqdn for persistent registry:")
	if nfs_registry_mountpoint is None:
  		nfs_registry_mountpoint = click.prompt("Please enter NFS share name for persistent registry:")

  tags.append('prod')

  if byo_lb == "no":
      lb_host = lb_fqdn
      lb_fqdn = lb_host + '.' + public_hosted_zone
      tags.append('haproxy')
  else:
  	if lb_fqdn is None:
  		lb_fqdn = click.prompt("Please enter the load balancer fqdn for installation:")

  if create_ose_vars is True:
  	click.echo('Configured OSE variables:')
	click.echo('\tldap_fqdn: %s' % ldap_fqdn)
	click.echo('\tldap_user: %s' % ldap_user)
  	click.echo('\tldap_user_password: %s' % ldap_user_password)
	click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
        click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
  	click.echo('\tbyo_lb: %s' % byo_lb)
  	click.echo('\tlb_host: %s' % lb_host)
	
	if not no_confirm:
    		click.confirm('Continue using these values?', abort=True)

	l_bdn = ""

	for d in ldap_fqdn.split("."):
        	l_bdn = l_bdn + "dc=" + d + ","

	l = ldap.initialize("ldap://" + ldap_fqdn)
	try:
    		l.protocol_version = ldap.VERSION3
		l.set_option(ldap.OPT_REFERRALS, 0)

		bind = l.simple_bind_s(ldap_user, ldap_user_password)

    		base = l_bdn[:-1]
    		criteria = "(&(objectClass=user)(sAMAccountName=" + ldap_user + "))"
    		attributes = 'displayName', 'distinguishedName'
    		result = l.search_s(base, ldap.SCOPE_SUBTREE, criteria, attributes)

    		results = [entry for dn, entry in result if isinstance(entry, dict)]
	finally:
    		l.unbind()

	for result in results:

        	bindDN = str(result['distinguishedName']).strip("'[]")
	        url_base = bindDN.replace(("CN=" + ldap_user + ","), "")
	        url = "ldap://" + ldap_fqdn + ":389/" + url_base + "?sAMAccountName"
	
	install_file = "openshift-install.yaml"

	for line in fileinput.input(install_file, inplace=True):
	# Parse our ldap url
        	if line.startswith("      url:"):
                	print "      url: " + url
	        elif line.startswith("      bindPassword:"):
        	        print "      bindPassword: " + ldap_user_password
	        elif line.startswith("      bindDN:"):
        	        print "      bindDN: " + bindDN
	        elif line.startswith("    wildcard_zone:"):
        	        print "    wildcard_zone: " + app_dns_prefix + "." + public_hosted_zone
	        elif line.startswith("    load_balancer_hostname:"):
        	        print "    load_balancer_hostname: " + lb_host + "." + public_hosted_zone
        	else:
                	print line,
	 
  if create_inventory is True:
  	click.echo('Configured inventory values:')
	click.echo('\tmaster_nodes: %s' % master_nodes)
	click.echo('\tinfra_nodes: %s' % infra_nodes)
  	click.echo('\tapp_nodes: %s' % app_nodes)
  	click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  	click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
	click.echo('\tose_hostname_prefix: %s' % ose_hostname_prefix)
  	click.echo('\tbyo_nfs: %s' % byo_nfs)
	if byo_nfs == "no":
  		click.echo('\tnfs_host: %s' % nfs_host)
	  	click.echo('\tbyo_lb: %s' % byo_lb)
	if byo_lb == "no":
  		click.echo('\tlb_host: %s' % lb_host)
	  	click.echo('\tvm_ipaddr_start: %s' % vm_ipaddr_start)
	click.echo("")
	if not no_confirm:
    		click.confirm('Continue using these values?', abort=True)	
	# Create the inventory file and exit 
	total_nodes=int(master_nodes)+int(app_nodes)+int(infra_nodes)+int(support_nodes)

	if vm_ipaddr_start is None:
    		vm_ipaddr_start = click.prompt("Starting IP address to use?")
	
	ip4addr = []
	for i in range(total_nodes):
	        p = iptools.ipv4.ip2long(vm_ipaddr_start) + i
		ip4addr.append(iptools.ipv4.long2ip(p))
	wild_ip =  ip4addr.pop()

	bind_entry = []
	bind_entry.append("$ORIGIN " + app_dns_prefix + "." + public_hosted_zone + ".")
	bind_entry.append("*    A       " + wild_ip)
	bind_entry.append("$ORIGIN " + public_hosted_zone + ".")

	d = {}
	d['host_inventory'] = {}
	d['infrastructure_hosts'] = {}	

	support_list = []
	if byo_nfs == "no":
		d['host_inventory'][nfs_host] = {}
        	d['host_inventory'][nfs_host]['guestname'] = nfs_host
		d['host_inventory'][nfs_host]['ip4addr'] = ip4addr[0]
	        d['host_inventory'][nfs_host]['tag'] = "infra-nfs"
        	d['infrastructure_hosts']["nfs_server"] = {}
	        d['infrastructure_hosts']["nfs_server"]['guestname'] = nfs_host
        	d['infrastructure_hosts']["nfs_server"]['tag'] = "infra-nfs"
	        support_list.append(nfs_host)
        	bind_entry.append(nfs_host + "		A       " + ip4addr[0])
	        del ip4addr[0]
	if byo_lb == "no":
	        d['host_inventory'][lb_host] = {}
        	d['host_inventory'][lb_host]['guestname'] = lb_host
	        d['host_inventory'][lb_host]['ip4addr'] = wild_ip
       		d['host_inventory'][lb_host]['tag'] = "loadbalancer"
	        d['infrastructure_hosts']["haproxy"] = {}
        	d['infrastructure_hosts']["haproxy"]['guestname'] = lb_host
	        d['infrastructure_hosts']["haproxy"]['tag'] = "loadbalancer"
        	support_list.append(lb_host)
	        bind_entry.append(lb_host + "		A       " + wild_ip)

	master_list = []
	d['production_hosts'] = {}
	for i in range(0, int(master_nodes)):
		if ose_hostname_prefix is not None:
			master_name=ose_hostname_prefix+"master-"+str(i)
		else:
                	master_name="master-"+str(i)
        	d['host_inventory'][master_name] = {}
	        d['host_inventory'][master_name]['guestname'] = master_name
       		d['host_inventory'][master_name]['ip4addr'] = ip4addr[0]
	        d['host_inventory'][master_name]['tag'] = "master"
        	d['production_hosts'][master_name] = {}
	        d['production_hosts'][master_name]['guestname'] = master_name
	        d['production_hosts'][master_name]['tag'] = "master"
	        master_list.append(master_name)
	        bind_entry.append(master_name + "	A       " + ip4addr[0])
	        del ip4addr[0]
	app_list = []
	for i in range(0, int(app_nodes)):
        	if ose_hostname_prefix is not None:
                	app_name=ose_hostname_prefix+"app-"+str(i)

	        else:
        	        app_name="app-"+str(i)

		d['host_inventory'][app_name] = {}
	        d['host_inventory'][app_name]['guestname'] = app_name
       		d['host_inventory'][app_name]['ip4addr'] = ip4addr[0]
	        d['host_inventory'][app_name]['tag'] = "app"
       		d['production_hosts'][app_name] = {}
	        d['production_hosts'][app_name]['guestname'] = app_name
       		d['production_hosts'][app_name]['tag'] = "app"
	        app_list.append(app_name)
        	bind_entry.append(app_name + "		A       " + ip4addr[0])
	        del ip4addr[0]
	infra_list = []
	for i in range(0, int(infra_nodes)):
        	if ose_hostname_prefix is not None:
                	infra_name=ose_hostname_prefix+"infra-"+str(i)
		else:
                	infra_name="infra-"+str(i)
		d['host_inventory'][infra_name] = {}
	        d['host_inventory'][infra_name]['guestname'] = infra_name
        	d['host_inventory'][infra_name]['ip4addr'] = ip4addr[0]
	        d['host_inventory'][infra_name]['tag'] = "infra"
       		d['production_hosts'][infra_name] = {}
	        d['production_hosts'][infra_name]['guestname'] = infra_name
       		d['production_hosts'][infra_name]['tag'] = "infra"
	        infra_list.append(infra_name)
        	bind_entry.append(infra_name + "        A       " + ip4addr[0])
	        del ip4addr[0]
	print "# Here is what should go into your DNS records"
	print("\n".join(bind_entry))
	print "# Please note, if you have chosen to bring your own loadbalancer and NFS Server you will need to ensure that these records are added to DNS and properly resolve. "

	with open('infrastructure.json', 'w') as outfile:
	    json.dump(d, outfile)
	exit(0)
  # Display information to the user about their choices
  click.echo('Configured values:')
  click.echo('\tconsole port: %s' % console_port)
  click.echo('\tdeployment_type: %s' % deployment_type)
  click.echo('\tvcenter_host: %s' % vcenter_host)
  click.echo('\tvcenter_username: %s' % vcenter_username)
  click.echo('\tvcenter_password: *******')
  click.echo('\tvcenter_template_name: %s' % vcenter_template_name)
  click.echo('\tvcenter_folder: %s' % vcenter_folder)
  click.echo('\tvcenter_cluster: %s' % vcenter_cluster)
  click.echo('\tvcenter_resource_pool: %s' % vcenter_resource_pool)

  click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
  click.echo('\tvm_dns: %s' % vm_dns)
  click.echo('\tvm_gw: %s' % vm_gw)
  click.echo('\tvm_interface_name: %s' % vm_interface_name)

  if rhsm_user is not None and tag is not None:
	  click.echo('\trhsm_user: %s' % rhsm_user)
	  click.echo('\trhsm_password: *******')


  if rhsm_activation_key is not None and tag is not None:
	  click.echo('\trhsm_activation_key: %s' % rhsm_activation_key)
	  click.echo('\trhsm_org_id: rhsm_org_id')

  click.echo('\tbyo_lb: %s' % byo_lb)
  click.echo('\tlb_fqdn: %s' % lb_fqdn)
  click.echo('\tbyo_nfs: %s' % byo_nfs)
  click.echo('\tnfs_registry_host: %s' % nfs_registry_host)
  click.echo('\tnfs_registry_mountpoint: %s' % nfs_registry_mountpoint)

  click.echo('\tapps_dns: %s' % wildcard_zone)

  click.echo("")

  if not no_confirm:
    click.confirm('Continue using these values?', abort=True)

  if not os.path.isfile('infrastructure.json'):
	print "Please create your inventory file first by running the --create_inventory flag"
  	exit (1)

  inventory_file = "inventory/vsphere/vms/vmware_inventory.ini"
  # Add section here to modify inventory file based on input from user check your vmmark scripts for parsing the file and adding the values
  for line in fileinput.input(inventory_file, inplace=True):
  	if line.startswith("server="):
                print "server=" + vcenter_host
        elif line.startswith("password="):
                print "password=" + vcenter_password
        elif line.startswith("username="):
                print "username=" + vcenter_username
        else:
                print line,

  playbooks = ['infrastructure.yaml']
  tags.append('ose-install')
  tags.append('ose-configure')

  for playbook in playbooks:
    # hide cache output unless in verbose mode
    devnull='> /dev/null'

    if verbose > 0:
      devnull=''

    # make sure the ssh keys have the proper permissions
    command='chmod 600 ssh_key/ose3-installer'
    os.system(command)

    # remove any cached facts to prevent stale data during a re-run
    command='rm -rf .ansible/cached_facts'
    os.system(command)
    tags = ",".join(tags)
    if tag:
	tags = tag
    
    if local:
	command='ansible-playbook'
    else:
	command='docker run -t --rm --volume `pwd`:/opt/ansible:z -v ~/.ssh:/root/.ssh:z -v /tmp:/tmp:z --net=host ansible:2.2-latest'

    command=command + ' --extra-vars "@./infrastructure.json" --tags %s -e \'vcenter_host=%s \
    vcenter_username=%s \
    vcenter_password=%s \
    vcenter_template_name=%s \
    vcenter_folder=%s \
    vcenter_cluster=%s \
    vcenter_resource_pool=%s \
    public_hosted_zone=%s \
    app_dns_prefix=%s \
    vm_dns=%s \
    vm_gw=%s \
    vm_interface_name=%s \
    wildcard_zone=%s \
    console_port=%s \
    deployment_type=%s \
    rhsm_user=%s \
    rhsm_password=%s \
    rhsm_activation_key=%s \
    rhsm_org_id=%s \
    rhsm_pool=%s \
    lb_fqdn=%s \
    nfs_registry_host=%s \
    nfs_registry_mountpoint=%s \' %s' % ( tags,
		    vcenter_host,
                    vcenter_username,
                    vcenter_password,
                    vcenter_template_name,
                    vcenter_folder,
                    vcenter_cluster,
                    vcenter_resource_pool,
                    public_hosted_zone,
                    app_dns_prefix,
                    vm_dns,
                    vm_gw,
                    vm_interface_name,
                    wildcard_zone,
                    console_port,
                    deployment_type,
                    rhsm_user,
                    rhsm_password,
                    rhsm_activation_key,
                    rhsm_org_id,
		    rhsm_pool,
                    lb_fqdn,
                    nfs_registry_host,
                    nfs_registry_mountpoint,
                    playbook)
    if verbose > 0:
      command += " -" + "".join(['v']*verbose)
      click.echo('We are running: %s' % command)

    status = os.system(command)
    if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
      return os.WEXITSTATUS(status)

if __name__ == '__main__':

  launch_refarch_env(auto_envvar_prefix='OSE_REFArch')

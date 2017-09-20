#!/usr/bin/env python
# set ts=4 sw=4 et
import click, os, sys, fileinput, json, iptools, ldap, six, random
from argparse import RawTextHelpFormatter
from six.moves import configparser

@click.command()

### Cluster options
@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)
@click.option('--create_inventory', is_flag=True, help='Helper script to create json inventory file and exit')
@click.option('--create_ocp_vars', is_flag=True, help='Helper script to modify OpenShift ansible install variables and exit')
@click.option('-t', '--tag', help='Ansible playbook tag for specific parts of playbook: valid targets are setup, nfs, prod, haproxy, ocp-install, ocp-configure, ocp-demo, ocp-update or clean')
@click.option('--clean', is_flag=True, help='Delete all nodes and unregister from RHN')

def launch_refarch_env(console_port=8443,
                    cluster_id=None,
                    deployment_type=None,
                    openshift_vers=None,
                    vcenter_host=None,
                    vcenter_username=None,
                    vcenter_password=None,
                    vcenter_template_name=None,
                    vcenter_folder=None,
                    vcenter_cluster=None,
                    vcenter_datacenter=None,
                    vcenter_datastore=None,
                    vcenter_resource_pool=None,
                    public_hosted_zone=None,
                    app_dns_prefix=None,
                    vm_dns=None,
                    vm_gw=None,
                    vm_netmask=None,
                    vm_network=None,
                    rhel_subscription_user=None,
                    rhel_subscription_pass=None,
                    rhel_subscription_server=None,
                    rhel_subscription_pool=None,
                    byo_lb=None,
                    lb_host=None,
                    byo_nfs=None,
                    nfs_host=None,
                    nfs_registry_mountpoint=None,
                    no_confirm=False,
                    tag=None,
                    verbose=0,
                    create_inventory=None,
                    master_nodes=None,
                    infra_nodes=None,
                    app_nodes=None,
                    vm_ipaddr_start=None,
                    ocp_hostname_prefix=None,
                    create_ocp_vars=None,
                    auth_type=None,
                    ldap_user=None,
                    ldap_user_password=None,
                    ldap_fqdn=None,
                    openshift_sdn=None,
                    containerized=None,
                    container_storage=None,
                    openshift_hosted_metrics_deploy=None,
                    clean=None):

  # Open config file INI for values first
  scriptbasename = __file__
  scriptbasename = os.path.basename(scriptbasename)
  scriptbasename = scriptbasename.replace('.py', '')
  defaults = {'vmware': {
    'ini_path': os.path.join(os.path.dirname(__file__), '%s.ini' % scriptbasename),
    'console_port':'8443',
    'deployment_type':'openshift-enterprise',
    'openshift_vers':'v3_5',
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
    'containerized':'containerized',
    'container_storage':'none',
    'openshift_hosted_metrics_deploy':'false',
    'byo_lb':'no',
    'lb_host':'haproxy-',
    'byo_nfs':'no',
    'nfs_host':'nfs-0',
    'nfs_registry_mountpoint':'/exports',
    'master_nodes':'3',
    'infra_nodes':'2',
    'app_nodes':'3',
    'vm_ipaddr_start':'',
    'ocp_hostname_prefix':'',
    'auth_type':'ldap',
    'ldap_user':'openshift',
    'ldap_user_password':'',
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

  cluster_id = config.get('vmware', 'cluster_id')
  console_port = config.get('vmware', 'console_port')
  deployment_type = config.get('vmware','deployment_type')
  openshift_vers = config.get('vmware','openshift_vers')
  vcenter_host = config.get('vmware', 'vcenter_host')
  vcenter_username = config.get('vmware', 'vcenter_username')
  vcenter_password = config.get('vmware', 'vcenter_password')
  vcenter_template_name = config.get('vmware', 'vcenter_template_name')
  vcenter_folder = config.get('vmware', 'vcenter_folder')
  vcenter_cluster = config.get('vmware', 'vcenter_cluster')
  vcenter_datacenter = config.get('vmware', 'vcenter_datacenter')
  vcenter_datastore = config.get('vmware', 'vcenter_datastore')
  vcenter_resource_pool = config.get('vmware', 'vcenter_resource_pool')
  public_hosted_zone= config.get('vmware', 'public_hosted_zone')
  app_dns_prefix = config.get('vmware', 'app_dns_prefix')
  vm_dns = config.get('vmware', 'vm_dns')
  vm_gw = config.get('vmware', 'vm_gw')
  vm_netmask = config.get('vmware', 'vm_netmask')
  vm_network = config.get('vmware', 'vm_network')
  rhel_subscription_user = config.get('vmware', 'rhel_subscription_user')
  rhel_subscription_pass = config.get('vmware', 'rhel_subscription_pass')
  rhel_subscription_server = config.get('vmware', 'rhel_subscription_server')
  rhel_subscription_pool = config.get('vmware', 'rhel_subscription_pool')
  openshift_sdn = config.get('vmware', 'openshift_sdn')
  containerized = config.get('vmware', 'containerized')
  container_storage = config.get('vmware', 'container_storage')
  openshift_hosted_metrics_deploy = config.get('vmware', 'openshift_hosted_metrics_deploy')
  byo_lb = config.get('vmware', 'byo_lb')
  lb_host = config.get('vmware', 'lb_host')
  byo_nfs = config.get('vmware', 'byo_nfs')
  nfs_host = config.get('vmware', 'nfs_host')
  nfs_registry_mountpoint = config.get('vmware', 'nfs_registry_mountpoint')
  master_nodes = config.get('vmware', 'master_nodes')
  infra_nodes = config.get('vmware', 'infra_nodes')
  app_nodes = config.get('vmware', 'app_nodes')
  vm_ipaddr_start = config.get('vmware', 'vm_ipaddr_start')
  ocp_hostname_prefix = config.get('vmware', 'ocp_hostname_prefix')
  auth_type = config.get('vmware', 'auth_type')
  ldap_user = config.get('vmware', 'ldap_user')
  ldap_user_password = config.get('vmware', 'ldap_user_password')
  ldap_fqdn = config.get('vmware', 'ldap_fqdn')

  err_count = 0
  required_vars = {'public_hosted_zone':public_hosted_zone, 'vcenter_host':vcenter_host, 'vcenter_password':vcenter_password, 'vm_ipaddr_start':vm_ipaddr_start, 'ldap_fqdn':ldap_fqdn, 'ldap_user_password':ldap_user_password, 'vm_dns':vm_dns, 'vm_gw':vm_gw, 'vm_netmask':vm_netmask, 'vcenter_datacenter':vcenter_datacenter, 'vcenter_datastore':vcenter_datastore}
  for k, v in required_vars.items():
    if v == '':
        err_count += 1
        print "Missing %s " % k
  if err_count > 0:
    print "Please fill out the missing variables in %s " %  vmware_ini_path
    exit (1)
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  # fix nfs_host and lb_host vars with nfs_ocp_hostname_prefix
  if 'no' in byo_lb:
      if ocp_hostname_prefix is not None:
        lb_host=ocp_hostname_prefix+"haproxy-0"
      else:
        lb_host="haproxy-0"

  if 'no' in byo_nfs:
    if ocp_hostname_prefix is not None:
        nfs_host=ocp_hostname_prefix+"nfs-0"
    else:
        nfs_host="nfs-0"

  tags = []
  tags.append('setup')

  # Our initial support node is the wildcard_ip
  support_nodes=1
  if byo_nfs == "no":
      support_nodes=support_nodes+1
      tags.append('nfs')
  else:
    if nfs_host == '':
        nfs_host = click.prompt("Please enter the NFS Server fqdn for persistent registry:")
    if nfs_registry_mountpoint is '':
       nfs_registry_mountpoint = click.prompt("Please enter NFS share name for persistent registry:")

  tags.append('prod')

  if byo_lb == "no":
      tags.append('haproxy')
  else:
    if lb_host == '':
       lb_host = click.prompt("Please enter the load balancer hostname for installation:")
       lb_host = lb_host + '.' + public_hosted_zone

  if create_ocp_vars is True:
    click.echo('Configured OCP variables:')
    click.echo('\tauth_type: %s' % auth_type)
    click.echo('\tldap_fqdn: %s' % ldap_fqdn)
    click.echo('\tldap_user: %s' % ldap_user)
    click.echo('\tldap_user_password: %s' % ldap_user_password)
    click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
    click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
    click.echo('\tbyo_lb: %s' % byo_lb)
    click.echo('\tlb_host: %s' % lb_host)
    click.echo('\tUsing values from: %s' % vmware_ini_path)
    if not no_confirm:
      click.confirm('Continue using these values?', abort=True)
    if auth_type == 'ldap':
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

        install_file = "playbooks/ocp-install.yaml"

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
            elif line.startswith("    deployment_type:"):
                print "    deployment_type: " + deployment_type
            elif line.startswith("    openshift_hosted_registry_storage_host:"):
                print "    openshift_hosted_registry_storage_host: " + nfs_host + "." + public_hosted_zone
            elif line.startswith("    openshift_hosted_registry_storage_nfs_directory:"):
                print "    openshift_hosted_registry_storage_nfs_directory: " + nfs_registry_mountpoint
            elif line.startswith("    openshift_hosted_metrics_storage_host:"):
                print "    openshift_hosted_metrics_storage_host: " + nfs_host + "." + public_hosted_zone
            elif line.startswith("    openshift_hosted_metrics_storage_nfs_directory:"):
                print "    openshift_hosted_metrics_storage_nfs_directory: " + nfs_registry_mountpoint
            else:
                print line,

        # Provide values for update and add node playbooks       
        update_file = "playbooks/minor-update.yaml"
        for line in fileinput.input(update_file, inplace=True):
            if line.startswith("    wildcard_zone:"):
                print "    wildcard_zone: " + app_dns_prefix + "." + public_hosted_zone
            elif line.startswith("    load_balancer_hostname:"):
                print "    load_balancer_hostname: " + lb_host + "." + public_hosted_zone
            elif line.startswith("    deployment_type:"):
                print "    deployment_type: " + deployment_type
            else:
                print line,
            #End create_ocp_vars
        exit(0)

    if auth_type == 'none':
        playbooks = ["playbooks/ocp-install.yaml", "playbooks/minor-update.yaml"]
        for ocp_file in playbooks:
            for line in fileinput.input(ocp_file, inplace=True):
                if line.startswith('#openshift_master_identity_providers:'):
                    line = line.replace('#', '    ')
                    print line
                else:
                    print line,
    exit(0)


  if create_inventory is True:
    click.echo('Configured inventory values:')
    click.echo('\tmaster_nodes: %s' % master_nodes)
    click.echo('\tinfra_nodes: %s' % infra_nodes)
    click.echo('\tapp_nodes: %s' % app_nodes)
    click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
    click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
    click.echo('\tocp_hostname_prefix: %s' % ocp_hostname_prefix)
    click.echo('\tbyo_nfs: %s' % byo_nfs)
    if byo_nfs == "no":
       click.echo('\tnfs_host: %s' % nfs_host)
    click.echo('\tbyo_lb: %s' % byo_lb)
    if byo_lb == "no":
       click.echo('\tlb_host: %s' % lb_host)
    click.echo('\tvm_ipaddr_start: %s' % vm_ipaddr_start)
    click.echo('\tUsing values from: %s' % vmware_ini_path)
    click.echo("")
    if not no_confirm:
         click.confirm('Continue using these values?', abort=True)
    # Create the inventory file and exit
    if not cluster_id:
        #create a unique cluster_id first
        cluster_id = ''.join(random.choice('0123456789abcdefghijklmnopqrstuvwxyz') for i in range(20))
        config.set('vmware', 'cluster_id', cluster_id)
        for line in fileinput.input(vmware_ini_path, inplace=True):
            if line.startswith('cluster_id'):
                print "cluster_id=" + str(cluster_id)
            else:
                print line,

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
    bind_entry.append("*\tA\t" + wild_ip)
    bind_entry.append("$ORIGIN " + public_hosted_zone + ".")

    d = {}
    d['host_inventory'] = {}
    d['infrastructure_hosts'] = {}

    support_list = []
    if byo_nfs == "no":
        if ocp_hostname_prefix not in nfs_host:
            nfs_host=ocp_hostname_prefix+"nfs-0"
        d['host_inventory'][nfs_host] = {}
        d['host_inventory'][nfs_host]['guestname'] = nfs_host
        d['host_inventory'][nfs_host]['ip4addr'] = ip4addr[0]
        d['host_inventory'][nfs_host]['tag'] = str(cluster_id) + "-infra-nfs"
        d['infrastructure_hosts']["nfs_server"] = {}
        d['infrastructure_hosts']["nfs_server"]['guestname'] = nfs_host
        d['infrastructure_hosts']["nfs_server"]['tag'] =  str(cluster_id) + "-infra-nfs"
        support_list.append(nfs_host)
        bind_entry.append(nfs_host + "\tA\t" + ip4addr[0])
        del ip4addr[0]

    if byo_lb == "no":
        if ocp_hostname_prefix not in lb_host:
            lb_host=ocp_hostname_prefix+"haproxy-0"
        d['host_inventory'][lb_host] = {}
        d['host_inventory'][lb_host]['guestname'] = lb_host
        d['host_inventory'][lb_host]['ip4addr'] = wild_ip
        d['host_inventory'][lb_host]['tag'] =  str(cluster_id) + "-loadbalancer"
        d['infrastructure_hosts']["haproxy"] = {}
        d['infrastructure_hosts']["haproxy"]['guestname'] = lb_host
        d['infrastructure_hosts']["haproxy"]['tag'] = str(cluster_id) + "-loadbalancer"
        support_list.append(lb_host)
        bind_entry.append(lb_host + "\tA\t" + wild_ip)

    master_list = []
    d['production_hosts'] = {}
    for i in range(0, int(master_nodes)):
        if ocp_hostname_prefix is not None:
            master_name=ocp_hostname_prefix+"master-"+str(i)
        else:
            master_name="master-"+str(i)
        d['host_inventory'][master_name] = {}
        d['host_inventory'][master_name]['guestname'] = master_name
        d['host_inventory'][master_name]['ip4addr'] = ip4addr[0]
        d['host_inventory'][master_name]['tag'] = str(cluster_id) + "-master"
        d['production_hosts'][master_name] = {}
        d['production_hosts'][master_name]['guestname'] = master_name
        d['production_hosts'][master_name]['tag'] =  str(cluster_id) + "-master"
        master_list.append(master_name)
        bind_entry.append(master_name + "\tA\t" + ip4addr[0])
        del ip4addr[0]
    app_list = []
    for i in range(0, int(app_nodes)):
        if ocp_hostname_prefix is not None:
            app_name=ocp_hostname_prefix+"app-"+str(i)

        else:
            app_name="app-"+str(i)

        d['host_inventory'][app_name] = {}
        d['host_inventory'][app_name]['guestname'] = app_name
        d['host_inventory'][app_name]['ip4addr'] = ip4addr[0]
        d['host_inventory'][app_name]['tag'] =  str(cluster_id) + "-app"
        d['production_hosts'][app_name] = {}
        d['production_hosts'][app_name]['guestname'] = app_name
        d['production_hosts'][app_name]['tag'] = str(cluster_id) + "-app"
        app_list.append(app_name)
        bind_entry.append(app_name + "\tA\t" + ip4addr[0])
        del ip4addr[0]
    infra_list = []
    for i in range(0, int(infra_nodes)):
        if ocp_hostname_prefix is not None:
            infra_name=ocp_hostname_prefix+"infra-"+str(i)
        else:
            infra_name="infra-"+str(i)
        d['host_inventory'][infra_name] = {}
        d['host_inventory'][infra_name]['guestname'] = infra_name
        d['host_inventory'][infra_name]['ip4addr'] = ip4addr[0]
        d['host_inventory'][infra_name]['tag'] =  str(cluster_id) + "-infra"
        d['production_hosts'][infra_name] = {}
        d['production_hosts'][infra_name]['guestname'] = infra_name
        d['production_hosts'][infra_name]['tag'] = str(cluster_id) + "-infra"
        infra_list.append(infra_name)
        bind_entry.append(infra_name + "        A       " + ip4addr[0])
        del ip4addr[0]
    print "# Here is what should go into your DNS records"
    print("\n".join(bind_entry))
    print "# Please note, if you have chosen to bring your own loadbalancer and NFS Server you will need to ensure that these records are added to DNS and properly resolve. "

    with open('infrastructure.json', 'w') as outfile:
        json.dump(d, outfile)
    exit(0)
  # End create inventory

  # Display information to the user about their choices
  click.echo('Configured values:')
  for each_section in config.sections():
            for (key, val) in config.items(each_section):
                print '\t %s:  %s' % ( key,  val )
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

  tags.append('ocp-install')
  tags.append('ocp-configure')

  # remove any cached facts to prevent stale data during a re-run
  command='rm -rf .ansible/cached_facts'
  os.system(command)

  tags = ",".join(tags)
  if clean is True:
      tags = 'clean'
  if tag:
      tags = tag

  # grab the default priv key from the user"
  command='cp -f ~/.ssh/id_rsa ssh_key/ocp-installer'
  os.system(command)
  # make sure the ssh keys have the proper permissions
  command='chmod 600 ssh_key/ocp-installer'
  os.system(command)


  for tag in tags.split(','):
      playbook = "playbooks/" + tag + ".yaml"
      tags = 'all'

      devnull='> /dev/null'

      if verbose > 0:
        devnull=''

      command='ansible-playbook  --extra-vars "@./infrastructure.json" --tags %s -e \'vcenter_host=%s \
      vcenter_username=%s \
      vcenter_password=%s \
      vcenter_template_name=%s \
      vcenter_folder=%s \
      vcenter_cluster=%s \
      vcenter_datacenter=%s \
      vcenter_datastore=%s \
      vcenter_resource_pool=%s \
      public_hosted_zone=%s \
      app_dns_prefix=%s \
      vm_dns=%s \
      vm_gw=%s \
      vm_netmask=%s \
      vm_network=%s \
      wildcard_zone=%s \
      console_port=%s \
      cluster_id=%s \
      deployment_type=%s \
      openshift_vers=%s \
      rhsm_user=%s \
      rhsm_password=%s \
      rhel_subscription_server=%s \
      rhsm_pool="%s" \
      openshift_sdn=%s \
      containerized=%s \
      container_storage=%s \
      openshift_hosted_metrics_deploy=%s \
      lb_host=%s \
      nfs_host=%s \
      nfs_registry_mountpoint=%s \' %s' % ( tags,
                          vcenter_host,
                          vcenter_username,
                          vcenter_password,
                          vcenter_template_name,
                          vcenter_folder,
                          vcenter_cluster,
                          vcenter_datacenter,
                          vcenter_datastore,
                          vcenter_resource_pool,
                          public_hosted_zone,
                          app_dns_prefix,
                          vm_dns,
                          vm_gw,
                          vm_netmask,
                          vm_network,
                          wildcard_zone,
                          console_port,
                          cluster_id,
                          deployment_type,
                          openshift_vers,
                          rhel_subscription_user,
                          rhel_subscription_pass,
                          rhel_subscription_server,
                          rhel_subscription_pool,
                          openshift_sdn,
                          containerized,
                          container_storage,
                          openshift_hosted_metrics_deploy,
                          lb_host,
                          nfs_host,
                          nfs_registry_mountpoint,
                          playbook)
      if verbose > 0:
        command += " -" + "".join(['v']*verbose)
        click.echo('We are running: %s' % command)

      status = os.system(command)
      if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
        return os.WEXITSTATUS(status)

if __name__ == '__main__':

  launch_refarch_env(auto_envvar_prefix='OCP_REFArch')

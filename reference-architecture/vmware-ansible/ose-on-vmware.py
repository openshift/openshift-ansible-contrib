#!/usr/bin/env python
# vim: sw=2 ts=2

import click, os, sys, fileinput

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
@click.option('--vcenter_datacenter', default='Boston', help='vCenter datacenter to utilize',
              show_default=True)
@click.option('--vcenter_cluster', default='devel', help='vCenter cluster to utilize',
              show_default=True)
@click.option('--vcenter_datastore', default='ose3-vmware', help='Storage in vCenter to store VMs',
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
@click.option('--rhsm_activation_key', default='act-dev-infra-openshift3', help='Red Hat Subscription Management User')
@click.option('--rhsm_org_id', default='Default_Organization', help='Red Hat Subscription Management Password')

### Miscellaneous options
@click.option('--byo_lb', default='no', help='skip haproxy install when one exists within the environment',
              show_default=True)
@click.option('--lb_fqdn', default='haproxy-0.vcenter.e2e.bos.redhat.com', help='Used for OpenShift cluster hostname and public hostname',
              show_default=True)

@click.option('--byo_nfs', default='no', help='skip nfs install when one exists within the environment',
              show_default=True)
@click.option('--nfs_registry_host', default='nfs-0.vcenter.e2e.bos.redhat.com', help='NFS server for persistent registry',
              show_default=True)
@click.option('--nfs_registry_mountpoint', default='/registry', help='NFS share for persistent registry',
              show_default=True)

@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)
@click.option('-t', '--tag', help='Ansible playbook tag for specific parts of playbook')
@click.option('-l', '--local', is_flag=True,help='Local installation of ansible instead of our container')
	
def launch_refarch_env(console_port=8443,
                    deployment_type=None,
                    vcenter_host=None,
                    vcenter_username=None,
                    vcenter_password=None,
                    vcenter_template_name=None,
		    vcenter_folder=None,
                    vcenter_datacenter=None,
                    vcenter_cluster=None,
                    vcenter_datastore=None,
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
                    byo_lb=None,
                    lb_fqdn=None,
                    byo_nfs=None,
                    nfs_registry_host=None,
                    nfs_registry_mountpoint=None,
                    no_confirm=False,
		    tag=None,
                    verbose=0,
		    local=None):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  # If the user already provided values, don't bother asking again
  if rhsm_user is None and rhsm_activation_key is None:
    rhsm_user = click.prompt("RHSM username?")
  if rhsm_password is None and rhsm_user:
    rhsm_password = click.prompt("RHSM password?", hide_input=True, confirmation_prompt=True)

  if rhsm_activation_key is None:
    rhsm_activation_key = click.prompt("Satellite Server Activation Key?")
  if rhsm_org_id is None:
    rhsm_org_id = click.prompt("Organization ID for Satellite Server?", confirmation_prompt=True)

  # Calculate various DNS values
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  tags = []

  if byo_nfs == "no":
      nfs_registry_host = 'nfs-0.vcenter.e2e.bos.redhat.com'
      nfs_registry_mountpoint ='/registry'
      tags.append('nfs')
  else:
      nfs_registry_host = click.prompt("Please enter the NFS Server fqdn for persistent registry:")
      nfs_registry_mountpoint = click.prompt("Please enter NFS share name for persistent registry:")

  tags.append('prod')

  if byo_lb == "no":
      lb_fqdn = 'haproxy-0.vcenter.e2e.bos.redhat.com'
      tags.append('haproxy')
  else:
      lb_fqdn = click.prompt("Please enter the load balancer fqdn for installation:")



  # Display information to the user about their choices
  click.echo('Configured values:')
  click.echo('\tconsole port: %s' % console_port)
  click.echo('\tdeployment_type: %s' % deployment_type)
  click.echo('\tvcenter_host: %s' % vcenter_host)
  click.echo('\tvcenter_username: %s' % vcenter_username)
  click.echo('\tvcenter_password: *******')
  click.echo('\tvcenter_template_name: %s' % vcenter_template_name)
  click.echo('\tvcenter_folder: %s' % vcenter_folder)
  click.echo('\tvcenter_datacenter: %s' % vcenter_datacenter)
  click.echo('\tvcenter_cluster: %s' % vcenter_cluster)
  click.echo('\tvcenter_datastore: %s' % vcenter_datastore)
  click.echo('\tvcenter_resource_pool: %s' % vcenter_resource_pool)

  click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
  click.echo('\tvm_dns: %s' % vm_dns)
  click.echo('\tvm_gw: %s' % vm_gw)
  click.echo('\tvm_interface_name: %s' % vm_interface_name)

  if rhsm_user is not None:
	  auth_method = 'user'
	  click.echo('\trhsm_user: %s' % rhsm_user)
	  click.echo('\trhsm_password: *******')

  
  if rhsm_activation_key is not None: 
	  auth_method = 'key'
	  click.echo('\trhsm_activation_key: %s' % rhsm_activation_key)
	  click.echo('\trhsm_org_id: rhsm_org_id')

  click.echo('\tRHN Authentication method: %s' % auth_method)
  click.echo('\tbyo_lb: %s' % byo_lb)
  click.echo('\tlb_fqdn: %s' % lb_fqdn)
  click.echo('\tbyo_nfs: %s' % byo_nfs)
  click.echo('\tnfs_registry_host: %s' % nfs_registry_host)
  click.echo('\tnfs_registry_mountpoint: %s' % nfs_registry_mountpoint)

  click.echo('\tapps_dns: %s' % wildcard_zone)

  click.echo("")

  if not no_confirm:
    click.confirm('Continue using these values?', abort=True)

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

  playbooks = ['playbooks/infrastructure.yaml']
  tags.append('ose-install')
  tags.append('ose-configure')

  for playbook in playbooks:
    # hide cache output unless in verbose mode
    devnull='> /dev/null'

    if verbose > 0:
      devnull=''

    # make sure the ssh keys have the proper permissions
    # interferring with re-running
    command='chmod 600 ssh_key/ose3-installer'
    os.system(command)

    # remove any cached facts to prevent stale data during a re-run
    command='rm -rf .ansible/cached_facts'
    os.system(command)
    tags = ",".join(tags)
    if tag:
	tags = tag
    # We'll be doing a docker run instead
    #command='docker run -t --rm --dns=10.19.114.2 --volume `pwd`:/opt/ansible:Z --volume `pwd`/openshift-ansible:/usr/share/ansible/openshift-ansible ansible:2.1.0.0-1-latest --tags %s -e \'vcenter_host=%s \
    # Should we be using a container or a local install  be doing a docker run instead
    if local:
	command='ansible-playbook'
    else:
	command='docker run -t --rm --volume `pwd`:/opt/ansible:rw --net=host ansible:2.2-latest'

    command=command + ' --tags %s -e \'vcenter_host=%s \
    vcenter_username=%s \
    vcenter_password=%s \
    vcenter_template_name=%s \
    vcenter_folder=%s \
    vcenter_datacenter=%s \
    vcenter_cluster=%s \
    vcenter_datastore=%s \
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
    lb_fqdn=%s \
    auth_method=%s \
    nfs_registry_host=%s \
    nfs_registry_mountpoint=%s \' %s' % ( tags,
		    vcenter_host,
                    vcenter_username,
                    vcenter_password,
                    vcenter_template_name,
                    vcenter_folder,
                    vcenter_datacenter,
                    vcenter_cluster,
                    vcenter_datastore,
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
                    lb_fqdn,
		    auth_method,
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

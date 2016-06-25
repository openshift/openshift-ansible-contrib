#!/usr/bin/env python
# vim: sw=2 ts=2

import click
import os
import sys

@click.command()

### Cluster options
@click.option('--console-port', default='8443', type=click.IntRange(1,65535), help='OpenShift web console port',
              show_default=True)
@click.option('--deployment-type', default='openshift-enterprise', help='OpenShift deployment type',
              show_default=True)

### AWS/EC2 options
@click.option('--region', default='us-east-1', help='ec2 region',
              show_default=True)
@click.option('--ami', default='ami-10251c7a', help='ec2 ami',
              show_default=True)
@click.option('--master-instance-type', default='t2.medium', help='ec2 instance type',
              show_default=True)
@click.option('--node-instance-type', default='t2.medium', help='ec2 instance type',
              show_default=True)
@click.option('--keypair', help='ec2 keypair name',
              show_default=True)
@click.option('--create-key', default='no', help='Create SSH keypair',
              show_default=True)
@click.option('--ssh-key', default='no', help='Path to SSH public key',
              show_default=True)
@click.option('--create-vpc', default='yes', help='Create VPC',
              show_default=True)
@click.option('--vpc-id', help='Specify an already existing VPC',
              show_default=True)
@click.option('--subnet-id1', help='Specify a subnet within the existing VPC',
              show_default=True)
@click.option('--subnet-id2', help='Specify a subnet within the existing VPC(can be a duplicate of subnet_id1)',
              show_default=True)
@click.option('--subnet-id3', help='Specify a subnet within the existing VPC(can be a duplicate of subnet_id1)',
              show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')
@click.option('--app-dns-prefix', default='apps', help='application dns prefix',
              show_default=True)

### Subscription and Software options
@click.option('--rhn-user', help='Red Hat Subscription Management User')
@click.option('--rhn-password', help='Red Hat Subscription Management Password',
                hide_input=True,)

### Miscellaneous options
@click.option('--byo-bastion', default='no', help='skip bastion install when one exists within the cloud provider',
              show_default=True)
@click.option('--registry-volume-size', default='50', help='Size of Registry Volume',
              show_default=True)
@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)

def launch_demo_env(region=None,
                    ami=None,
                    no_confirm=False,
                    master_instance_type=None,
                    node_instance_type=None,
                    keypair=None,
                    create_key=None,
                    ssh_key=None,
                    create_vpc=None,
                    vpc_id=None,
                    subnet_id1=None,
                    subnet_id2=None,
                    subnet_id3=None,
                    byo_bastion=None,
                    public_hosted_zone=None,
                    app_dns_prefix=None,
                    deployment_type=None,
                    console_port=8443,
                    rhn_user=None,
                    rhn_password=None,
                    registry_volume_size=None,
                    verbose=0):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  # Create ssh key pair in AWS if none is specified
  if create_key in 'yes' and ssh_key in 'no':
    ssh_key = click.prompt('Specify path for ssh public key')
    keypair = click.prompt('Specify a name for the keypair')

 # If no keypair is not specified fail:
  if keypair is None and create_key in 'no':
    click.echo('A SSH keypair must be specified or created')
    sys.exit(1)

 # Name the keypair if a path is defined
  if keypair is None and create_key in 'yes':
    keypair = click.prompt('Specify a name for the keypair')

 # If no subnets are defined prompt:
  if create_vpc in 'no' and vpc_id is None:
    vpc_id = click.prompt('Specify the VPC ID')

 # If no subnets are defined prompt:
  if create_vpc in 'no' and subnet_id1 is None:
    subnet_id1 = click.prompt('Specify the first subnet within the existing VPC')
    subnet_id2 = click.prompt('Specify the second subnet within the existing VPC(can be a duplicate of subnet_id1')
    subnet_id3 = click.prompt('Specify the third  subnet within the existing VPC(can be a duplicate of subnet_id1')

  # If the user already provided values, don't bother asking again
  if rhn_user is None:
    rhn_user = click.prompt("RHSM username?")
  if rhn_password is None:
    rhn_password = click.prompt("RHSM password?", hide_input=True, confirmation_prompt=True)

  # Calculate various DNS values
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  # Display information to the user about their choices
  click.echo('Configured values:')
  click.echo('\tami: %s' % ami)
  click.echo('\tregion: %s' % region)
  click.echo('\tmaster_instance_type: %s' % master_instance_type)
  click.echo('\tnode_instance_type: %s' % node_instance_type)
  click.echo('\tkeypair: %s' % keypair)
  click.echo('\tcreate_key: %s' % create_key)
  click.echo('\tssh_key: %s' % ssh_key)
  click.echo('\tcreate_vpc: %s' % create_vpc)
  click.echo('\tvpc_id: %s' % vpc_id)
  click.echo('\tsubnet_id1: %s' % subnet_id1)
  click.echo('\tsubnet_id2: %s' % subnet_id2)
  click.echo('\tsubnet_id3: %s' % subnet_id3)
  click.echo('\tbyo_bastion: %s' % byo_bastion)
  click.echo('\tconsole port: %s' % console_port)
  click.echo('\tdeployment_type: %s' % deployment_type)
  click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
  click.echo('\tapps_dns: %s' % wildcard_zone)
  click.echo('\trhn_user: %s' % rhn_user)
  click.echo('\trhn_password: *******')
  click.echo('\tregistry_volume_size: %s' % registry_volume_size)
  click.echo("")

  if not no_confirm:
    click.confirm('Continue using these values?', abort=True)

  playbooks = ['playbooks/infrastructure.yaml', 'playbooks/openshift-install.yaml']

  for playbook in playbooks:

    # hide cache output unless in verbose mode
    devnull='> /dev/null'

    if verbose > 0:
      devnull=''

    # refresh the inventory cache to prevent stale hosts from
    # interferring with re-running
    command='inventory/aws/hosts/ec2.py --refresh-cache %s' % (devnull)
    os.system(command)

    # remove any cached facts to prevent stale data during a re-run
    command='rm -rf .ansible/cached_facts'
    os.system(command)

    command='ansible-playbook -i inventory/aws/hosts -e \'region=%s \
    ami=%s \
    keypair=%s \
    create_key=%s \
    ssh_key=%s \
    create_vpc=%s \
    vpc_id=%s \
    subnet_id1=%s \
    subnet_id2=%s \
    subnet_id3=%s \
    byo_bastion=%s \
    master_instance_type=%s \
    node_instance_type=%s \
    public_hosted_zone=%s \
    wildcard_zone=%s \
    console_port=%s \
    deployment_type=%s \
    rhn_user=%s \
    rhn_password=%s \
    registry_volume_size=%s\' %s' % (region,
                    ami,
                    keypair,
                    create_key,
                    ssh_key,
                    create_vpc,
                    vpc_id,
                    subnet_id1,
                    subnet_id2,
                    subnet_id3,
                    byo_bastion,
                    master_instance_type,
                    node_instance_type,
                    public_hosted_zone,
                    wildcard_zone,
                    console_port,
                    deployment_type,
                    rhn_user,
                    rhn_password,
                    registry_volume_size,
                    playbook)

    if verbose > 0:
      command += " -" + "".join(['v']*verbose)
      click.echo('We are running: %s' % command)

    status = os.system(command)
    if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
      return os.WEXITSTATUS(status)

if __name__ == '__main__':
  # check for AWS access info
  if os.getenv('AWS_ACCESS_KEY_ID') is None or os.getenv('AWS_SECRET_ACCESS_KEY') is None:
    print 'AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY **MUST** be exported as environment variables.'
    sys.exit(1)

  launch_demo_env(auto_envvar_prefix='OSE_DEMO')

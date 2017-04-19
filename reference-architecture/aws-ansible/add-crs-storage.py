#!/usr/bin/env python
# vim: sw=2 ts=2

import click
import os
import sys

@click.command()

### AWS/EC2 options
@click.option('--gluster-stack', help='Specify a gluster stack name. Making the name unique will allow for multiple deployments',
              show_default=True)
@click.option('--region', default='us-east-1', help='ec2 region',
              show_default=True)
@click.option('--ami', default='ami-10251c7a', help='ec2 ami',
              show_default=True)
@click.option('--node-instance-type', default='m4.2xlarge', help='ec2 instance type',
              show_default=True)
@click.option('--use-cloudformation-facts', is_flag=True, help='Use cloudformation to populate facts. Requires Deployment >= OCP 3.5',
              show_default=True)
@click.option('--keypair', help='ec2 keypair name',
              show_default=True)
@click.option('--private-subnet-id1', help='Specify a Private subnet within the existing VPC',
              show_default=True)
@click.option('--private-subnet-id2', help='Specify a Private subnet within the existing VPC',
              show_default=True)
@click.option('--private-subnet-id3', help='Specify a Private subnet within the existing VPC',
              show_default=True)
@click.option('--gluster-volume-size', default='500', help='Gluster volume size in GB',
              show_default=True)
@click.option('--gluster-volume-type', default='st1', help='Gluster volume type',
              show_default=True)
@click.option('--bastion-sg', help='Specify the Bastion Security Group',
              show_default=True)
@click.option('--node-sg', help='Specify the Node Security Group',
              show_default=True)
@click.option('--vpc', help='Specify the existing VPC',
              show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')

### Subscription and Software options
@click.option('--rhsm-user', help='Red Hat Subscription Management User')
@click.option('--rhsm-password', help='Red Hat Subscription Management Password',
                hide_input=True,)
@click.option('--rhsm-pool', help='Red Hat Subscription Management Pool ID or Subscription Name for OpenShift')

### Miscellaneous options
@click.option('--existing-stack', help='Specify the name of the existing CloudFormation stack')
@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)

def launch_refarch_env(region=None,
                    ami=None,
                    no_confirm=False,
                    node_instance_type=None,
                    gluster_stack=None,
                    keypair=None,
                    public_hosted_zone=None,
                    rhsm_user=None,
                    rhsm_password=None,
                    rhsm_pool=None,
                    node_type=None,
                    private_subnet_id1=None,
                    private_subnet_id2=None,
                    private_subnet_id3=None,
                    gluster_volume_type=None,
                    gluster_volume_size=None,
                    bastion_sg=None,
                    node_sg=None,
                    vpc=None,
                    existing_stack=None,
                    use_cloudformation_facts=False,
                    verbose=0):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  if existing_stack is None:
    existing_stack = click.prompt('Specify the name of the existing CloudFormation stack')

  if gluster_stack is None:
    gluster_stack = click.prompt('Specify a unique name for the CRS CloudFormation stack')

 # If no keypair is specified fail:
  if keypair is None:
    keypair = click.prompt('A SSH keypair must be specified or created')

  if use_cloudformation_facts and bastion_sg is None:
    bastion_sg = "Computed by Cloudformations"
  elif bastion_sg is None:
    bastion_sg = click.prompt("Specify the Security Group of the Bastion?")

  if use_cloudformation_facts and node_sg is None:
    node_sg = "Computed by Cloudformations"
  elif node_sg is None:
    node_sg = click.prompt("Specify the Security Group of the Node?")

  if use_cloudformation_facts and vpc is None:
    vpc = "Computed by Cloudformations"
  elif vpc is None:
    vpc = click.prompt("Specify the existing VPC?")

  if use_cloudformation_facts and private_subnet_id1 is None:
    private_subnet_id1 = "Computed by Cloudformations"
  elif private_subnet_id1 is None:
    private_subnet_id1 = click.prompt("Specify the first private subnet for the nodes?")

  if use_cloudformation_facts and private_subnet_id2 is None:
    private_subnet_id2 = "Computed by Cloudformations"
  elif private_subnet_id2 is None:
    private_subnet_id2 = click.prompt("Specify the second private subnet for the nodes?")

  if use_cloudformation_facts and private_subnet_id3 is None:
    private_subnet_id3 = "Computed by Cloudformations"
  elif private_subnet_id3 is None:
    private_subnet_id3 = click.prompt("Specify the third private subnet for the nodes?")

  # If the user already provided values, don't bother asking again
  if rhsm_user is None:
    rhsm_user = click.prompt("RHSM username?")
  if rhsm_password is None:
    rhsm_password = click.prompt("RHSM password?", hide_input=True)
  if rhsm_pool is None:
    rhsm_pool = click.prompt("RHSM Pool ID or Subscription Name?")

  # Hidden facts for infrastructure.yaml
  create_key = "no"
  create_vpc = "no"
  add_node = "no"
  deploy_crs = "yes"

  # Display information to the user about their choices
  if use_cloudformation_facts:
      click.echo('Configured values:')
      click.echo('\tami: %s' % ami)
      click.echo('\tregion: %s' % region)
      click.echo('\tgluster_stack: %s' % gluster_stack)
      click.echo('\tgluster_volume_type: %s' % gluster_volume_type)
      click.echo('\tgluster_volume_size: %s' % gluster_volume_size)
      click.echo('\tnode_instance_type: %s' % node_instance_type)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
      click.echo('\trhsm_user: %s' % rhsm_user)
      click.echo('\trhsm_password: *******')
      click.echo('\trhsm_pool: %s' % rhsm_pool)
      click.echo('\texisting_stack: %s' % existing_stack)
      click.echo('\tSubnets and Security Groups will be gather from the CloudFormation')
      click.echo("")
  else:
      click.echo('Configured values:')
      click.echo('\tami: %s' % ami)
      click.echo('\tregion: %s' % region)
      click.echo('\tgluster_stack: %s' % gluster_stack)
      click.echo('\tprivate_subnet_id1: %s' % private_subnet_id1)
      click.echo('\tprivate_subnet_id2: %s' % private_subnet_id2)
      click.echo('\tprivate_subnet_id3: %s' % private_subnet_id3)
      click.echo('\tgluster_volume_type: %s' % gluster_volume_type)
      click.echo('\tgluster_volume_size: %s' % gluster_volume_size)
      click.echo('\tnode_instance_type: %s' % node_instance_type)
      click.echo('\tbastion_sg: %s' % bastion_sg)
      click.echo('\tnode_sg: %s' % node_sg)
      click.echo('\tvpc: %s' % vpc)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
      click.echo('\trhsm_user: %s' % rhsm_user)
      click.echo('\trhsm_password: *******')
      click.echo('\trhsm_pool: %s' % rhsm_pool)
      click.echo('\texisting_stack: %s' % existing_stack)
      click.echo("")

  if not no_confirm:
    click.confirm('Continue using these values?', abort=True)

  playbooks = ['playbooks/infrastructure.yaml', 'playbooks/add-crs.yaml']

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

    if use_cloudformation_facts:
        command='ansible-playbook -i inventory/aws/hosts -e \'region=%s \
        ami=%s \
        keypair=%s \
        gluster_stack=%s \
        add_node=no \
        deploy_crs=yes \
    	node_instance_type=%s \
    	public_hosted_zone=%s \
    	rhsm_user=%s \
    	rhsm_password=%s \
    	rhsm_pool="%s" \
    	key_path=/dev/null \
    	create_key=%s \
    	create_vpc=%s \
        gluster_volume_type=%s \
        gluster_volume_size=%s \
    	stack_name=%s \' %s' % (region,
                    	ami,
                    	keypair,
                        gluster_stack,
                    	node_instance_type,
                    	public_hosted_zone,
                    	rhsm_user,
                    	rhsm_password,
                    	rhsm_pool,
                    	create_key,
                    	create_vpc,
                        gluster_volume_type,
                        gluster_volume_size,
                    	existing_stack,
                    	playbook)
    else:
        command='ansible-playbook -i inventory/aws/hosts -e \'region=%s \
        ami=%s \
        keypair=%s \
        gluster_stack=%s \
        add_node=no \
        deploy_crs=yes \
    	node_instance_type=%s \
    	private_subnet_id1=%s \
    	private_subnet_id2=%s \
    	private_subnet_id3=%s \
    	public_hosted_zone=%s \
    	rhsm_user=%s \
    	rhsm_password=%s \
    	rhsm_pool="%s" \
    	key_path=/dev/null \
    	create_key=%s \
    	create_vpc=%s \
        gluster_volume_type=%s \
        gluster_volume_size=%s \
        bastion_sg=%s \
        node_sg=%s \
        vpc=%s \
    	stack_name=%s \' %s' % (region,
                    	ami,
                    	keypair,
                        gluster_stack,
                    	node_instance_type,
                    	private_subnet_id1,
                    	private_subnet_id2,
                    	private_subnet_id3,
                    	public_hosted_zone,
                    	rhsm_user,
                    	rhsm_password,
                    	rhsm_pool,
                    	create_key,
                    	create_vpc,
                        gluster_volume_type,
                        gluster_volume_size,
                        bastion_sg,
                        node_sg,
                        vpc,
                    	existing_stack,
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

  launch_refarch_env(auto_envvar_prefix='OSE_REFArch')

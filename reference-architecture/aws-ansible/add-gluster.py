#!/usr/bin/env python
# vim: sw=2 ts=2

import click
import os
import sys

@click.command()

### Cluster options
@click.option('--console-port', default='443', type=click.IntRange(1,65535), help='OpenShift web console port',
              show_default=True)
@click.option('--deployment-type', default='openshift-enterprise', help='OpenShift deployment type',
              show_default=True)

### AWS/EC2 options
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
@click.option('--gluster-volume-type', default='gp2', help='Gluster volume type',
              show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')

### Subscription and Software options
@click.option('--rhsm-user', help='Red Hat Subscription Management User')
@click.option('--rhsm-password', help='Red Hat Subscription Management Password',
                hide_input=True,)
@click.option('--rhsm-openshift-pool', help='Red Hat Subscription Management Pool ID or Subscription Name for OpenShift')
@click.option('--rhsm-gluster-pool', help='Red Hat Subscription Management Pool ID or Subscription Name for Gluster Storage')

### Miscellaneous options
@click.option('--containerized', default='False', help='Containerized installation of OpenShift',
              show_default=True)
@click.option('--iam-role', help='Specify the name of the existing IAM Instance profile',
              show_default=True)
@click.option('--node-sg', help='Specify the already existing node security group id',
              show_default=True)
@click.option('--existing-stack', help='Specify the name of the existing CloudFormation stack')
@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)

def launch_refarch_env(region=None,
                    ami=None,
                    no_confirm=False,
                    node_instance_type=None,
                    keypair=None,
                    public_hosted_zone=None,
                    deployment_type=None,
                    console_port=443,
                    rhsm_user=None,
                    rhsm_password=None,
                    rhsm_openshift_pool=None,
                    rhsm_gluster_pool=None,
                    containerized=None,
                    node_type=None,
                    private_subnet_id1=None,
                    private_subnet_id2=None,
                    private_subnet_id3=None,
                    gluster_volume_type=None,
                    gluster_volume_size=None,
                    node_sg=None,
                    iam_role=None,
                    existing_stack=None,
                    use_cloudformation_facts=False,
                    verbose=0):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  if existing_stack is None:
    existing_stack = click.prompt('Specify the name of the existing CloudFormation stack')

 # If no keypair is specified fail:
  if keypair is None:
    keypair = click.prompt('A SSH keypair must be specified or created')

  # If the user already provided values, don't bother asking again
  if deployment_type in ['openshift-enterprise'] and rhsm_user is None:
    rhsm_user = click.prompt("RHSM username?")
  if deployment_type in ['openshift-enterprise'] and rhsm_password is None:
    rhsm_password = click.prompt("RHSM password?", hide_input=True)
  if deployment_type in ['openshift-enterprise'] and rhsm_openshift_pool is None:
    rhsm_openshift_pool = click.prompt("RHSM Pool ID or Subscription Name for OpenShift?")
  if deployment_type in ['openshift-enterprise'] and rhsm_gluster_pool is None:
    rhsm_gluster_pool = click.prompt("RHSM Pool ID or Subscription Name for Gluster?")

  # Hidden facts for infrastructure.yaml
  create_key = "no"
  create_vpc = "no"
  add_node = "yes"
  node_type = "gluster"

  # Display information to the user about their choices
  click.echo('Configured values:')
  click.echo('\tami: %s' % ami)
  click.echo('\tregion: %s' % region)
  click.echo('\tnode_instance_type: %s' % node_instance_type)
  click.echo('\tprivate_subnet_id1: %s' % private_subnet_id1)
  click.echo('\tprivate_subnet_id2: %s' % private_subnet_id2)
  click.echo('\tprivate_subnet_id3: %s' % private_subnet_id3)
  click.echo('\tgluster_volume_type: %s' % gluster_volume_type)
  click.echo('\tgluster_volume_size: %s' % gluster_volume_size)
  click.echo('\tkeypair: %s' % keypair)
  click.echo('\tnode_sg: %s' % node_sg)
  click.echo('\tdeployment_type: %s' % deployment_type)
  click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  click.echo('\tconsole port: %s' % console_port)
  click.echo('\trhsm_user: %s' % rhsm_user)
  click.echo('\trhsm_password: *******')
  click.echo('\trhsm_openshift_pool: %s' % rhsm_openshift_pool)
  click.echo('\trhsm_glusterpool: %s' % rhsm_gluster_pool)
  click.echo('\tcontainerized: %s' % containerized)
  click.echo('\tiam_role: %s' % iam_role)
  click.echo('\texisting_stack: %s' % existing_stack)
  click.echo("")

  if not no_confirm:
    click.confirm('Continue using these values?', abort=True)

  playbooks = ['playbooks/infrastructure.yaml', 'playbooks/add-node.yaml']

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
        add_node=yes \
    	node_instance_type=%s \
    	public_hosted_zone=%s \
    	deployment_type=%s \
        console_port=%s \
    	rhsm_user=%s \
    	rhsm_password=%s \
    	rhsm_openshift_pool=%s \
    	rhsm_gluster_pool=%s \
    	containerized=%s \
    	node_type=gluster \
    	key_path=/dev/null \
    	create_key=%s \
    	create_vpc=%s \
        gluster_volume_type=%s \
        gluster_volume_size=%s \
    	stack_name=%s \' %s' % (region,
                    	ami,
                    	keypair,
                    	node_instance_type,
                    	public_hosted_zone,
                    	deployment_type,
                        console_port,
                    	rhsm_user,
                    	rhsm_password,
                    	rhsm_openshift_pool,
                    	rhsm_gluster_pool,
                    	containerized,
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
        add_node=yes \
   	node_sg=%s \
    	node_instance_type=%s \
    	private_subnet_id1=%s \
    	private_subnet_id2=%s \
    	private_subnet_id3=%s \
    	public_hosted_zone=%s \
    	deployment_type=%s \
        console_port=%s \
    	rhsm_user=%s \
    	rhsm_password=%s \
    	rhsm_pool=%s \
    	rhsm_gluster_pool=%s \
    	containerized=%s \
    	node_type=gluster \
    	iam_role=%s \
    	key_path=/dev/null \
    	create_key=%s \
    	create_vpc=%s \
        gluster_volume_type=%s \
        gluster_volume_size=%s \
    	stack_name=%s \' %s' % (region,
                    	ami,
                    	keypair,
                    	node_sg,
                    	node_instance_type,
                    	private_subnet_id1,
                    	private_subnet_id2,
                    	private_subnet_id3,
                    	public_hosted_zone,
                    	deployment_type,
                        console_port,
                    	rhsm_user,
                    	rhsm_password,
                    	rhsm_openshift_pool,
                    	rhsm_gluster_pool,
                    	containerized,
                    	iam_role,
                    	create_key,
                    	create_vpc,
                        gluster_volume_type,
                        gluster_volume_size,
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

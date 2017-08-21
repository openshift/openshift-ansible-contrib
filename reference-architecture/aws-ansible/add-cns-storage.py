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
@click.option('--openshift-sdn', default='redhat/openshift-ovs-multitenant', type=click.Choice(['redhat/openshift-ovs-subnet', 'redhat/openshift-ovs-multitenant']),  help='OpenShift SDN',
              show_default=True)

### AWS/EC2 options
@click.option('--glusterfs-stack-name', help='Specify a gluster stack name. Making the name unique will allow for multiple deployments',
              show_default=True)
@click.option('--region', default='us-east-1', help='ec2 region',
              show_default=True)
@click.option('--ami', default='ami-fbc89880', help='ec2 ami',
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
@click.option('--glusterfs-volume-size', default='500', help='Gluster volume size in GB',
              show_default=True)
@click.option('--glusterfs-volume-type', default='st1', help='Gluster volume type',
              show_default=True)
@click.option('--iops', help='Specfify the IOPS for a volume (used only with IO1)',
              show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')

### Subscription and Software options
@click.option('--rhsm-user', help='Red Hat Subscription Management User')
@click.option('--rhsm-password', help='Red Hat Subscription Management Password',
                hide_input=True,)
@click.option('--rhsm-pool', help='Red Hat Subscription Management Pool Name')

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
                    glusterfs_stack_name=None,
                    keypair=None,
                    public_hosted_zone=None,
                    deployment_type=None,
                    console_port=443,
                    rhsm_user=None,
                    rhsm_password=None,
                    rhsm_pool=None,
                    containerized=None,
                    node_type=None,
                    private_subnet_id1=None,
                    private_subnet_id2=None,
                    private_subnet_id3=None,
                    glusterfs_volume_type=None,
                    glusterfs_volume_size=None,
                    openshift_sdn=None,
                    iops=None,
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

  if glusterfs_stack_name is None:
    glusterfs_stack_name = click.prompt('Specify a unique name for the CNS CloudFormation stack')

 # If no keypair is specified fail:
  if keypair is None:
    keypair = click.prompt('A SSH keypair must be specified or created')

  # If the user already provided values, don't bother asking again
  if deployment_type in ['openshift-enterprise'] and rhsm_user is None:
    rhsm_user = click.prompt("RHSM username?")
  if deployment_type in ['openshift-enterprise'] and rhsm_password is None:
    rhsm_password = click.prompt("RHSM password?", hide_input=True)
  if deployment_type in ['openshift-enterprise'] and rhsm_pool is None:
    rhsm_pool = click.prompt("RHSM Pool ID or Subscription Name for OpenShift?")

  # Prompt for vars if they are not defined
  if use_cloudformation_facts and iam_role is None:
    iam_role = "Computed by Cloudformations"
  elif iam_role is None:
    iam_role = click.prompt("Specify the IAM Role of the node?")

  if use_cloudformation_facts and node_sg is None:
    node_sg = "Computed by Cloudformations"
  elif node_sg is None:
    node_sg = click.prompt("Specify the Security Group for the nodes?")

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

  if glusterfs_volume_type in ['io1']:
    iops = click.prompt('Specify a numeric value for iops')

  if iops is None:
    iops = "NA"

  # Hidden facts for infrastructure.yaml
  create_key = "no"
  create_vpc = "no"
  add_node = "yes"
  deploy_glusterfs = "true"
  node_type = "glusterfs"

  # Display information to the user about their choices
  if use_cloudformation_facts:
      click.echo('Configured values:')
      click.echo('\tami: %s' % ami)
      click.echo('\tregion: %s' % region)
      click.echo('\tglusterfs_stack_name: %s' % glusterfs_stack_name)
      click.echo('\tnode_instance_type: %s' % node_instance_type)
      click.echo('\tglusterfs_volume_type: %s' % glusterfs_volume_type)
      click.echo('\tglusterfs_volume_size: %s' % glusterfs_volume_size)
      click.echo('\tiops: %s' % iops)
      click.echo('\topenshift_sdn: %s' % openshift_sdn)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tdeployment_type: %s' % deployment_type)
      click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
      click.echo('\tconsole port: %s' % console_port)
      click.echo('\trhsm_user: %s' % rhsm_user)
      click.echo('\trhsm_password: *******')
      click.echo('\trhsm_pool: %s' % rhsm_pool)
      click.echo('\tcontainerized: %s' % containerized)
      click.echo('\texisting_stack: %s' % existing_stack)
      click.echo('\tSubnets, Security Groups, and IAM Roles will be gather from the CloudFormation')
      click.echo("")
  else:
      click.echo('Configured values:')
      click.echo('\tami: %s' % ami)
      click.echo('\tregion: %s' % region)
      click.echo('\tglusterfs_stack_name: %s' % glusterfs_stack_name)
      click.echo('\tnode_instance_type: %s' % node_instance_type)
      click.echo('\tprivate_subnet_id1: %s' % private_subnet_id1)
      click.echo('\tprivate_subnet_id2: %s' % private_subnet_id2)
      click.echo('\tprivate_subnet_id3: %s' % private_subnet_id3)
      click.echo('\tglusterfs_volume_type: %s' % glusterfs_volume_type)
      click.echo('\tglusterfs_volume_size: %s' % glusterfs_volume_size)
      click.echo('\tiops: %s' % iops)
      click.echo('\openshift_sdn: %s' % openshift_sdn)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tnode_sg: %s' % node_sg)
      click.echo('\tdeployment_type: %s' % deployment_type)
      click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
      click.echo('\tconsole port: %s' % console_port)
      click.echo('\trhsm_user: %s' % rhsm_user)
      click.echo('\trhsm_password: *******')
      click.echo('\trhsm_pool: %s' % rhsm_pool)
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
        glusterfs_stack_name=%s \
        add_node=yes \
    	node_instance_type=%s \
    	public_hosted_zone=%s \
        deployment_type=%s \
        console_port=%s \
        rhsm_user=%s \
        rhsm_password=%s \
        rhsm_pool="%s" \
        containerized=%s \
        node_type=glusterfs \
        key_path=/dev/null \
        create_key=%s \
        create_vpc=%s \
        deploy_glusterfs=%s \
        glusterfs_volume_type=%s \
        glusterfs_volume_size=%s \
        iops=%s \
        openshift_sdn=%s \
        stack_name=%s \' %s' % (region,
                    	ami,
                    	keypair,
                        glusterfs_stack_name,
                    	node_instance_type,
                    	public_hosted_zone,
                    	deployment_type,
                        console_port,
                    	rhsm_user,
                    	rhsm_password,
                    	rhsm_pool,
                    	containerized,
                    	create_key,
                    	create_vpc,
                    	deploy_glusterfs,
                        glusterfs_volume_type,
                        glusterfs_volume_size,
                        iops,
                        openshift_sdn,
                    	existing_stack,
                    	playbook)
    else:
        command='ansible-playbook -i inventory/aws/hosts -e \'region=%s \
        ami=%s \
        keypair=%s \
        glusterfs_stack_name=%s \
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
    	  rhsm_pool="%s" \
    	  containerized=%s \
    	  node_type=glusterfs \
    	  iam_role=%s \
    	  key_path=/dev/null \
    	  create_key=%s \
    	  create_vpc=%s \
    	  deploy_glusterfs=%s \
          glusterfs_volume_type=%s \
          glusterfs_volume_size=%s \
          iops=%s \
          openshift_sdn=%s \
    	  stack_name=%s \' %s' % (region,
                    	ami,
                    	keypair,
                        glusterfs_stack_name,
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
                    	rhsm_pool,
                    	containerized,
                    	iam_role,
                    	create_key,
                    	create_vpc,
                    	deploy_glusterfs,
                        glusterfs_volume_type,
                        glusterfs_volume_size,
                        iops,
                        openshift_sdn,
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

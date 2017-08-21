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
@click.option('--openshift-sdn', default='redhat/openshift-ovs-multitenant', help='OpenShift SDN (redhat/openshift-ovs-subnet, redhat/openshift-ovs-multitenant, or other supported SDN)',
              show_default=True)

### AWS/EC2 options
@click.option('--region', default='us-east-1', help='ec2 region',
              show_default=True)
@click.option('--ami', default='ami-10251c7a', help='ec2 ami',
              show_default=True)
@click.option('--node-instance-type', default='t2.medium', help='ec2 instance type',
              show_default=True)
@click.option('--use-cloudformation-facts', is_flag=True, help='Use cloudformation to populate facts. Requires Deployment >= OCP 3.5',
              show_default=True)
@click.option('--keypair', help='ec2 keypair name',
              show_default=True)
@click.option('--subnet-id', help='Specify a Private subnet within the existing VPC',
              show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')
@click.option('--app-dns-prefix', default='apps', help='application dns prefix',
              show_default=True)

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
@click.option('--shortname', help='Specify the hostname of the system',
              show_default=True)
@click.option('--node-sg', help='Specify the already existing node security group id',
              show_default=True)
@click.option('--infra-sg', help='Specify the already existing Infrastructure node security group id',
              show_default=True)
@click.option('--node-type', default='app', help='Specify the node label (example: infra or app)',
              show_default=True)
@click.option('--infra-elb-name', help='Specify the name of the ELB used for the router and registry')
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
                    subnet_id=None,
                    node_sg=None,
                    infra_sg=None,
                    public_hosted_zone=None,
                    app_dns_prefix=None,
                    shortname=None,
                    fqdn=None,
                    deployment_type=None,
                    console_port=443,
                    rhsm_user=None,
                    rhsm_password=None,
                    rhsm_pool=None,
                    containerized=None,
                    node_type=None,
                    iam_role=None,
                    infra_elb_name=None,
                    existing_stack=None,
                    openshift_sdn=None,
                    use_cloudformation_facts=False,
                    verbose=0):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  if shortname is None:
    shortname = click.prompt('Hostname of newly created system')

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
  if deployment_type in ['openshift-enterprise'] and rhsm_pool is None:
    rhsm_pool = click.prompt("RHSM Pool ID or Subscription Name?")

  # Prompt for vars if they are not defined
  if use_cloudformation_facts and iam_role is None:
    iam_role = "Computed by Cloudformations"
  elif iam_role is None:
    iam_role = click.prompt("Specify the IAM Role of the node?")

 # If no keypair is specified fail:
  if subnet_id is None:
    subnet_id = click.prompt('A private subnet must be specified for the instance')

  if use_cloudformation_facts and node_sg is None:
    node_sg = "Computed by Cloudformations"
  elif node_sg is None:
    node_sg = click.prompt("Specify the Security Group for the nodes?")

  if node_type in 'infra' and use_cloudformation_facts: 
    infra_sg = "Computed by Cloudformations"
  elif node_type in 'infra' and infra_sg is None:
    infra_sg = click.prompt("Specify the Infra Security Group for the node?")

  # Calculate various DNS values
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  # calculate stack name
  new_node_stack="%s-%s" % (existing_stack, shortname)

  # Calculate various DNS values
  fqdn="%s.%s" % (shortname, public_hosted_zone)

  # Hidden facts for infrastructure.yaml
  create_key = "no"
  create_vpc = "no"
  deploy_glusterfs = "false"
  add_node = "yes"

  # Display information to the user about their choices
  if use_cloudformation_facts:
      click.echo('Configured values:')
      click.echo('\tami: %s' % ami)
      click.echo('\tregion: %s' % region)
      click.echo('\tnode_instance_type: %s' % node_instance_type)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tsubnet_id: %s' % subnet_id)
      click.echo('\tconsole port: %s' % console_port)
      click.echo('\tdeployment_type: %s' % deployment_type)
      click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
      click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
      click.echo('\tapps_dns: %s' % wildcard_zone)
      click.echo('\tshortname: %s' % shortname)
      click.echo('\tfqdn: %s' % fqdn)
      click.echo('\trhsm_user: %s' % rhsm_user)
      click.echo('\trhsm_password: *******')
      click.echo('\trhsm_pool: %s' % rhsm_pool)
      click.echo('\tcontainerized: %s' % containerized)
      click.echo('\tnode_type: %s' % node_type)
      click.echo('\texisting_stack: %s' % existing_stack)
      click.echo('\topenshit_sdn: %s' % openshift_sdn)
      click.echo('\tSubnets, Security Groups, and IAM Roles will be gather from the CloudFormation')
      click.echo("")
  else:
      click.echo('Configured values:')
      click.echo('\tami: %s' % ami)
      click.echo('\tregion: %s' % region)
      click.echo('\tnode_instance_type: %s' % node_instance_type)
      click.echo('\tkeypair: %s' % keypair)
      click.echo('\tsubnet_id: %s' % subnet_id)
      click.echo('\tnode_sg: %s' % node_sg)
      click.echo('\tinfra_sg: %s' % infra_sg)
      click.echo('\tconsole port: %s' % console_port)
      click.echo('\tdeployment_type: %s' % deployment_type)
      click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
      click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
      click.echo('\tapps_dns: %s' % wildcard_zone)
      click.echo('\tshortname: %s' % shortname)
      click.echo('\tfqdn: %s' % fqdn)
      click.echo('\trhsm_user: %s' % rhsm_user)
      click.echo('\trhsm_password: *******')
      click.echo('\trhsm_pool: %s' % rhsm_pool)
      click.echo('\tcontainerized: %s' % containerized)
      click.echo('\tnode_type: %s' % node_type)
      click.echo('\tiam_role: %s' % iam_role)
      click.echo('\tinfra_elb_name: %s' % infra_elb_name)
      click.echo('\texisting_stack: %s' % existing_stack)
      click.echo('\topenshift_sdn: %s' % openshift_sdn)
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
        subnet_id=%s \
        node_instance_type=%s \
        public_hosted_zone=%s \
        wildcard_zone=%s \
        shortname=%s \
        fqdn=%s \
        console_port=%s \
        deployment_type=%s \
        rhsm_user=%s \
        rhsm_password=%s \
        rhsm_pool="%s" \
        containerized=%s \
        node_type=%s \
        key_path=/dev/null \
        infra_elb_name=%s \
        create_key=%s \
        create_vpc=%s \
        deploy_glusterfs=%s \
        new_node_stack=%s \
        stack_name=%s \
        openshift_sdn=%s \' %s' % (region,
                        ami,
                        keypair,
                        subnet_id,
                        node_instance_type,
                        public_hosted_zone,
                        wildcard_zone,
                        shortname,
                        fqdn,
                        console_port,
                        deployment_type,
                        rhsm_user,
                        rhsm_password,
                        rhsm_pool,
                        containerized,
                        node_type,
                        infra_elb_name,
                        create_key,
                        create_vpc,
                        deploy_glusterfs,
                        new_node_stack,
                        existing_stack,
                        openshift_sdn,
                        playbook)

    else:
        command='ansible-playbook -i inventory/aws/hosts -e \'region=%s \
        ami=%s \
        keypair=%s \
        add_node=yes \
        subnet_id=%s \
        node_sg=%s \
        infra_sg=%s \
        node_instance_type=%s \
        public_hosted_zone=%s \
        wildcard_zone=%s \
        shortname=%s \
        fqdn=%s \
        console_port=%s \
        deployment_type=%s \
        rhsm_user=%s \
        rhsm_password=%s \
        rhsm_pool="%s" \
        containerized=%s \
        node_type=%s \
        iam_role=%s \
        key_path=/dev/null \
        infra_elb_name=%s \
        create_key=%s \
        create_vpc=%s \
        deploy_glusterfs=%s \
        new_node_stack=%s \
        stack_name=%s \
        openshift_sdn=%s \' %s' % (region,
                        ami,
                        keypair,
                        subnet_id,
                        node_sg,
                        infra_sg,
                        node_instance_type,
                        public_hosted_zone,
                        wildcard_zone,
                        shortname,
                        fqdn,
                        console_port,
                        deployment_type,
                        rhsm_user,
                        rhsm_password,
                        rhsm_pool,
                        containerized,
                        node_type,
                        iam_role,
                        infra_elb_name,
                        create_key,
                        create_vpc,
                        deploy_glusterfs,
                        new_node_stack,
                        existing_stack,
                        openshift_sdn,
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

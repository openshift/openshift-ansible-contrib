#!/usr/bin/env python
# vim: sw=2 ts=2

import click
from jinja2 import Environment, FileSystemLoader
import os
import sys
import json
import types
from copy import deepcopy

@click.command()

### Cluster options
@click.option('--console-port', default='443', type=click.IntRange(1,65535), help='OpenShift web console port',
              show_default=True)
@click.option('--deployment-type', default='openshift-enterprise', help='OpenShift deployment type',
              show_default=True)

### AWS/EC2 options
@click.option('--stack-name', default='OpenShift-Infra', help='CloudFormation stack name',
              show_default=True)
@click.option('--region', default='us-east-1', help='ec2 region',
              show_default=True)
@click.option('--ami', default='ami-10251c7a', help='ec2 ami',
              show_default=True)
@click.option('--master-instance-type', default='m4.large', help='ec2 instance type',
              show_default=True)
@click.option('--master-instance-count', default='3', type=click.IntRange(3,9), help='Number of master nodes to provision',
              show_default=True)
@click.option('--infra-instance-type', default='t2.small', help='ec2 instance type',
              show_default=True)
@click.option('--infra-instance-count', default='2', type=click.IntRange(2,9), help='Number of application nodes to provision',
              show_default=True)
@click.option('--node-instance-type', default='t2.medium', help='ec2 instance type',
              show_default=True)
@click.option('--node-instance-count', default='2', type=click.IntRange(2,9), help='Number of application nodes to provision',
              show_default=True)
@click.option('--keypair', help='ec2 keypair name',
              show_default=True)
@click.option('--create-key', default='no', help='Create SSH keypair',
              show_default=True)
@click.option('--key-path', default='/dev/null', help='Path to SSH public key. Default is /dev/null which will skip the step',
              show_default=True)
@click.option('--create-vpc', default='yes', help='Create VPC',
              show_default=True)
@click.option('--vpc-id', help='Specify an already existing VPC',
              show_default=True)
@click.option('--private-subnet-id1', help='Specify a Private subnet within the existing VPC',
              show_default=True)
@click.option('--private-subnet-id2', help='Specify a Private subnet within the existing VPC',
              show_default=True)
@click.option('--private-subnet-id3', help='Specify a Private subnet within the existing VPC',
              show_default=True)
@click.option('--public-subnet-id1', help='Specify a Public subnet within the existing VPC',
              show_default=True)
@click.option('--public-subnet-id2', help='Specify a Public subnet within the existing VPC',
              show_default=True)
@click.option('--public-subnet-id3', help='Specify a Public subnet within the existing VPC',
              show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')
@click.option('--app-dns-prefix', default='apps', help='application dns prefix',
              show_default=True)

### Subscription and Software options
@click.option('--rhsm-user', help='Red Hat Subscription Management User')
@click.option('--rhsm-password', help='Red Hat Subscription Management Password',
                hide_input=True,)
@click.option('--rhsm-pool', help='Red Hat Subscription Management Pool ID or Subscription Name')

### Miscellaneous options
@click.option('--byo-bastion', default='no', help='skip bastion install when one exists within the cloud provider',
              show_default=True)
@click.option('--bastion-sg', default='/dev/null', help='Specify Bastion Security group used with byo-bastion',
              show_default=True)
@click.option('--no-confirm', is_flag=True,
              help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)
@click.option('--vars-file', default='vars/main.yaml',
            help="Location of environment specific variables, either fully qualified or relative to the playbooks directory",
            show_default=True)
@click.option('--custom-template', help="Define the location of a custom json file. Use it to define additional AWS resources during stack creation. Has to be a valid cfn template")


def launch_refarch_env(stack_name=None,
                       region=None,
                       ami=None,
                       no_confirm=False,
                       master_instance_type=None,
                       master_instance_count=3,
                       infra_instance_type=None,
                       infra_instance_count=2,
                       node_instance_type=None,
                       node_instance_count=2,
                       keypair=None,
                       create_key=None,
                       key_path=None,
                       create_vpc=None,
                       vpc_id=None,
                       private_subnet_id1=None,
                       private_subnet_id2=None,
                       private_subnet_id3=None,
                       public_subnet_id1=None,
                       public_subnet_id2=None,
                       public_subnet_id3=None,
                       byo_bastion=None,
                       bastion_sg=None,
                       public_hosted_zone=None,
                       app_dns_prefix=None,
                       deployment_type=None,
                       console_port=443,
                       rhsm_user=None,
                       rhsm_password=None,
                       rhsm_pool=None,
                       vars_file=None,
                       custom_template=None,
                       verbose=0):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  # If user specified a custom vars_file and not a custom stack_name
  if vars_file !='vars/main.yaml' and stack_name == 'OpenShift-Infra':
    stack_name = click.prompt('Specify a name for the CloudFormation stack')

  # Create ssh key pair in AWS if none is specified
  if create_key in 'yes' and key_path in 'no':
    key_path = click.prompt('Specify path for ssh public key')
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
  if create_vpc in 'no' and private_subnet_id1 is None:
    private_subnet_id1 = click.prompt('Specify the first Private subnet within the existing VPC')
    private_subnet_id2 = click.prompt('Specify the second Private subnet within the existing VPC')
    private_subnet_id3 = click.prompt('Specify the third Private subnet within the existing VPC')
    public_subnet_id1 = click.prompt('Specify the first Public subnet within the existing VPC')
    public_subnet_id2 = click.prompt('Specify the second Public subnet within the existing VPC')
    public_subnet_id3 = click.prompt('Specify the third Public subnet within the existing VPC')

 # Prompt for Bastion SG if byo-bastion specified
  if byo_bastion in 'yes' and bastion_sg in '/dev/null':
    bastion_sg = click.prompt('Specify the the Bastion Security group(example: sg-4afdd24)')
  

  # If the user already provided values, don't bother asking again
  if rhsm_user is None:
    rhsm_user = click.prompt("RHSM username?")
  if rhsm_password is None:
    rhsm_password = click.prompt("RHSM password?")
  if rhsm_pool is None:
    rhsm_pool = click.prompt("RHSM Pool ID or Subscription Name?")

  # Calculate various DNS values
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  # Display information to the user about their choices
  click.echo('Configured values:')
  click.echo('\tami: %s' % ami)
  click.echo('\tstack_name: %s' % stack_name)
  click.echo('\tregion: %s' % region)
  click.echo('\tmaster_instance_type: %s' % master_instance_type)
  click.echo('\tmaster_instance_count: %s' % master_instance_count)
  click.echo('\tinfra_instance_type: %s' % infra_instance_type)
  click.echo('\tinfra_instance_count: %s' % infra_instance_count)
  click.echo('\tnode_instance_type: %s' % node_instance_type)
  click.echo('\tnode_instance_count: %s' % node_instance_count)
  click.echo('\tkeypair: %s' % keypair)
  click.echo('\tcreate_key: %s' % create_key)
  click.echo('\tkey_path: %s' % key_path)
  click.echo('\tcreate_vpc: %s' % create_vpc)
  click.echo('\tvpc_id: %s' % vpc_id)
  click.echo('\tprivate_subnet_id1: %s' % private_subnet_id1)
  click.echo('\tprivate_subnet_id2: %s' % private_subnet_id2)
  click.echo('\tprivate_subnet_id3: %s' % private_subnet_id3)
  click.echo('\tpublic_subnet_id1: %s' % public_subnet_id1)
  click.echo('\tpublic_subnet_id2: %s' % public_subnet_id2)
  click.echo('\tpublic_subnet_id3: %s' % public_subnet_id3)
  click.echo('\tbyo_bastion: %s' % byo_bastion)
  click.echo('\tbastion_sg: %s' % bastion_sg)
  click.echo('\tconsole port: %s' % console_port)
  click.echo('\tdeployment_type: %s' % deployment_type)
  click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
  click.echo('\tapps_dns: %s' % wildcard_zone)
  click.echo('\trhsm_user: %s' % rhsm_user)
  click.echo('\trhsm_password: *******')
  click.echo('\trhsm_pool: %s' % rhsm_pool)
  click.echo('\tvars_file: %s' % vars_file)
  click.echo('\tcustom_template: %s' % custom_template)
  click.echo("")

  if not no_confirm:
    click.confirm('Continue using these values?', abort=True)

  playbooks = ['playbooks/infrastructure.yaml', 'playbooks/openshift-install.yaml']

  for playbook in playbooks:

    if create_vpc == 'yes':
      install_type='greenfield'
    elif create_vpc == 'no' and bastion_byo == 'no':
      install_type = 'brownfield'
    elif create_vpc == 'no' and bastion_byo == 'yes':
      install_type = 'brownfield-byo-bastion'

    if custom_template != None:
      custom_fragment = custom_template 
    else:
      custom_fragment = None

    render_template(install_type=install_type,
                    master_count=master_instance_count,
                    infra_count=infra_instance_count,
                    node_count=node_instance_count, custom_template=custom_fragment)

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
    stack_name=%s \
    keypair=%s \
    create_key=%s \
    key_path=%s \
    create_vpc=%s \
    vpc_id=%s \
    private_subnet_id1=%s \
    private_subnet_id2=%s \
    private_subnet_id3=%s \
    public_subnet_id1=%s \
    public_subnet_id2=%s \
    public_subnet_id3=%s \
    byo_bastion=%s \
    bastion_sg=%s \
    master_instance_type=%s \
    infra_instance_type=%s \
    node_instance_type=%s \
    public_hosted_zone=%s \
    wildcard_zone=%s \
    console_port=%s \
    deployment_type=%s \
    rhsm_user=%s \
    rhsm_password=%s \
    rhsm_pool=%s \
    vars_file=%s \
    custom_template=%s \' %s' % (region,
                    ami,
                    stack_name,
                    keypair,
                    create_key,
                    key_path,
                    create_vpc,
                    vpc_id,
                    private_subnet_id1,
                    private_subnet_id2,
                    private_subnet_id3,
                    public_subnet_id1,
                    public_subnet_id2,
                    public_subnet_id3,
                    byo_bastion,
                    bastion_sg,
                    master_instance_type,
                    infra_instance_type,
                    node_instance_type,
                    public_hosted_zone,
                    wildcard_zone,
                    console_port,
                    deployment_type,
                    rhsm_user,
                    rhsm_password,
                    rhsm_pool,
                    vars_file,
                    custom_template,
                    playbook)

    if verbose > 0:
      command += " -" + "".join(['v']*verbose)
      click.echo('We are running: %s' % command)

    status = os.system(command)
    if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
      return os.WEXITSTATUS(status)

def render_template(install_type="greenfield", master_count=3, infra_count=4, node_count=2, custom_template=None):
  tmpl = Environment(loader=FileSystemLoader('./'), trim_blocks=True)
  t_in = ("playbooks/roles/cloudformation-infra/files/%s.json.j2") % (install_type)
  t_out = ("playbooks/roles/cloudformation-infra/files/%s.json") % (install_type)

  if custom_template:
    r1 = tmpl.get_template(t_in).render(
          master_count=(master_count + 1),
          infra_count=(infra_count + 1),
          node_count=(node_count + 1))
    r2 = tmpl.get_template(custom_template).render(
          master_count=(master_count + 1),
          infra_count=(infra_count + 1),
          node_count=(node_count + 1))
    rendered = merge(json.loads(r1), json.loads(r2))
    rendered = json.dumps(rendered) 
  else:
    rendered = tmpl.get_template(t_in).render(
          master_count=(master_count + 1),
          infra_count=(infra_count + 1),
          node_count=(node_count + 1))

  with open(t_out, "wb") as fh:
    fh.write(rendered)


def merge(a, b):
   c = deepcopy(a)
   if type(a) != type(b):
     c = b
   elif type(b) is types.DictType:
     for k,v in b.items():
       if k in a:
         c[k] = merge(a[k], v)
       else:
         c[k] = b[k]
   elif type(b) is types.ListType:
     for v in b:
       if v not in c:
         c.append(v)
   else:
     c = b

   return c


if __name__ == '__main__':
  # check for AWS access info
  if os.getenv('AWS_ACCESS_KEY_ID') is None or os.getenv('AWS_SECRET_ACCESS_KEY') is None:
    print 'AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY **MUST** be exported as environment variables.'
    sys.exit(1)

  launch_refarch_env(auto_envvar_prefix='OSE_REFArch')

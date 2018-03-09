#!/usr/bin/env python
# vim: sw=2 ts=2

import click
import os
import sys

@click.command()

### Cluster options
@click.option('--openshift-ansible-path', default='/usr/share/ansible/openshift-ansible', help='Default path to openshift-ansible playbooks', show_default=True)
@click.option('--openshift-version', default='3.6.1', help='Openshift version', show_default=True)
@click.option('--stack-name', default='openshift-infra', help='Cloudformation stack name. Must be unique', show_default=True)
@click.option('--console-port', default='8443', type=click.IntRange(1,65535), help='OpenShift web console port', show_default=True)
@click.option('--deployment-type', default='openshift-enterprise', type=click.Choice(['origin', 'openshift-enterprise']),  help='OpenShift deployment type', show_default=True)
@click.option('--openshift-sdn', default='redhat/openshift-ovs-multitenant', help='OpenShift SDN (redhat/openshift-ovs-subnet, redhat/openshift-ovs-multitenant, or other supported SDN)', show_default=True)

### AWS/EC2 options
@click.option('--region', default='us-east-1', help='ec2 region', show_default=True)
@click.option('--ami', default='ami-fbc89880', help='ec2 ami', show_default=True)
@click.option('--master-instance-type', default='m4.xlarge', help='ec2 instance type', show_default=True)
@click.option('--node-instance-type', default='m4.xlarge', help='ec2 instance type', show_default=True)
@click.option('--app-instance-type', default='t2.large', help='ec2 instance type', show_default=True)
@click.option('--app-node-count', default='3', help='Number of Application Nodes', show_default=True)
@click.option('--keypair', help='ec2 keypair name', show_default=True)
@click.option('--create-key', default='no', help='Create SSH keypair', show_default=True)
@click.option('--key-path', default='/dev/null', help='Path to SSH public key. Default is /dev/null which will skip the step', show_default=True)
@click.option('--create-vpc', default='yes', help='Create VPC', show_default=True)
@click.option('--all-in-one', default='false', help='Cluster of single node OpenShift', show_default=True)
@click.option('--vpc-id', help='Specify an already existing VPC', show_default=True)
@click.option('--private-subnet-id1', help='Specify a Private subnet within the existing VPC', show_default=True)
@click.option('--private-subnet-id2', help='Specify a Private subnet within the existing VPC', show_default=True)
@click.option('--private-subnet-id3', help='Specify a Private subnet within the existing VPC', show_default=True)
@click.option('--public-subnet-id1', help='Specify a Public subnet within the existing VPC', show_default=True)
@click.option('--public-subnet-id2', help='Specify a Public subnet within the existing VPC', show_default=True)
@click.option('--public-subnet-id3', help='Specify a Public subnet within the existing VPC', show_default=True)

### DNS options
@click.option('--public-hosted-zone', help='hosted zone for accessing the environment')
@click.option('--app-dns-prefix', default='apps', help='application dns prefix', show_default=True)


### Subscription and Software options
@click.option('--rhsm-user', help='Red Hat Subscription Management User')
@click.option('--rhsm-password', help='Red Hat Subscription Management Password', hide_input=True,)
@click.option('--rhsm-pool', help='Red Hat Subscription Management Pool Name')

### Miscellaneous options
@click.option('--byo-bastion', default='no', help='skip bastion install when one exists within the cloud provider', show_default=True)
@click.option('--bastion-sg', default='/dev/null', help='Specify Bastion Security group used with byo-bastion', show_default=True)
@click.option('--containerized', default='False', help='Containerized installation of OpenShift', show_default=True)
@click.option('--s3-bucket-name', help='Bucket name for S3 for registry')
@click.option('--google-client-id', help='Google OAuth ClientID')
@click.option('--google-client-secret', help='Google OAuth Client Secret')
@click.option('--google-hosted-domain', help='Google Hosted Domain')
@click.option('--s3-username',  help='S3 user for registry access')
@click.option('--openshift-docker-storage-volume-size', default='25Gi', help='Size of OptionShift Docker Logical Volume On Application Nodes', show_default=False)
@click.option('--openshift-metrics-deploy',  help='Deploy OpenShift Metrics', type=click.Choice(['true', 'false']), default='true')
@click.option('--openshift-logging-deploy',  help='Deploy OpenShift Logging', type=click.Choice(['true', 'false']), default='true')
@click.option('--openshift-metrics-storage-volume-size', default='20Gi', help='Size of OptionShift Metrics Persistent Volume', show_default=False)
@click.option('--openshift-logging-storage-volume-size', default='100Gi', help='Size of OptionShift Logging Persistent Volume', show_default=False)
@click.option('--openshift-disable-check', default='', help='Disable check on aspects of hardware requirements', show_default=True)
@click.option('--no-confirm', is_flag=True, help='Skip confirmation prompt')
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)

def launch_refarch_env(region=None,
                    stack_name=None,
                    ami=None,
                    no_confirm=False,
                    master_instance_type=None,
                    node_instance_type=None,
                    app_instance_type=None,
                    app_node_count=None,
                    keypair=None,
                    create_key=None,
                    key_path=None,
                    create_vpc=None,
                    all_in_one=None,
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
                    openshift_sdn=None,
                    console_port=8443,
                    rhsm_user=None,
                    rhsm_password=None,
                    rhsm_pool=None,
                    containerized=None,
                    s3_bucket_name=None,
                    s3_username=None,
                    google_client_id=None,
                    google_client_secret=None,
                    google_hosted_domain=None,
                    openshift_docker_storage_volume_size=None,
                    openshift_metrics_deploy=None,
                    openshift_metrics_storage_volume_size=None,
                    openshift_logging_deploy=None,
                    openshift_logging_storage_volume_size=None,
                    openshift_disable_check=None,
                    openshift_version=None,
                    openshift_ansible_path=None,
                    verbose=0):

  # Need to prompt for the R53 zone:
  if public_hosted_zone is None:
    public_hosted_zone = click.prompt('Hosted DNS zone for accessing the environment')

  if s3_bucket_name is None:
    s3_bucket_name = stack_name + '-ocp-registry-' + public_hosted_zone.split('.')[0]

  if s3_username is None:
    s3_username = stack_name + '-s3-openshift-user'

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

 # Fail on missing key_path
  if key_path in '/dev/null' and create_key in 'yes':
    key_path = click.prompt('Specify the location of the public key')

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

  app_node_count = int(app_node_count)
  if app_node_count > 3:
    click.echo("Please choose a value between 1 and 3")
    sys.exit(1)

  if master_instance_type in ['m4.large', 't2.micro', 't2.small', 't2.nano', 'm3.medium', 'm3.large', 'm3.xlarge']:
    click.echo('The master instance type will not support an OpenShift deployment')
    sys.exit(1)

  if node_instance_type in ['t2.micro', 't2.nano', 'm3.medium', 'm3.large']:
    click.echo('The node instance type will not support an OpenShift deployment')
    sys.exit(1)

  if app_instance_type in ['t2.micro', 't2.nano', 'm3.medium', 'm3.large']:
    click.echo('The app instance type will not support an OpenShift deployment')
    sys.exit(1)

 # Prompt for Bastion SG if byo-bastion specified
  if byo_bastion in 'yes' and bastion_sg in '/dev/null':
    bastion_sg = click.prompt('Specify the the Bastion Security group(example: sg-4afdd24)')

  # If the user already provided values, don't bother asking again
  if deployment_type in ['openshift-enterprise'] and rhsm_user is None:
    rhsm_user = click.prompt("RHSM username?")
  if deployment_type in ['openshift-enterprise'] and rhsm_password is None:
    rhsm_password = click.prompt("RHSM password?", hide_input=True)
  if deployment_type in ['openshift-enterprise'] and rhsm_pool is None:
    rhsm_pool = click.prompt("RHSM Pool ID or Subscription Name?")

  # Calculate various DNS values
  wildcard_zone="%s.%s" % (app_dns_prefix, public_hosted_zone)

  # Google Authentication
  if google_hosted_domain is None or not google_hosted_domain:
    click.echo('A Google hosted domain must be provided')
    sys.exit(1)
  if google_client_id is None:
    google_client_id = click.prompt('Specify the ClientID for Google OAuth')
  if google_client_secret is None:
    google_client_secret = click.prompt('Specify the Client Secret for Google OAuth')

  deploy_glusterfs = "false"

  # Display information to the user about their choices
  click.echo('Configured values:')
  click.echo('\tstack_name: %s' % stack_name)
  click.echo('\tami: %s' % ami)
  click.echo('\tregion: %s' % region)
  click.echo('\tmaster_instance_type: %s' % master_instance_type)
  click.echo('\tnode_instance_type: %s' % node_instance_type)
  click.echo('\tapp_instance_type: %s' % app_instance_type)
  click.echo('\tapp_node_count: %d' % app_node_count)
  click.echo('\tkeypair: %s' % keypair)
  click.echo('\tcreate_key: %s' % create_key)
  click.echo('\tkey_path: %s' % key_path)
  click.echo('\tcreate_vpc: %s' % create_vpc)
  click.echo('\tall_in_one: %s' % all_in_one)
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
  click.echo('\topenshift_sdn: %s' % openshift_sdn)
  click.echo('\tpublic_hosted_zone: %s' % public_hosted_zone)
  click.echo('\tapp_dns_prefix: %s' % app_dns_prefix)
  click.echo('\tapps_dns: %s' % wildcard_zone)
  click.echo('\tcontainerized: %s' % containerized)
  click.echo('\ts3_bucket_name: %s' % s3_bucket_name)
  click.echo('\ts3_username: %s' % s3_username)
  click.echo('\tgoogle_client_id: *******')
  click.echo('\tgoogle_client_secret: *******')
  click.echo('\tgoogle_hosted_domain: %s' % google_hosted_domain)
  click.echo('\topenshift_docker_storage_volume_size: %s' % openshift_docker_storage_volume_size)
  click.echo('\topenshift_metrics_deploy: %s' % openshift_metrics_deploy)
  click.echo('\topenshift_metrics_storage_volume_size: %s' % openshift_metrics_storage_volume_size)
  click.echo('\topenshift_logging_deploy: %s' % openshift_logging_deploy)
  click.echo('\topenshift_logging_storage_volume_size: %s' % openshift_logging_storage_volume_size)
  click.echo('\topenshift_disable_check: %s' % openshift_disable_check)
  click.echo('\topenshift_version: %s' % openshift_version)
  click.echo('\topenshift_ansible_path: %s' % openshift_ansible_path)
  click.echo("")

  # app_node_count = (app_node_count +1)

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

    command='ansible-playbook -i inventory/aws/hosts -v -e \'region=%s \
    enable_excluders=false \
    stack_name=%s \
    ami=%s \
    keypair=%s \
    create_key=%s \
    add_node=no \
    key_path=%s \
    create_vpc=%s \
    all_in_one=%s \
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
    node_instance_type=%s \
    app_instance_type=%s \
    app_node_count=%d \
    public_hosted_zone=%s \
    wildcard_zone=%s \
    console_port=%s \
    deployment_type=%s \
    openshift_sdn=%s \
    rhsm_user=%s \
    rhsm_password=%s \
    rhsm_pool="%s" \
    containerized=%s \
    s3_bucket_name=%s \
    s3_username=%s \
    google_client_id=%s \
    google_client_secret=%s \
    google_hosted_domain=%s \
    openshift_docker_storage_volume_size=%s \
    deploy_glusterfs=%s \
    openshift_hosted_metrics_deploy=%s \
    openshift_hosted_metrics_storage_volume_size=%s \
    openshift_hosted_logging_deploy=%s \
    openshift_hosted_logging_storage_volume_size=%s \
    openshift_disable_check=%s \
    openshift_version=%s \
    etcd_image=registry.fedoraproject.org/f26/etcd \
    openshift_ansible_path=%s\' \
    %s' % (region,
                    stack_name,
                    ami,
                    keypair,
                    create_key,
                    key_path,
                    create_vpc,
                    all_in_one,
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
                    node_instance_type,
                    app_instance_type,
                    int(app_node_count),
                    public_hosted_zone,
                    wildcard_zone,
                    console_port,
                    deployment_type,
                    openshift_sdn,
                    rhsm_user,
                    rhsm_password,
                    rhsm_pool,
                    containerized,
                    s3_bucket_name,
                    s3_username,
                    google_client_id,
                    google_client_secret,
                    google_hosted_domain,
                    openshift_docker_storage_volume_size,
                    deploy_glusterfs,
                    openshift_metrics_deploy,
                    openshift_metrics_storage_volume_size,
                    openshift_logging_deploy,
                    openshift_logging_storage_volume_size,
                    openshift_disable_check,
                    openshift_version,
                    openshift_ansible_path,
                    playbook)

    if verbose > 0:
      command += " -" + "".join(['v']*verbose)
      click.echo('We are running: %s' % command)

    status = os.system(command)
    if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
      sys.exit(os.WEXITSTATUS(status))


if __name__ == '__main__':
  # check for AWS access info
  if os.getenv('AWS_ACCESS_KEY_ID') is None or os.getenv('AWS_SECRET_ACCESS_KEY') is None:
    print('AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY **MUST** be exported as environment variables.')
    sys.exit(1)

  launch_refarch_env(auto_envvar_prefix='OSE_REFArch')

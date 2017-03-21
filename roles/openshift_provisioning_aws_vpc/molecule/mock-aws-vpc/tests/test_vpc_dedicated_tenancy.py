import testinfra.utils.ansible_runner


testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '.molecule/ansible_inventory.yml').get_hosts('dedicated_group')


def test_vpc_dedicated_tenancy(Ansible):
    vpc_facts_args = {
        'region': '{{ openshift_provisioning_aws_region }}',
        'filters': {
            'tag:openshift_cluster_id': '{{ openshift_cluster_id }}',
            'tag:openshift_env_id': '{{ openshift_env_id }}',
            'tag:Name': 'my_vpc'
        }
    }
    vpc_facts = Ansible("ec2_vpc_net_facts", vpc_facts_args, check=False)
    assert len(vpc_facts['vpcs']) == 1
    vpc = vpc_facts['vpcs'][0]
    assert vpc['instance_tenancy'] == 'dedicated'

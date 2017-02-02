import testinfra.utils.ansible_runner


testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '.molecule/ansible_inventory.yml').get_hosts('default_group')


def test_vpc_exists(Ansible):
    vpc_facts_args = {
        'region': '{{ openshift_provisioning_aws_region }}',
        'filters': {
            'tag:openshift_cluster_id': '{{ openshift_cluster_id }}',
            'tag:openshift_env_id': '{{ openshift_env_id }}',
            'tag:Name': 'openshift_{{ openshift_cluster_id }}_{{ openshift_env_id }}'
        }
    }
    vpc_facts = Ansible("ec2_vpc_net_facts", vpc_facts_args, check=False)
    assert len(vpc_facts['vpcs']) == 1
    vpc = vpc_facts['vpcs'][0]
    assert vpc['cidr_block'] == '172.18.0.0/16'
    assert vpc['instance_tenancy'] == 'default'
    assert 'Name' in vpc['tags']
    assert 'openshift_cluster_id' in vpc['tags']
    assert 'openshift_env_id' in vpc['tags']
    assert vpc['tags']['Name'] == 'openshift_test_test'
    assert vpc['tags']['openshift_cluster_id'] == 'test'
    assert vpc['tags']['openshift_env_id'] == 'test'

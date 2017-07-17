#!/usr/bin/python
# -*- coding: utf-8 -*-
# vim: expandtab:tabstop=4:shiftwidth=4
'''
Custom filters for use in gce-federation scripts
'''


def add_cloudconfig_master(master_config):
    for service in ('apiServerArguments', 'controllerArguments'):
        for key, val in {'cloud-provider': 'gce', 'cloud-config': '/var/lib/origin/openshift.local.config/gce.conf'}.items():
            if master_config['kubernetesMasterConfig'][service] is None:
                master_config['kubernetesMasterConfig'][service] = {key: [val]}
            else:
                master_config['kubernetesMasterConfig'][service][key] = [val]
    master_config['kubernetesMasterConfig']['controllerArguments']['configure-cloud-routes'] = ['true']
    master_config['kubernetesMasterConfig']['controllerArguments']['allocate-node-cidrs'] = ['true']
    master_config['kubernetesMasterConfig']['controllerArguments']['cluster-cidr'] = ['172.29.0.0/16']
    if 'ingressIPNetworkCIDR' in master_config['networkConfig']:
        del master_config['networkConfig']['ingressIPNetworkCIDR']
    return master_config


def add_cloudconfig_node(node_config, node_name):
    for key, val in {'cloud-provider': 'gce', 'cloud-config': '/var/lib/origin/openshift.local.config/gce.conf'}.items():
        if node_config['kubeletArguments'] is None:
            node_config['kubeletArguments'] = {key: [val]}
        else:
            node_config['kubeletArguments'][key] = [val]
        node_config['nodeName'] = node_name
    return node_config


class FilterModule(object):
    ''' Custom ansible filters for use by the openshift_master role'''

    def filters(self):
        ''' returns a mapping of filters to methods '''
        return {
            "add_cloudconfig_master": add_cloudconfig_master,
            "add_cloudconfig_node": add_cloudconfig_node,
        }

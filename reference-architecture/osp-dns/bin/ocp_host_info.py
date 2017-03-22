#!/usr/bin/env python

import os,sys,re
from argparse import ArgumentParser

from novaclient import client

import yaml
import json

def parse_args():

    args = ArgumentParser()
    args.add_argument("-u", "--username", default=os.environ['OS_USERNAME'])
    args.add_argument("-p", "--password", default=os.environ['OS_PASSWORD'])
    args.add_argument("-U", "--auth-url", default=os.environ['OS_AUTH_URL'])
    args.add_argument("-P", "--project", default=os.environ['OS_TENANT_NAME'])
    args.add_argument("-R", "--region", default=os.getenv('OS_REGION'))

    args.add_argument("-S", "--stack-name", default="ocp3")
    args.add_argument("-z", "--zone", default="example.com")
    args.add_argument("-c", "--control-zone", default="control")
    args.add_argument("-m", "--master", default="master")
    args.add_argument("-i", "--infra", default="infra")
    args.add_argument("-a", "--app", default="node")
    args.add_argument("-n", "--network", default=None) # dns-network

    return args.parse_args()

def floating_ip(server, network=None):
    #if network == None:
    #    network = server.addresses.keys()[0]
    for network in server.addresses.keys():
        for interface in server.addresses[network]:
            if interface[u'OS-EXT-IPS:type'] == "floating":
                return {
                    "name": server.name.encode("ascii"),
                    "address": interface['addr'].encode("ascii")
                }
    return None

def fixed_ip(server, network=None):
    #if network == None:
    #    network = server.addresses.keys()[0]
    for network in server.addresses.keys():
        for interface in server.addresses[network]:
            if interface[u'OS-EXT-IPS:type'] == "fixed":
                return {
                    "name": server.name.encode("ascii"),
                    "address": interface['addr'].encode("ascii")
                }
    return None

if __name__ == "__main__":

    opts = parse_args()

    if opts.network == None:
        network_re = re.compile("^%s-fixed_network-.*$" % opts.stack_name)
    else:
        network_re = re.compile(opts.network)
        
    master_re = re.compile("%s-%s-\d+.%s.%s$" % (
        opts.stack_name,
        opts.master,
        opts.control_zone,
        opts.zone
    ))
    infra_re = re.compile("^%s-%s-\d+.%s.%s$" % (opts.stack_name,
                                                 opts.infra,
                                                 opts.control_zone,
                                                 opts.zone))
    app_re = re.compile("^%s-%s-[^.]+.%s.%s$" % (opts.stack_name,
                                                opts.app,
                                                opts.control_zone,
                                                opts.zone))

    records = {
        'zone': opts.zone,
        'hosts': {
            'public': [],
            'private': []
        }
    }
    
    nova = client.Client("2.0",
                         opts.username,
                         opts.password,
                         opts.project,
                         opts.auth_url)

    for server in nova.servers.list():
        hostname = re.sub('\..*$', '', server.name.encode('ascii'))
        for netname in server.addresses:
            if network_re.match(netname):
                for interface in server.addresses[netname]:
                    if interface['OS-EXT-IPS:type'] == 'fixed':
                        records['hosts']['private'].append(
                            {
                                'name': hostname + "." + opts.control_zone,
                                'address': interface['addr'].encode('ascii')
                            }
                        )
                    elif interface['OS-EXT-IPS:type'] == 'floating':
                        records['hosts']['public'].append(
                            {
                                'name': hostname,
                                'address': interface['addr'].encode('ascii')
                            }
                        )
    json.dump(records, sys.stdout, indent=2)
    print

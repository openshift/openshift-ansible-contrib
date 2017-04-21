#!/usr/bin/env python
#
#
#
import os,sys,re
from optparse import OptionParser

from novaclient import client

from jinja2 import Environment, FileSystemLoader

def parse_cli():
    opts = OptionParser()
    opts.add_option("-u", "--username", default=os.environ['OS_USERNAME'])
    opts.add_option("-p", "--password", default=os.environ['OS_PASSWORD'])
    opts.add_option("-P", "--project", default=os.environ['OS_TENANT_NAME'])
    opts.add_option("-U", "--auth-url", default=os.environ['OS_AUTH_URL'])

    opts.add_option("-z", "--zone", default="example.com")
    opts.add_option("-c", "--contact", default="admin.example.com.")
    opts.add_option("-k", "--update-key", default=os.getenv('DNS_UPDATE_KEY'))

    opts.add_option("-n", "--network", default=None) # dns-network
    opts.add_option("-m", "--master", default="ns-master")
    opts.add_option("-s", "--slave-prefix", default="ns")

    opts.add_option("-f", "--forwarder", type="string", action="append", dest="forwarders", default=[])

    opts.add_option("-t", "--template", type="string", default="inventory.j2")
    
    return opts.parse_args()

def floating_ip(server, network=None):
    if network == None:
        network = server.addresses.keys()[0]
    entry = None
    for interface in server.addresses[network]:
        if interface['OS-EXT-IPS:type'] == 'floating':
            entry = {"name": server.name, "address": interface['addr']}
    return entry

def resolv_conf_nameservers():
    ns_re = re.compile("^nameserver *(.*)$")
    f = open('/etc/resolv.conf')
    return [ns_re.match(l).groups()[0] for l in f.readlines() if ns_re.match(l)]

if __name__ == "__main__":

    (opts, args) = parse_cli()

    struct = dict()

    # INPUTS
    struct['zone'] = opts.zone
    struct['contact'] = opts.contact
    struct['update_key'] = opts.update_key
    if len(opts.forwarders) > 0:
        struct['forwarders'] = opts.forwarders
    else:
        struct['forwarders'] = resolv_conf_nameservers()

    zone_re = re.compile("\.%s$" % opts.zone)
    master_re = re.compile("^(%s)\.%s" % (opts.master, opts.zone))
    slave_re = re.compile("^(%s)[0-9]\.%s" % (opts.slave_prefix, opts.zone))
    
    nova = client.Client("2.0",
                         opts.username,
                         opts.password,
                         opts.project,
                         opts.auth_url)

    # get a list of the server/floating IP pairs in the project
    servers = [floating_ip(server, opts.network)
               for server in nova.servers.list()]

    # TODO: these need better filters
    # Filter the nameserver master host(s) from the complete list
    struct['masters'] = [h for h in servers if h and master_re.match(h['name'])]
    # Then match them with their address and create a hash object for each one
    struct['masters'] = [
        {
            'name': zone_re.sub('', s['name']),
            'address': s['address']
        }
        for s in struct['masters']
    ]

    # Filter the slave servers from the list (not masters) 
    struct['slaves'] = [h for h in servers if h and slave_re.match(h['name'])]
    # Then create a simple object with name and IP address
    struct['slaves'] = [
        {
            'name': zone_re.sub('', s['name']),
            'address': s['address']
        } for s in struct['slaves']
    ]

    template = Environment(loader=FileSystemLoader(os.getcwd())).get_template(opts.template)
    print template.render(struct)

#!/usr/bin/env python
#
# given:
#   osp_credentials:
#     - username
#     - password
#     - project_name
#     - auth_url
#   network_name
#   
# 
#

import os,sys,re
from optparse import OptionParser

from novaclient import client

# python2-dns
import dns.query
import dns.tsigkeyring
import dns.update

                       
def parse_cli():
    opts = OptionParser()
    opts.add_option("-u", "--username", default=os.environ['OS_USERNAME'])
    opts.add_option("-p", "--password", default=os.environ['OS_PASSWORD'])
    opts.add_option("-P", "--project", default=os.environ['OS_TENANT_NAME'])
    opts.add_option("-U", "--auth-url", default=os.environ['OS_AUTH_URL'])
    opts.add_option("-n", "--network", default="dns-network")
    opts.add_option("-z", "--zone", default="example.com")
    opts.add_option("-m", "--master", default="ns-master")
    opts.add_option("-s", "--slave-prefix", default="ns")
    opts.add_option("-k", "--update-key", default=os.getenv('UPDATE_KEY'))

    return opts.parse_args()

def floating_ip(server, network):
    entry = None
    for interface in server.addresses[network]:
        if interface['OS-EXT-IPS:type'] == 'floating':
            entry = {"name": server.name, "address": interface['addr']}
    return entry

def add_a_record(name,zone,ipv4addr,master,key):
    keyring = dns.tsigkeyring.from_text({'update-key': key})
    update = dns.update.Update(zone, keyring=keyring)
    update.replace(name, 300, 'a', ipv4addr)
    response = dns.query.tcp(update, master)
    return response

def add_ns_record(zone,master,key):
    keyring = dns.tsigkeyring.from_text({'update-key': key})
    update = dns.update.Update(zone, keyring=keyring)
    update.replace(zone, 300, 'ns', fqdn)
    response = dns.query.tcp(update, master)
    return response

def host_part(fqdn,zone):
    zone_re = re.compile("(.*).(%s)$" % zone)
    response = zone_re.match(fqdn)
    return response.groups()[0]
    
if __name__ == "__main__":

    (opts, args) = parse_cli()

    master_re = re.compile("^(%s)\." % opts.master)
    
    nova = client.Client("2.0",
                         opts.username,
                         opts.password,
                         opts.project,
                         opts.auth_url)

    pairs = [floating_ip(server, opts.network) for server in nova.servers.list()]
    print pairs
    
    master_addr = [host['address'] for host in pairs if host_part(host['name'], opts.zone) == opts.master]

    print master_addr[0]
    
    #set_a_record(pairs
    #print pairs
    for record in pairs:
        add_a_record(
            host_part(record['name'], opts.zone),
            opts.zone,
            record['address'],
            master_addr[0],
            opts.update_key
        )
#        add_ns_record(
#           host_part(record['name'], opts.zone), 
#           opts.zone,
#            master_addr[0],
#            opts.update_key
#        )
                
    

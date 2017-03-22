#!/usr/bin/env python

import os,sys
from argparse import ArgumentParser

# python2-dns
import dns.query
import dns.tsigkeyring
import dns.update
import dns.rcode

import json

def add_a_record(server, zone, key, name, address, ttl=300):

    # make input zones absolute
    #zone = zone + '.' if not zone.endswith('.')
    keyring = dns.tsigkeyring.from_text({'update-key': key})
    update = dns.update.Update(zone, keyring=keyring)
    update.replace(name, ttl, 'a', address)
    response = dns.query.tcp(update, server)
    return response

if __name__ == "__main__":
    
    def process_arguments():
        parser = ArgumentParser()
        parser.add_argument("-s", "--server", type=str, default="127.0.0.1")
        parser.add_argument("-k", "--key", type=str, default=os.getenv("DNS_UPDATE_KEY"))
        parser.add_argument("zone_spec")
        
        return parser.parse_args()

    opts = process_arguments()

    zone_spec = json.load(open(opts.zone_spec))

    for host in zone_spec['hosts']['public']:
        response = add_a_record(opts.server, zone_spec['zone'], opts.key,
                                host['name'], host['address'])
        if response.rcode() != dns.rcode.NOERROR:
            print "ERROR  %s: %s" % (
                dns.rcode.to_text(response.rcode()),
                "%s.%s %s" % (host['name'], zone_spec['zone'], host['address']))
        #print response.rcode()
        
    for host in zone_spec['hosts']['private']:
        response = add_a_record(opts.server, zone_spec['zone'], opts.key,
                                host['name'], host['address'])
        if response.rcode() != dns.rcode.NOERROR:
            print "ERROR  %s: %s" % (
                dns.rcode.to_text(response.rcode()),
                "%s.%s %s" % (host['name'], zone_spec['zone'], host['address']))


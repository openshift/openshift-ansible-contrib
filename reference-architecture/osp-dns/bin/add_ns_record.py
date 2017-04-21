#!/usr/bin/env python
#
# Add an A record to a DNS server via RFC 2136 dynamic update
#

import os
from argparse import ArgumentParser

# python2-dns
import dns.query
import dns.tsigkeyring
import dns.update
import dns.rdata


def add_ns_record(server, zone, key, nameserver, ttl=300):

    # make input zones absolute
    #zone = zone + '.' if not zone.endswith('.')

    keyring = dns.tsigkeyring.from_text({'update-key': key})
    update = dns.update.Update(zone, keyring=keyring)
    update.add(zone, ttl, 'ns', nameserver)
    response = dns.query.tcp(update, server)
    return response
    
    
if __name__ == "__main__":

    def process_arguments():
        parser = ArgumentParser()
        parser.add_argument("-s", "--server", type=str, default="127.0.0.1")
        parser.add_argument("-z", "--zone", type=str, default="example.com")
        parser.add_argument("-k", "--key", type=str, default=os.getenv("DNS_KEY"))
        parser.add_argument("nameserver", type=str)
        parser.add_argument("-t", "--ttl", type=str, default=300)
        return parser.parse_args()

    opts = process_arguments()
    response = add_ns_record(opts.server, opts.zone, opts.key, opts.nameserver, opts.ttl)

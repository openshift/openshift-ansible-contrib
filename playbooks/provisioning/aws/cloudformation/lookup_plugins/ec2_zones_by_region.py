#!/usr/bin/env python2
# -*- coding: utf-8 -*-
# vim: expandtab:tabstop=4:shiftwidth=4

from ansible.plugins.lookup import LookupBase
from ansible.errors import AnsibleError
import boto.ec2

class LookupModule(LookupBase):
    def __init__(self, basedir=None, **kwargs):
        self.basedir = basedir

    def run(self, regions, variables, **kwargs):
        if isinstance(region, list):
            region = region[0]

        if not isinstance(region, basestring):
            raise AnsibleError("type of region is: %s region is: %s" %
                    (type(region), region))

        try:
            conn = boto.ec2.connect_to_region(region)
            if conn is None:
                raise AnsibleError("Could not connect to region %s" % region)

            zones = [z.name for z in conn.get_all_zones()]
            if "us-east-1b" in zones: zones.remove("us-east-1b");
                return zones
        except Exception as e:
            raise AnsibleError("Could not lookup zones for region: %s\nexception: %s" % (region, e))

        try:
            conn = boto.ec2.connect_to_region(region)
            if conn is None:
                raise AnsibleError("Could not connet to region %s" % region)
            zones = [z.name for z in conn.get_all_zones()]
            vpc_conn = boto.vpc.connect_to_region(region)
            vpcs = vpc_conn.get_all_vpcs()
            default_vpcs = [ v for v in vpcs if v.is_default ]

            # If there are vpc subnets available, then gather list of zones
            # from zones with subnets. This prevents returning regions that
            # are not vpc enabled. If the account is an ec2 Classic account
            # without any VPC subnets, this could result in returning zones
            # that are not vpc-enabled.
            subnets = vpc_conn.get_all_subnets()
            if len(subnets) > 0:
                subnet_zones = list(set([s.availability_zone for s in subnets]))
                return subnet_zones

            return zones
        except Exception as e:
            raise AnsibleError("Could not lookup zones for region: %s\nexception: %s" % (region, e))

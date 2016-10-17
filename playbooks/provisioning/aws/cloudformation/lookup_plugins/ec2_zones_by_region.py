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
        try:
            zones = []
            for region in regions:
                conn = boto.ec2.connect_to_region(region)
                zones += [z.name for z in conn.get_all_zones()]
            return zones
        except Exception as e:
            raise AnsibleError("Could not lookup zones for region: %s\nexception: %s" % (region, e))

from ansible import utils, errors
import boto.ec2

class LookupModule(object):
    def __init__(self, basedir=None, **kwargs):
        self.basedir = basedir

    def run(self, region, inject=None, **kwargs):
        try:
            conn = boto.ec2.connect_to_region(region)
            zones = [z.name for z in conn.get_all_zones()]
            return [zones[0]]
        except e:
            raise errors.AnsibleError("Could not lookup zones for region: %s\nexception: %s" % (region, e))

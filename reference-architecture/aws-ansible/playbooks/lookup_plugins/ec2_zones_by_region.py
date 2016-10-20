from ansible import utils, errors
import boto.ec2
import boto.vpc

# pylint: disable=no-name-in-module,import-error,unused-argument,unused-variable,super-init-not-called,too-few-public-methods,missing-docstring
try:
    # ansible-2.0
    from ansible.plugins.lookup import LookupBase
except ImportError:
    # ansible-1.9.x
    class LookupBase(object):
        def __init__(self, basedir=None, runner=None, **kwargs):
            self.runner = runner
            self.basedir = self.runner.basedir
            def get_basedir(self, variables):
                return self.basedir


class LookupModule(LookupBase):
    def __init__(self, basedir=None, **kwargs):
        self.basedir = basedir

    def run(self, region, inject=None, **kwargs):
        if isinstance(region, list):
            region = region[0]

        if not isinstance(region, basestring):
            raise errors.AnsibleError("type of region is: %s region is: %s" %
                    (type(region), region))

        try:
            conn = boto.ec2.connect_to_region(region)
            if conn is None:
                raise errors.AnsibleError("Could not connet to region %s" % region)
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
            raise errors.AnsibleError("Could not lookup zones for region: %s\nexception: %s" % (region, e))

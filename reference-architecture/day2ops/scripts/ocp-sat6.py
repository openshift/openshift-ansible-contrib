#!/usr/bin/env python
# vim: sw=4 ts=4 et
import os, argparse, socket, getpass, subprocess

class ocpSat6(object):

    __name__ = 'ocpSat6'

    openshift3Images=[]

    def __init__(self, load=True):

        if load:
            self._parseCli()
            self._loadImageList()
            self._addData()
            self._syncData()

    def _loadImageList(self):
        # from https://access.redhat.com/solutions/3435901
        containerlist=[
            "openshift3/ose-ansible",
            "openshift3/ose-web-console",
            "openshift3/ose-cluster-capacity",
            "openshift3/ose-deployer",
            "openshift3/ose-docker-builder",
            "openshift3/oauth-proxy",
            "openshift3/ose-docker-registry",
            "openshift3/ose-egress-http-proxy",
            "openshift3/ose-egress-router",
            "openshift3/ose-f5-router",
            "openshift3/ose-haproxy-router",
            "openshift3/ose-keepalived-ipfailover",
            "openshift3/ose-pod",
            "openshift3/ose-sti-builder",
            "openshift3/ose",
            "openshift3/container-engine",
            "openshift3/node",
            "openshift3/openvswitch",
            "rhel7/etcd",
            "openshift3/ose-recycler",
            "openshift3/logging-auth-proxy",
            "openshift3/logging-curator",
            "openshift3/logging-elasticsearch",
            "openshift3/logging-fluentd",
            "openshift3/logging-kibana",
            "openshift3/metrics-cassandra",
            "openshift3/metrics-hawkular-metrics",
            "openshift3/metrics-hawkular-openshift-agent",
            "openshift3/metrics-heapster",
            "openshift3/prometheus",
            "openshift3/prometheus-alert-buffer",
            "openshift3/prometheus-alertmanager",
            "openshift3/prometheus-node-exporter",
            "cloudforms46/cfme-openshift-postgresql",
            "cloudforms46/cfme-openshift-memcached",
            "cloudforms46/cfme-openshift-app-ui",
            "cloudforms46/cfme-openshift-app",
            "cloudforms46/cfme-openshift-embedded-ansible",
            "cloudforms46/cfme-openshift-httpd",
            "cloudforms46/cfme-httpd-configmap-generator",
            "rhgs3/rhgs-server-rhel7",
            "rhgs3/rhgs-volmanager-rhel7",
            "rhgs3/rhgs-gluster-block-prov-rhel7",
            "rhgs3/rhgs-s3-server-rhel7",
            "openshift3/ose-service-catalog",
            "openshift3/ose-ansible-service-broker",
            "openshift3/mediawiki-apb",
            "openshift3/postgresql-apb",
        ]
        self.openshift3Images.append(containerlist)

    def _parseCli(self):

        parser = argparse.ArgumentParser(description='Add all OCP images for disconnected installation to satellite 6', add_help=True)
        parser.add_argument('--orgid', action='store', default='1',help='Satellite organization ID to create new product for OCP images in')
        parser.add_argument('--productname', action='store', default='ocp36',help='Satellite product name to use to create OCP images')
        parser.add_argument('--username', action='store', default='admin', help='Satellite 6 username for hammer CLI')
        parser.add_argument('--password', action='store', help='Satellite 6 Password for hammer CLI')
        parser.add_argument('--no_confirm', action='store_true', help='Do not ask for confirmation')
        self.args = parser.parse_args()

        if not self.args.password:
            self.args.password = getpass.getpass(prompt='Please enter the password to use for the admin account in hammer CLI: ')

    def _syncData(self):

        if not self.args.no_confirm:
            print "Sync repo data? (This may take a while)"
            go = raw_input("Continue? y/n:\n")
            if 'y' not in go:
                exit(0)

        cmd="hammer --username %s --password %s product synchronize --name %s --organization-id %s" % (self.args.username, self.args.password, self.args.productname, self.args.orgid)
        os.system(cmd)

    def _addData(self):

        if not self.args.no_confirm:
            print "Adding OCP images to org ID: %s with the product name: %s" % (self.args.orgid, self.args.productname)
            go = raw_input("Continue? y/n:\n")
            if 'y' not in go:
                exit(0)

        print "Adding product with name: %s" % self.args.productname

        cmd="hammer --username %s --password %s product create --name %s --organization-id %s" % (self.args.username, self.args.password, self.args.productname, self.args.orgid)
        os.system(cmd)

        print "Adding openshift3 images"
        for image in self.openshift3Images:
            cmd='hammer --username %s --password %s repository create --name %s --organization-id %s --content-type docker --url "https://registry.access.redhat.com" --docker-upstream-name %s --product %s' % (self.args.username,  self.args.password, image, self.args.orgid, image, self.args.productname )
            os.system(cmd)

        print "The following vars should exist in your OpenShift install playbook"
        cmd="hammer --username %s --password %s organization list" % (self.args.username, self.args.password)
        result = subprocess.check_output(cmd, shell=True)
        lines = result.splitlines()
        for line in lines:
            if self.args.orgid in line:
                orgLabel = line.split("|")[2].lower()
                hostname = socket.getfqdn()
                oreg_url = "%s-%s-openshift3_ose-${component}:${version}" % ( orgLabel, self.args.productname )
                print "oreg_url: %s" % ( oreg_url.replace(" ", ""))
        print 'openshift_disable_check: "docker_image_availability"'
        print 'openshift_docker_insecure_registries: "%s:5000"' % hostname
        print 'openshift_docker_additional_registries: "%s:5000"' % hostname
        print "openshift_examples_modify_imagestreams: True"

if __name__ == '__main__':
    ocpSat6()

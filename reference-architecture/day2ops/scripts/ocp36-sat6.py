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
        cmd='curl -s https://registry.access.redhat.com/v1/search?q="openshift3" | python -mjson.tool | grep ".name.:" | cut -d: -f2 | sed -e "s/ "//g"" -e "s/,"//g""'
        result = subprocess.check_output(cmd, shell=True)
        lines = result.splitlines()
        for line in lines:
            nl = line.replace('"', '')
            self.openshift3Images.append(nl)

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
                oreg_url = "%s:5000/%s-%s-openshift3_ose-${component}:${version}" % ( hostname, orgLabel, self.args.productname )
                print "oreg_url: %s" % ( oreg_url.replace(" ", ""))
        print 'openshift_disable_check: "docker_image_availability"'
        print 'openshift_docker_insecure_registries: "%s:5000"' % hostname
        print 'openshift_docker_additional_registries: "%s:5000"' % hostname
        print "openshift_examples_modify_imagestreams: True"

if __name__ == '__main__':
    ocpSat6()

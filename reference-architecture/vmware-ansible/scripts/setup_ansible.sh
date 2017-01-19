#! /bin/bash
#

subscription-manager repos --enable rhel-7-server-rpms
subscription-manager repos --enable rhel-7-server-ose-3.3-rpms
subscription-manager repos --enable rhel-7-server-optional-rpms
subscription-manager repos --enable rhel-7-server-extras-rpms
subscription-manager repos --enable rhel-7-server-satellite-tools-6.2-rpms

rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

yum -y install atomic-openshift-utils \
                 git \
                 pyOpenSSL \
                 PyYAML \
                 python-click \
                 python-httplib2
                 python-iptools \
                 python-ldap \
                 python-netaddr \
                 python-simplejson \
                 python-six \

git clone https://github.com/vmware/pyvmomi && cd pyvmomi/ && python setup.py install

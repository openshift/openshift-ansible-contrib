FROM registry.access.redhat.com/rhel7

MAINTAINER Davis Phillips <dphillip@redhat.com>


RUN yum -y --disablerepo=\* --enablerepo=rhel-7-server-rpms install yum-utils && \
  yum-config-manager --disable \* && \
  yum-config-manager --enable rhel-7-server-rpms && \
  yum-config-manager --enable rhel-7-server-extras-rpms  && \
  yum-config-manager --enable rhel-7-server-ose-3.2-rpms && \
  yum-config-manager --enable rhel-7-server-satellite-tools-6.2-rpms && \
  yum-config-manager --enable rhel-7-server-optional-rpms && \
  yum clean all


RUN yum install -y  atomic-openshift-utils git python-netaddr python-pip pyOpenSSL openshift-ansible-playbooks net-tools && \
    yum clean all


RUN rm /etc/ansible/hosts 
RUN git clone https://github.com/dannvix/pySphere && cd pySphere/ && python setup.py install 
RUN git clone https://github.com/vmware/pyvmomi && cd pyvmomi/ && python setup.py install 
 
VOLUME [ "/etc/ansible/hosts", "/opt/ansible" ]

# Add in patched version of vsphere_guest.py
# Awaiting PR merge
COPY vsphere_guest.py /usr/lib/python2.7/site-packages/ansible/modules/core/cloud/vmware/
#COPY vi_virtual_machine.py /usr/lib/python2.7/site-packages/pysphere/
WORKDIR "/opt/ansible"

ENTRYPOINT [ "ansible-playbook" ]

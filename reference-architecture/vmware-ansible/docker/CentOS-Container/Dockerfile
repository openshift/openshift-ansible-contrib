FROM centos:7

MAINTAINER Davis Phillips <dphillip@redhat.com>

# install all that is required to use http://docs.ansible.com/ansible/vsphere_guest_module.html
RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum update-minimal -y --security --sec-severity=Important --sec-severity=Critical --setopt=tsflags=nodocs && \
    yum install -y --setopt=tsflags=nodocs ansible python-pip  atomic-openshift-utils pyOpenSSL && \
    yum install -y --setopt=tsflags=nodocs git && \
    yum clean all


RUN pip install --upgrade pip && \
    pip install pysphere && \
    pip install psphere && \
    pip install pyVmomi && \ 
    pip install  pyVim 

RUN rm /etc/ansible/hosts && \
    git clone https://github.com/openshift/openshift-ansible /opt/openshift-ansible


RUN git clone https://github.com/dannvix/pySphere && cd pySphere/ && python setup.py install 
RUN git clone https://github.com/vmware/pyvmomi && cd pyvmomi/ && python setup.py install 
 
VOLUME [ "/etc/ansible/hosts", "/opt/ansible" ]

RUN git clone https://github.com/openshift/openshift-ansible && mkdir -p /usr/share/ansible/ && ln -s /usr/share/ansible/openshift-ansible openshift-ansible
# Add in patched version of vsphere_guest.py
# Awaiting PR merge

COPY vsphere_guest.py /usr/lib/python2.7/site-packages/ansible/modules/core/cloud/vmware/
WORKDIR "/opt/ansible"

ENTRYPOINT [ "ansible-playbook" ]

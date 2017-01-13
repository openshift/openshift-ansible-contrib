FROM centos:7
COPY epel.repo /etc/yum.repos.d/epel.repo
COPY RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
RUN yum -y install git ansible pyOpenSSL && yum clean all
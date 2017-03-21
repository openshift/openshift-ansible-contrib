FROM centos/systemd:latest

RUN yum makecache fast && yum update -y && \
    yum install -y python sudo yum-plugin-ovl && \
    sed -i 's/plugins=0/plugins=1/g' /etc/yum.conf && \
    yum install -y epel-release && \
    yum install -y python python-pip python-flask git && \
    pip install git+https://github.com/detiber/moto@vpc_tenancy

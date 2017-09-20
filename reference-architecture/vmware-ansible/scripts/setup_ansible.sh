#! /bin/bash
#
echo "Subscribing and enabling the repos we need for deployment"
subscription-manager attach --pool=`subscription-manager list --available --pool-only --matches="Red Hat OpenShift Container Platform, Premium*" | tail -n1`
subscription-manager repos --enable=rhel-7-fast-datapath-rpms
subscription-manager repos --enable=rhel-server-rhscl-7-rpms
subscription-manager repos --enable=rhel-7-server-ose-3.6-rpms
subscription-manager repos --enable=rhel-7-server-rpms
subscription-manager repos --enable=rhel-7-server-extras-rpms


echo "Enabling the python27 SCL and use it for most of our packaging needs"
yum install -y python27 

echo "Installing the base packages that are needed for deployment minus the ones that are only on EPEL"
yum install -y git atomic-openshift-utils python-click python-ldap ansible-2.3

echo "Installing the EPEL repo and then EPEL packages needed"
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y python-iptools python2-pyvmomi

echo "Creating a ~/git directory and cloning the vmw-3.6 branch into it"
mkdir ~/git/; cd ~/git/
git clone -b vmw-3.6 https://github.com/openshift/openshift-ansible-contrib

echo "Please fill in your variables ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.ini"
echo "Create the initial inventory with the following command ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.py --create_inventory"
echo "Create the OCP install vars with the following command ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.py --create_ocp_vars"
echo "Lastly, run ~/git/openshift-ansible-contrib/reference-architecture/vmware-ansible/ocp-on-vmware.py to complete and test the OCP install"

#!/bin/sh
#
# Ensure that Python is installed for Ansible
#
echo "Installing Python, DNF and Selinux packages for Ansible"
[ -f /etc/fedora-release ] && dnf install -y python python-dnf libselinux-python

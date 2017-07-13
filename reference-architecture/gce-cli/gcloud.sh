#!/bin/bash

# MIT License
#
# Copyright (c) 2016 Peter Schiffer <pschiffe@redhat.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#
# Helper script to deploy infrastructure and OpenShift Cloud Platform on GCP.
#

set -euo pipefail

# Directory of this script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configure python path
PYTHONPATH="${PYTHONPATH:-}:${DIR}/ansible/inventory/gce/hosts"
export PYTHONPATH

# Run given playbook (1. param). All other parameters
# are passed directly to Ansible.
function run_playbook {
  playbook="$1"
  shift
  pushd "${DIR}/ansible"
  ansible-playbook -e @playbooks/openshift-installer-common-vars.yaml -e @../config.yaml $@ "$playbook"
  popd
}

# Teardown infrastructure
function teardown {
  run_playbook playbooks/teardown.yaml "$@"
}

# Create static inventory file
function static_inventory {
  run_playbook playbooks/create-inventory-file.yaml "$@"
}

# Main function which creates infrastructure and deploys OCP
function main {
  run_playbook playbooks/prereq.yaml -i inventory/inventory "$@"
  run_playbook playbooks/main.yaml "$@"
}

case ${1:-} in
  --teardown | --revert )
    shift
    teardown "$@"
    exit 0
    ;;
  --static-inventory )
    shift
    static_inventory "$@"
    exit 0
    ;;
  * )
    main "$@"
    exit 0
    ;;
esac

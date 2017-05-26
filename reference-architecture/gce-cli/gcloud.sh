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

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configure python path
PYTHONPATH="${PYTHONPATH:-}:${DIR}/ansible/inventory/gce/hosts"
export PYTHONPATH

function teardown {
  pushd "${DIR}/ansible"
  ansible-playbook -e @../config.yaml $@ playbooks/teardown.yaml
  popd
}

function main {
  pushd "${DIR}/ansible"
  ansible-playbook -i inventory/inventory -e @../config.yaml $@ playbooks/prereq.yaml
  ansible-playbook -e @../config.yaml $@ playbooks/main.yaml
  popd
}

while [ "$1" != "" ]; do
  case $1 in
    --teardown | --revert )
      shift
      teardown "$@"
      exit 0
      ;;
    * )
      main "$@"
      exit 0
      ;;
  esac
done

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

# Our config file
CONFIG_FILE='../config.yaml'

# Don't ask for confirmation
QUIET=0

# Configure python path
PYTHONPATH="${PYTHONPATH:-}:${DIR}/ansible/inventory/gce/hosts"
export PYTHONPATH

# Assign log file for ansible
ANSIBLE_LOG_PATH="${DIR}/ansible-$(date +%F_%T).log"
export ANSIBLE_LOG_PATH

function display_help {
  echo "./$(basename "$0") [ -c | --config FILE ] [ -q | --quiet ] [ -h | --help | --teardown | --soft-teardown | --redeploy | --soft-redeploy | --static-inventory | --validation | --minor-upgrade | --scaleup | --prereq | --gold-image | --infra | --clear-logs ] [ OPTIONAL ANSIBLE OPTIONS ]

Helper script to deploy infrastructure and OpenShift on Google Cloud Platform

Where:
  -c | --config FILE  Provide custom config file, must be relative
                      to the 'ansible' directory. Default is '../config.yaml'
  -q | --quiet        Don't ask for confirmations
  -h | --help         Display this help text
  --teardown          Teardown the OpenShift and the infrastructure.
                      Warning: you will loose all your data
  --soft-teardown     Soft-Teardown the OpenShift and the infrastructure.
                      Not all resources will be removed, just enough to do clean
                      redeployment. Saves some time.
                      Warning: you will loose all your data
  --redeploy          Teardown the OpenShift and the infrastructure and deploy
                      it again. Warning: you will loose all your data
  --soft-redeploy     Soft-Teardown the OpenShift and the infrastructure
                      and deploy it again. Not all resources will be removed,
                      just enough to do clean redeployment. Saves some time.
                      Warning: you will loose all your data
  --static-inventory  Generate static Ansible inventory file for existing infra.
                      It will be saved as 'ansible/static-inventory'
  --validation        Run validation playbook
  --minor-upgrade     Upgrade OpenShift to next minor release
  --scaleup           Scale up your OpenShift deployment. Update your
                      'config.yaml' file to set the desired number of nodes.
                      Supports scaling up of nodes as well as masters.
                      Doesn't support scaling down
  --prereq            Run only prerequisite playbook. Sets up Ansible connection
                      to the GCP, DNS zone, runs validation tests, etc.
  --gold-image        Run prerequisite playbook and create gold image in GCP
  --infra             Create complete infrastructure without deploying OpenShift
  --clear-logs        Delete all Ansible logs created by this script

If no action option is specified, the script will create the infrastructure
and deploy OpenShift on top of it.

OPTIONAL ANSIBLE OPTIONS  All other options following the options mentioned
                          above will be passed directly to the Ansible. For
                          example, you can override any Ansible variable with:
                          ./$(basename "$0") -e openshift_debug_level=4"
}

# Ask user for confirmation. First parameter is message
function ask_for_confirmation {
  if [ $QUIET -eq 1 ]; then
    return 0
  fi
  read -p "${1} [y/N] " yn
  case $yn in
    [Yy]* )
      return 0
      ;;
    * )
      exit 1
      ;;
  esac
}

# Run given playbook (1. param). All other parameters
# are passed directly to Ansible.
function run_playbook {
  playbook="$1"
  shift
  pushd "${DIR}/ansible"
  ansible-playbook -e '@playbooks/openshift-installer-common-vars.yaml' -e "@${CONFIG_FILE}" $@ "$playbook"
  popd
}

# Run prerequisite playbook
function prereq {
  run_playbook playbooks/prereq.yaml -i inventory/inventory "$@"
}

# Create only gold image
function gold_image {
  prereq "$@"
  run_playbook playbooks/gold-image.yaml "$@"
}

# Create only infrastructure, without deploying OpenShift
function infra {
  gold_image "$@"
  run_playbook playbooks/core-infra.yaml "$@"
}

# Scale up infrastructure and OCP
function scaleup {
  run_playbook playbooks/openshift-scaleup.yaml "$@"
}

# Teardown infrastructure
function teardown {
  ask_for_confirmation 'Are you sure you want to destroy OpenShift and the infrastructure? You will loose all your data.'
  run_playbook playbooks/teardown.yaml "$@"
}

# Soft-Teardown infrastructure
function soft_teardown {
  ask_for_confirmation 'Are you sure you want to destroy OpenShift and the infrastructure? You will loose all your data.'
  run_playbook playbooks/soft-teardown.yaml "$@"
}

# Create static inventory file
function static_inventory {
  run_playbook playbooks/create-inventory-file.yaml "$@"
}

# Run validation playbook
function validation {
  run_playbook playbooks/validation.yaml "$@"
}

# Run minor upgrade playbook
function minor_upgrade {
  run_playbook playbooks/openshift-minor-upgrade.yaml "$@"
}

# Main function which creates infrastructure and deploys OCP
function main {
  prereq "$@"
  run_playbook playbooks/main.yaml "$@"
}

while true; do
  case ${1:-} in
    -c | --config )
      shift
      CONFIG_FILE="${1}"
      shift
      ;;
    -q | --quiet )
      QUIET=1
      shift
      ;;
    -h | --help )
      display_help
      exit 0
      ;;
    --prereq )
      shift
      prereq "$@"
      exit 0
      ;;
    --gold-image )
      shift
      gold_image "$@"
      exit 0
      ;;
    --infra )
      shift
      infra "$@"
      exit 0
      ;;
    --scaleup )
      shift
      scaleup "$@"
      exit 0
      ;;
    --teardown )
      shift
      teardown "$@"
      exit 0
      ;;
    --soft-teardown )
      shift
      soft_teardown "$@"
      exit 0
      ;;
    --redeploy )
      shift
      teardown "$@"
      main "$@"
      exit 0
      ;;
    --soft-redeploy )
      shift
      soft_teardown "$@"
      main "$@"
      exit 0
      ;;
    --static-inventory )
      shift
      static_inventory "$@"
      exit 0
      ;;
    --validation )
      shift
      validation "$@"
      exit 0
      ;;
    --minor-upgrade )
      shift
      minor_upgrade "$@"
      exit 0
      ;;
    --clear-logs )
      rm -f "${DIR}"/ansible-*.log
      exit 0
      ;;
    * )
      main "$@"
      exit 0
      ;;
  esac
done

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
# Script to create base image for OpenShift Cloud Platform installation on GCE.
#

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CONFIG_SCRIPT:-${DIR}/config.sh}"

if [[ -z "${STARTUP_BUCKET:-}" || -z "${STARTUP_SCRIPT_FILE:-}" || -z "${STARTUP_INSTANCE_DATA_PATH:-}" ]]; then
  echo "STARTUP_BUCKET and either STARTUP_SCRIPT_FILE or STARTUP_INSTANCE_DATA_PATH must be specified to create instance data"
  exit 0
fi
if [[ -n "${STARTUP_INSTANCE_DATA_PATH:-}" ]]; then
  if [[ ! -d "${STARTUP_INSTANCE_DATA_PATH}" ]]; then
    echo "No instance-data directory"
    exit 1
  fi
fi

GCLOUD_REGION=${GCLOUD_ZONE%-*}

function revert {
    if gsutil ls -p "$GCLOUD_PROJECT" "gs://${STARTUP_BUCKET}" &>/dev/null; then
        gsutil -m rm -r "gs://${STARTUP_BUCKET}"
    fi
}

# Support the revert option
if [ "${1:-}" = '--revert' ]; then
    revert
    exit 0
fi

if ! gsutil ls -p "$GCLOUD_PROJECT" "gs://${STARTUP_BUCKET}" &>/dev/null; then
    gsutil mb -p "$GCLOUD_PROJECT" -l "$GCLOUD_REGION" "gs://${STARTUP_BUCKET}"
    gsutil defacl set public-read "gs://${STARTUP_BUCKET}/"
else
    echo "Bucket '${STARTUP_BUCKET}' already exists"
fi

if [[ -n "${STARTUP_INSTANCE_DATA_PATH}" ]]; then
  if [[ ! -f "${STARTUP_SCRIPT_FILE}" ]]; then
    mkdir -p $( dirname "${STARTUP_SCRIPT_FILE}" )
    cat << EOF > "${STARTUP_SCRIPT_FILE}"
#!/bin/bash
set -euo pipefail

wget "http://storage.googleapis.com/${STARTUP_BUCKET}/instance-data.tar.gz" -o - | tar xzvf -
if [[ -f run.sh ]]; then
  run.sh
fi
EOF
  fi

  if ! gsutil ls -p "$GCLOUD_PROJECT" "gs://${STARTUP_BUCKET}/instance-data.tar.gz" &>/dev/null; then
    tar cvzf "${DIR}/working/instance-data.tar.gz" -C "${STARTUP_INSTANCE_DATA_PATH}" .
    gsutil cp "${DIR}/working/instance-data.tar.gz" "gs://${STARTUP_BUCKET}"
  fi
fi

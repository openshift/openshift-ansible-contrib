#!/bin/bash

set -euo pipefail

source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" == "true" ]; then
    echo RUN_OPENSTACK_CI is set to true, skipping the tox tests.
    exit
fi

tox

#!/bin/bash

# Don't run the end to end test when the openstack credentials are not set up.
# This happens on pull requests coming from forks.
if [ -z ${OS_AUTH_URL:-} ]; then
    RUN_OPENSTACK_CI=false
fi

if [ "${RUN_OPENSTACK_CI:-}" == true ]
then
    WHITELIST_REGEX='^(.travis.yml|ci|roles|playbooks\/provisioning)'

    if git --no-pager diff --name-only master | grep -qE "$WHITELIST_REGEX"; then
        RUN_OPENSTACK_CI=true
    else
        RUN_OPENSTACK_CI=false
    fi
fi


export RUN_OPENSTACK_CI

export KEYPAIR_NAME="travis-ci-$TRAVIS_BUILD_NUMBER"
export ENV_ID="openshift-$TRAVIS_BUILD_NUMBER"

# NOTE(shadower): don't freak out if the openstack command doesn't exist.
# That just means ci/openstack/install.sh didn't run yet.
if hash openstack &>/dev/null; then
    stack_count="$(openstack stack list -f value | grep -cv $ENV_ID.example.com || true)"
else
    stack_count=0
fi

if [ "$stack_count" -ge "${CI_CONCURRENT_JOBS:-1}" ]; then
    export CI_OVER_CAPACITY=true
else
    export CI_OVER_CAPACITY=false
fi


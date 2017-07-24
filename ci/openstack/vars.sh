#!/bin/bash

GIT_RANGE=HEAD...master

echo Modified files:
git diff --name-only $GIT_RANGE
echo ==========

if [ "${RUN_OPENSTACK_CI:-}" == true ]
then
    # TODO(shadower): Can we only run this when the project admin asked for it?

    WHITELIST_REGEX='^(.travis.yml|ci|roles|playbooks\/provisioning)'

    if git diff --name-only $GIT_RANGE | grep -qE "$WHITELIST_REGEX"; then
        RUN_OPENSTACK_CI=true
    else
        RUN_OPENSTACK_CI=false
    fi
fi

export RUN_OPENSTACK_CI

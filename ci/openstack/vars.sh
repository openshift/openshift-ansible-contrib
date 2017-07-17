#!/bin/bash

if [ "${RUN_OPENSTACK_CI:-}" == true ]
then
    # TODO(shadower): Can we only run this when the project admin asked for it?

    # TODO(shadower): check that the commit changed roles or playbooks/provisioning
    if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
        TRAVIS_COMMIT_RANGE="FETCH_HEAD...$TRAVIS_BRANCH"
    fi

    WHITELIST_REGEX='^(.travis.yml|ci|roles|playbooks\/provisioning)'

    if git diff --name-only $TRAVIS_COMMIT_RANGE | grep -qE "$WHITELIST_REGEX"; then
        RUN_OPENSTACK_CI=true
    else
        RUN_OPENSTACK_CI=false
    fi
fi

export RUN_OPENSTACK_CI

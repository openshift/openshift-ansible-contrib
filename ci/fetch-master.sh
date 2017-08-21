#!/bin/bash

git fetch origin master:master

echo Modified files:
git --no-pager diff --name-only master
echo ==========



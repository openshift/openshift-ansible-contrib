#!/usr/bin/bash

IMAGE_NAMES="hello-openshift openvswitch node origin-f5-router origin-sti-builder origin-docker-builder origin-recycler origin-gitserver origin-federation origin-egress-router origin-docker-registry origin-keepalived-ipfailover origin-haproxy-router origin origin-pod origin-base origin-source origin-deployer"


for image in $IMAGE_NAMES; do
  docker tag openshift/${image}:latest detiber/${image}:latest
  docker push detiber/${image}:latest
done

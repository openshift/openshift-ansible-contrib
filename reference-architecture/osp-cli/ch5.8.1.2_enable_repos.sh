#!/bin/sh
OSP_VERSION=${OSP_VERSION:-10}
OCP3_VERSION=${OCP3_VERSION:-3.4}

sudo subscription-manager repos --disable="*"
sudo subscription-manager repos \
  --enable=rhel-7-server-rpms \
  --enable=rhel-7-server-extras-rpms \
  --enable=rhel-7-server-optional-rpms \
  --enable=rhel-7-server-ose-${OCP3_VERSION}-rpms \
  --enable=rhel-7-server-openstack-${OSP_VERSION}-rpms \
  --enable=rhel-7-fast-datapath-rpms

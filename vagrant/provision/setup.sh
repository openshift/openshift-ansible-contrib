#!/bin/bash

# Capture network variable:
NETWORK_BASE=$1
sudo -i

echo "Check eth1 ip config for netbase: $NETWORK_BASE"

if ip a show dev eth1 | grep -q "inet $NETWORK_BASE"; then
  echo "eth1 ip detected"
else
  echo "eth1 missing ip; restaring interface"
  ifdown eth1 && ifup eth1
fi

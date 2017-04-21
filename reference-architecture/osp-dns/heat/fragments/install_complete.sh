#!/usr/bin/sh
#
#
source /usr/local/lib/notify.sh
echo "Install Complete at" $(date)
notify_success "OpenShift node has been prepared for running ansible."

#!/bin/sh
# Set RHN_USERNAME, RHN_PASSWORD RHN_POOL_ID for your environment
sudo subscription-manager register \
  --username $RHN_USERNAME \
  --password $RHN_PASSWORD
sudo subscription-manager subscribe --pool $RHN_POOL_ID


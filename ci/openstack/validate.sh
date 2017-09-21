#!/bin/bash

set -euox pipefail


source ci/openstack/vars.sh
if [ "${RUN_OPENSTACK_CI:-}" != "true" ]; then
    echo RUN_OPENSTACK_CI is set to false, skipping the openstack end to end test.
    exit
fi

echo SET UP DNS
cp /etc/resolv.conf resolv.conf.orig
DNS_IP=$(openstack server show dns-0.$ENV_ID.example.com --format value --column addresses | awk '{print $2}')
grep -v '^nameserver' resolv.conf.orig > resolv.conf.openshift
echo nameserver "$DNS_IP" >> resolv.conf.openshift
sudo cp resolv.conf.openshift /etc/resolv.conf

function restore_dns {
    echo RESTORING DNS
    sudo cp resolv.conf.orig /etc/resolv.conf
}
trap restore_dns EXIT

mkdir -p bin
scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" openshift@master-0.$ENV_ID.example.com:/usr/bin/oc bin/
ls -alh bin

export PATH="$PWD/bin:$PATH"
ENV_ID="openshift-$TRAVIS_BUILD_NUMBER"

oc login --insecure-skip-tls-verify=true https://master-0.$ENV_ID.example.com:8443 -u test -p password
oc new-project test
oc new-app --template=cakephp-mysql-example

set +x

echo Waiting for the pods to come up

STATUS=timeout
for i in $(seq 600); do
    if [ "$(oc status -v | grep 'deployment.*deployed' | wc -l)" -eq 2 ]; then
        STATUS=success
        echo Both pods were deployed
        break
    elif [ "$(oc status -v | grep -i 'error\|fail' | wc -l)" -gt 0 ]; then
        STATUS=error
        echo ERROR: The deployment failed
        break
    else
        printf .
        sleep 15
    fi
done

if [ "$STATUS" = timeout ]; then
    echo ERROR: Timed out waiting for the pods
fi

echo 'Output of `oc status -v`:'
oc status -v

echo
echo 'Output of `oc logs bc/cakephp-mysql-example`:'
oc logs bc/cakephp-mysql-example

if [ "$STATUS" != success ]; then
    echo "ERROR: The deployment didn't succeed"
    exit 1
fi

set -o pipefail

curl "http://cakephp-mysql-example-test.apps.$ENV_ID.example.com" | grep 'Welcome to your CakePHP application on OpenShift'

echo "SUCCESS \o/"

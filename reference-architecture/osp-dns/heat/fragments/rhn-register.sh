#!/bin/bash
#
# Register with subscription manager and enable required RPM respositories
#
# ENVVARS:
#   RHN_USERNAME - a valid RHN username with access to OpenShift entitlements
#   RHN_PASSWORD - password for the RHN user
#   POOL_ID - OPTIONAL - a specific pool with OpenShift entitlements
#   SAT6_HOSTNAME - The hostname of the Sat6 server to register to
#   SAT6_ORGANIZAION - An Organization string to aid grouping of hosts
#   SAT6_ACTIVATIONKEY - A string used to authorize the registration
#
# Templates suitable for jinja substitution
RHN_USERNAME=${RHN_USERNAME:-'{{rhn_username}}'}
RHN_PASSWORD=${RHN_PASSWORD:-'{{rhn_password}}'}
RHN_POOL_ID=${RHN_POOL_ID:-'{{rhn_pool_id}}'}
SAT6_HOSTNAME=${SAT6_HOSTNAME:-'{{sat6_hostname}}'}
SAT6_ORGANIZATION=${SAT6_ORGANIZATION:-'{{sat6_hostname}}'}
SAT6_ACTIVATIONKEY=${SAT6_ACTIVATIONKEY:-'{{sat6_activationkey}}'}

# Exit on command fail
set -eu
set -x

# Return the final non-zero exit code of a failed pipe (or 0 for success)
set -o pipefail

echo "Start RHN register"

function retry() {
    for I in {1..5} ; do
        echo "try $I: $@"
        $@ && return || true
        echo "waiting 2 sec. to try again"
        sleep 2
    done
    echo "failed $I tries: $@"
    false
}

function use_satellite6() {
    [ -n "$SAT6_HOSTNAME" ]
}

function use_rhn() {
    [ -n "$RHN_USERNAME" -a -n "$RHN_PASSWORD" ]
}

function register_rhn() {
    # RHN_USERNAME=$1
    # RHN_PASSWORD=$2
    retry subscription-manager register --username="$1" --password="$2"
}

function install_sat6_ca_certs() {
    # SAT6_HOSTNAME=$1
    local SAT6_KEY_RPM="katello-ca-consumer-$1"
    local SAT6_KEY_RPM_URL="https://${1}/pub/katello-ca-consumer-latest.noarch.rpm"

    if ! rpm -q --quiet $SAT6_KEY_RPM ; then
        retry yum -y install $SAT6_KEY_RPM_URL
    fi
}

function register_sat6() {
    # SAT6_ORGANIZATION=$1
    # SAT6_ACTIVATIONKEY=$2
    # register as a sat6 client
    retry subscription-manager register --org="$1" --activationkey="$2"
}

# =============================================================================
# MAIN
# =============================================================================

if use_satellite6 ; then
    install_sat6_ca_certs $SAT6_HOSTNAME
    register_sat6 $SAT6_ORGANIZATION $SAT6_ACTIVATIONKEY
elif use_rhn ; then
    register_rhn $RHN_USERNAME $RHN_PASSWORD
else
    echo "No RHN credentials provided"
    exit 0
fi

# Attach to an entitlement pool
if [ -n "$RHN_POOL_ID" ]; then
    retry subscription-manager attach --pool $RHN_POOL_ID
else
    retry subscription-manager attach --auto
fi

# Select the YUM repositories to use
retry subscription-manager repos --disable="*"
retry subscription-manager repos \
                     --enable="rhel-7-server-rpms" \
                     --enable="rhel-7-server-extras-rpms" \
                     --enable="rhel-7-server-optional-rpms" \

# Allow RPM integrity checking
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

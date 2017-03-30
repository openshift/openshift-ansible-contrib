#!/bin/bash
#
# Create an OSv3.yml file with user values
#

OCP3_OSV3_TEMPLATE=${OCP3_OSV3_TEMPLATE:-OSv3.yml.template}
OCP3_OSV3_YML_FILE=${OCP3_OSV3_YAML_FILE:-OSv3.yml}

cp ${OCP3_OSV3_TEMPLATE} ${OCP3_OSV3_YML_FILE}

sed -i -e "/osm_default_subdomain:/s/:.*/: $APPS_DNS_SUFFIX/" ${OCP3_OSV3_YML_FILE}

sed -i -e "/openstack_auth_url:/s|:.*|: $OS_AUTH_URL|" ${OCP3_OSV3_YML_FILE}
sed -i -e "/openstack_username:/s/:.*/: $OS_USERNAME/" ${OCP3_OSV3_YML_FILE}
sed -i -e "/openstack_password:/s/:.*/: $OS_PASSWORD/" ${OCP3_OSV3_YML_FILE}
sed -i -e "/openstack_tenant_name:/s/:.*/: $OS_TENANT_NAME/" ${OCP3_OSV3_YML_FILE}
sed -i -e "/openstack_region:/s/:.*/: $OS_REGION_NAME/" ${OCP3_OSV3_YML_FILE}

sed -i -e "/cluster_hostname:/s/:.*/: $MASTER_DNS_NAME/" ${OCP3_OSV3_YML_FILE}
sed -i -e "/cluster_public_hostname:/s/:.*/: $MASTER_DNS_NAME/" ${OCP3_OSV3_YML_FILE}

sed -i -e "/bindDN:/s/:.*/: $LDAP_BIND_DN/"  ${OCP3_OSV3_YML_FILE}
sed -i -e "/bindPassword:/s/:.*/: $LDAP_BIND_PASSWORD/"  ${OCP3_OSV3_YML_FILE}
sed -i -e "/^ *url:/s|:.*|: $LDAP_URL|"  ${OCP3_OSV3_YML_FILE}

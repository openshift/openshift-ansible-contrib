#!/bin/bash
#
# Create an OSEv3.yml file with user values
#
OCP3_BASE_DOMAIN=${OCP3_BASE_DOMAIN:-ocp3.example.com}

OCP3_INVENTORY_TEMPLATE=${OCP3_INVENTORY_TEMPLATE:-inventory.template}
OCP3_INVENTORY_FILE=${OCP3_INVENTORY_FILE:-inventory}

OCP3_OSEV3_TEMPLATE=${OCP3_OSEV3_TEMPLATE:-OSEv3.yml.template}
OCP3_OSEV3_YML_FILE=${OCP3_OSEV3_YAML_FILE:-OSEv3.yml}

# Replace domain in inventory file
sed -e "s/ocp3.example.com/${OCP3_BASE_DOMAIN}/g" \
  ${OCP3_INVENTORY_TEMPLATE} \
  > ${OCP3_INVENTORY_FILE}


# Replace values in OSEv3.yml template
cp ${OCP3_OSEV3_TEMPLATE} ${OCP3_OSEV3_YML_FILE}

sed -i -e "/openshift_master_default_subdomain:/s/:.*/: $APPS_DNS_SUFFIX/" ${OCP3_OSEV3_YML_FILE} 

sed -i -e "/openstack_auth_url:/s|:.*|: $OS_AUTH_URL|" ${OCP3_OSEV3_YML_FILE}
sed -i -e "/openstack_username:/s/:.*/: $OS_USERNAME/" ${OCP3_OSEV3_YML_FILE}
sed -i -e "/openstack_password:/s/:.*/: $OS_PASSWORD/" ${OCP3_OSEV3_YML_FILE}
sed -i -e "/openstack_tenant_name:/s/:.*/: $OS_TENANT_NAME/" ${OCP3_OSEV3_YML_FILE}
sed -i -e "/openstack_region:/s/:.*/: $OS_REGION_NAME/" ${OCP3_OSEV3_YML_FILE}

sed -i -e "/cluster_hostname:/s/:.*/: $MASTER_DNS_NAME/" ${OCP3_OSEV3_YML_FILE}
sed -i -e "/cluster_public_hostname:/s/:.*/: $MASTER_DNS_NAME/" ${OCP3_OSEV3_YML_FILE}

sed -i -e "/bindDN:/s/:.*/: $LDAP_BIND_DN/"  ${OCP3_OSEV3_YML_FILE}
sed -i -e "/bindPassword:/s/:.*/: $LDAP_BIND_PASSWORD/"  ${OCP3_OSEV3_YML_FILE}
sed -i -e "/^ *url:/s|:.*|: $LDAP_URL|"  ${OCP3_OSEV3_YML_FILE}

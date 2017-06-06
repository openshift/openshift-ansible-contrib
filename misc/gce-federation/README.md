=== GCE quickstart
cat << EOF > inventory/gce.ini
gce_service_account_email_address = <service account email address>
gce_service_account_pem_file_path = <path to service account pem file>
gce_project_id = <gce project id>
EOF

export FEDERATION_ID=<my federation id>
export FEDERATION_DNS_ZONE=<my.federation.dns.zone >
export GCE_CREDS_FILE=<path to gce credentials json file>
export GCE_SERVICE_ACCOUNT=<gce service account>
export GCE_PROJECT_ID=<gce project id>
ansible-playbook init.yaml && ./inventory/gce.py --refresh-cache && ansible-playbook install.yaml && ansible-playbook federate.yaml && ansible-playbook deploy-app.yaml 

===General Configuration
====Required variables
Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | description |
|---------------|---------|-------------|
| federation_id | FEDERATION_ID | Unique ID for this federation |

====Optional variables
Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | default | description |
|---------------|---------|---------|-------------|
|               |         |         |             |

===GCE Provisioning Configuration
GCE Provisioning is enabled when gce_cluster_count > 0

====Required variables
Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | description |
|---------------|---------|-------------|
| gce_creds_file | GCE_CREDS_FILE | Path to the GCE credentials file to use for provisioning |
| gce_service_account | GCE_SERVICE_ACCOUNT | GCE service account to use for provisioning |
| gce_project_id | GCE_PROJECT_ID | GCE project id to use for provisioning |

====Optional variables
Variables can be set using extra vars (using -e at the command line) or by export environment variables.

| variable name | env var | default | description |
|---------------|---------|---------|-------------|
| gce_cluster_count | GCE_CLUSTER_COUNT | 3 | Number of GCE Clusters to create |
| gce_regions | GCE_REGIONS | us-east1,us-central1,us-west1 | Comma separated list of regions to deploy clusters to |

===Cluster teardown
ansible-playbook teardown.yaml

# OpenShift Container Platform on Azure using Ansible deployment of ARM

This repository contains a few scripts and playbooks to deploy an OpenShift Container Platform on Azure using Ansible and ARM templates. This is a helper method on the [OpenShift Container Platform on Azure reference architecture document](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/).

## Setup
Before running the Ansible deploy for Azure, all the dependencies needed for Azure Python API must be installed. The [playbooks/prepare.yaml](playbooks/prepare.yaml) playbook can be used that will install the required packages in `localhost`:

```bash
ansible-playbook playbooks/prepare.yml
```

## Azure Credentials

**NOTE:** A serviceprincipal creation is required, see [the OCP on Azure ref. arch. document](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/#azure_active_directory_credentials) and [Use Azure CLI to create a service principal to access resources](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal-cli) for more information.

Azure credentials needs to be stored in a file at `~/.azure/credentials` with the following format (do not use quotes or double quotes):

```
[default]
subscription_id=00000000-0000-0000-0000-000000000000
tenant=11111111-1111-1111-1111-111111111111
client_id=33333333-3333-3333-3333-333333333
secret=ServicePrincipalPassword
```

Where:

* `subscription_id` and `tenant` parameters can be obtained from the azure cli:

```
sudo yum install -y nodejs
sudo npm install -g azure-cli
azure login
azure account show
info:    Executing command account show
data:    Name                        : Acme Inc.
data:    ID                          : 00000000-0000-0000-0000-000000000000
data:    State                       : Enabled
data:    Tenant ID                   : 11111111-1111-1111-1111-111111111111
data:    Is Default                  : true
data:    Environment                 : AzureCloud
data:    Has Certificate             : Yes
data:    Has Access Token            : Yes
data:    User name                   : youremail@yourcompany.com
data:     
info:    account show command OK
```

* `client_id` is the "Service Principal Name" parameter when you create the serviceprincipal:

```
$ azure ad sp create -n azureansible -p ServicePrincipalPassword

info:    Executing command ad sp create
+ Creating application ansiblelab
+ Creating service principal for application 33333333-3333-3333-3333-333333333
data:    Object Id:               44444444-4444-4444-4444-444444444444
data:    Display Name:            azureansible
data:    Service Principal Names:
data:                             33333333-3333-3333-3333-333333333
data:                             http://azureansible
info:    ad sp create command OK
```

* `secret` is the serviceprincipal password

**NOTE:** Azure credentials can be also exported as environment variables or used as ansible variables. See [Getting started with Azure](https://docs.ansible.com/ansible/guide_azure.html) in the Ansible documentation for more information.

## Parameters required
The ansible playbook needs some parameters to be specified. There is a [vars.yaml example file](vars.yaml.example) included in this repository that should be customized with your environment data.

```
$ cp vars.yaml.example vars.yaml
$ vim vars.yaml
```

**NOTE:** The parameters detailed description can be found in [the official documentation](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/#provision_the_emphasis_role_strong_openshift_container_platform_emphasis_environment)

* sshkeydata: id_rsa.pub content
* sshprivatedata: id_rsa content in base64 without \n characters (`cat ~/.ssh/id_rsa | base64 | tr -d '\n'`)
* adminusername: User that will be created to login via ssh and as OCP cluster-admin
* adminpassword: Password for the user created (in plain text)
* rhsmusernamepasswordoractivationkey: This should be "usernamepassword" or "activationkey"
 * If "usernamepassword", then the username and password should be specified
 * If "activationkey", then the activation key and organization id should be specified
* rhnusername: The RHN username where the instances will be registered
 * rhnusername: "organizationid" if  activation key method has been chosen
* rhnpassword: The RHN password where the instances will be registered in plain text
 * rhnpassword: "activationkey" if activation key method has been chosen
* subscriptionpoolid: The subscription pool id the instances will use
* resourcegroupname: The Azure resource name that will be created
* aadclientid: Active Directory ID needed to be able to create, move and delete persistent volumes
* aadclientsecret: The Active Directory Password to match the AAD Client ID
* wildcardzone: Subdomain for applications in the OpenShift cluster (required by the load balancer, but nip.io will be used). It is just the subdomain, not the full FQDN.

Optional (default values are set in [playbooks/roles/azure-deploy/default/main.yaml](playbooks/roles/azure-deploy/default/main.yaml))
* templatelink: The ARM template that will be deployed
* numberofnodes: From 3 to 30 nodes
* image: The operating system image that will be used to create the instances
* mastervmsize: Master nodes VM size
* infranodesize: Infrastructure nodes VM size
* nodevmsize: Application nodes VM size
* location: westus by default
* openshiftsdn: SDN used by OCP. "redhat/openshift-ovs-multitenant" by default
* metrics: true to enable cluster metrics, false to not enable (note, do not quote as those variables are boolean values, not strings), true by default
* logging: true to enable cluster logging, false to not enable (note, do not quote as those variables are boolean values, not strings), true by default
* opslogging: true to enable ops cluster logging, false to not enable (note, do not quote as those variables are boolean values, not strings), false by default

## Running the deploy

```bash
ansible-playbook -e @vars.yaml playbooks/deploy.yml
```

**NOTE:** Ansible version should be > 2.1 as the Azure module was included in that version

### Sample Output

```bash
$ scripts/run.sh  

PLAY [localhost] ****************************************************************************************************************************************

TASK [Destroy Azure Deploy] *****************************************************************************************************************************
changed: [localhost]

TASK [Destroy Azure Deploy] *****************************************************************************************************************************
ok: [localhost]

TASK [Create Azure Deploy] ******************************************************************************************************************************
changed: [localhost]

PLAY RECAP **********************************************************************************************************************************************
localhost                  : ok=3    changed=2    unreachable=0    failed=0    
```

# Red Hat OpenShift Container Platform on Azure

## Overview
The reference architecture supports the creation of either a multi-node full HA
production cluster or a single node designed for exploration of OpenShift on Azure.

Reference architectures documentation are located:

* [Deploying Red Hat OpenShift Container Platform 3.6(3.7) on Microsoft Azure](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3.6_on_microsoft_azure/)
* [Deploying Red Hat OpenShift Container Platform 3.5 on Microsoft Azure](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html/deploying_red_hat_openshift_container_platform_3.5_on_microsoft_azure/index)

When creating the Red Hat OpenShift Container Platform on Azure, you will need a SSH RSA key for access.

## SSH Key Generation

1. [Windows](ssh_windows.md)
2. [Linux](ssh_linux.md)
3. [Mac](ssh_mac.md)

## Create the Installation
### OCP Version 3.7 - Create the Installation on the Azure Portal
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.7%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.7%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

#### Create a Single VM Installation using the Azure Portal

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.7%2Fallinone.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

#### Development Branch
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fglennswest%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.7%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fglennswest%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2F3.7%2Fazure-ansible%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

### OCP Version 3.6 - Create the Installation on the Azure Portal
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.6%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.6%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

### OCP Version 3.5 - Create the Installation on the Azure Portal
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.5%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fopenshift%2Fopenshift-ansible-contrib%2Fmaster%2Freference-architecture%2Fazure-ansible%2F3.5%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## Parameters

For macOS:

1. SSHKeyData - Public Key - Copy/Paste from .ssh/id_rsa.pub - pbcopy < ~/.ssh/id_rsa.pub

2. PoolId - From RHEL - subscription-manager list --available

3. SSHPrivate Data - Base64 Encoded id_rsa - cat ~/.ssh/id_rsa | base64 | pbcopy

For RHEL/Fedora/CentOS:

1. SSHKeyData - Public Key - Copy/Paste from .ssh/id_rsa.pub - xclip -selection clipboard < ~/.ssh/id_rsa.pub

2. PoolId - From RHEL - subscription-manager list --available

3. SSHPrivate Data - Base64 Encoded id_rsa - cat ~/.ssh/id_rsa | base64 | xclip -selection clipboard

### Input Parameters

| Name| Type           | Description |
| ------------- | ------------- | ------------- |
| adminUsername  | String       | Username for SSH Login and OpenShift Webconsole |
|  adminPassword | SecureString | Password for the OpenShift Webconsole |
| sshKeyData     | String       | Public SSH Key for the Virtual Machines |
| masterDnsName  | String       | DNS Prefix for the OpenShift Master / Webconsole |
| numberOfNodes  | Integer      | Number of OpenShift Nodes to create |
| masterVMSize | String | The size of the Master Virtual Machine |
| infranodeVMSize| String | The size of the Infranode Virtual Machine |
| nodeVMSize| String | The size of the each Node Virtual Machine |

### Output Parameters

| Name| Type           | Description |
| ------------- | ------------- | ------------- |
| OpenShift Webconsole | String       | URL of the OpenShift Webconsole |
| OpenShift Master ssh |String | SSH String to Login at the Master |
| OpenShift Router Public IP | String       | Router Public IP. Needed if you want to create your own Wildcard DNS |

------

This template deploys Red Hat OpenShift on Azure.

Attribution:

Thanks to:
Daniel Falkner - Microsoft Germany - For original templates.

Harold Wong <Harold.Wong@microsoft.com> for his great support.

Ivan McKinley

For full commit history: Please see - https://github.com/glennswest/azure-openshift/

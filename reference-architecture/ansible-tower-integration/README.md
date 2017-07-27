DISCLAIMER: The code within openshift-ansible-contrib is unsupported code that can be used in conjunction with openshift-ansible.

# Tower Integration Guide

This guide explains how to integrate the reference architectures within openshift-ansible-contrib/reference-architectures into Ansible Tower. By integrating the reference architecture playbooks into Ansible Tower it is possible to centralize and control the OpenShift infrastructure with a visual dashboard, role-based access control, job scheduling, integrated notifications and graphical inventory management. You may also want to check out this [UI prototype](https://github.com/strategicdesignteam/labs-console) that shows how it's possible to build a custom interface north of Tower to visualize the automated deployments for a user that might not want to understand the intricies of Tower.

Finally, you might want to check out this [demonstration video](https://youtu.be/0aNJX-GQowI)

## Overview

The diagram below illustrates the desired end state of this guide - to have Ansible Tower workflows able to deploy OpenShift and other services on various cloud providers, including creating the necessary virtual infrastructure on each cloud provider. 

![Overview Diagram](https://github.com/openshift/openshift-ansible-contrib/blob/master/reference-architecture/ansible-tower-integration/Overview_Diagram.png)

Here are the major stages to achieving the desired end state. 
1. Deploying Ansible Tower on the desired cloud provider. 
2. Configuring Ansible Tower to deploy OpenShift and other services on the cloud provider of choice.
3. Performing a deployment. 

Currently this guide has support for Amazon Web Services, but we intend to add instructions for other providers. Deployment of the AWS reference architecture for OpenShift Container Platform including registration to the Red Hat Insights service and deployment of CloudForms with the ability to manage OpenShift Container Platform takes approximately 60 minutes.

## Deploying Tower

This section provides information about how to deploy Ansible Tower on various cloud providers. It then provides information about how to configure the deployed Ansible Tower. No matter where you deploy Tower you'll need to do two things:

1. [Obtain a license key](https://www.ansible.com/license)
2. [Download Ansible Tower](https://www.ansible.com/tower-trial)

### Deploying Tower on Amazon Web Services (AWS)

Follow the [Deployment Steps](http://docs.aws.amazon.com/quickstart/latest/ansible-tower/deployment.html) section of the [Ansible Tower on AWS](http://docs.aws.amazon.com/quickstart/latest/ansible-tower/welcome.html) quickstart guide to deploy Ansible Tower on AWS.

## Future Sections for deploying Tower on Providers

We would welcome the addition of the the following sections to this guide:

+ Deploying Tower on Google Cloud
+ Deploying Tower on Microsoft Azure
+ Deploying Tower on OpenStack
+ Deploying Tower on VMware


## Configuring Tower

Once you have deployed Ansible Tower on a provider, you can then configure it to deploy OpenShift Container Platform, CloudForms, and enable Red Hat Insights on OCP and CloudForms. The following sections detail how to do this. 

### Configuring Ansible Tower for deployments on Amazon Web Services

This guide shows you how to use the master branch of [OpenShift-Ansible-Contrib](https://github.com/openshift/openshift-ansible-contrib). If you want to ensure that no changes are made to the deployment configuration, you may want to [fork the repository](https://help.github.com/articles/fork-a-repo/) to ensure nothing changes without your knowledge.

The directories contained within this directory roughly include:

```
------ create_httpd_file => playbooks to create a httpd auth file
  \---      tower_config => playbooks that bootstrap a blank tower
   \--    tower_unconfig => playbooks that unconfigure tower
```

Once you have Ansible Tower running and licensed you can clone and run the tower_config playbook with the appropriate variables. This will configure Ansible. Just make sure you have your tower_cli.cfg file setup and also make sure you have your AWS_KEY and AWS_SECRET as well as the ssh key you wish to use to authenticate to your machines. Then you can do the following:

Set the appropriate host, username, and password in ~/.tower_cli.cfg.
```$ $ vi ~/.tower_cli.cfg 
host=tower.domain.com
username=admin
password=yourpassword
```

You will need to git clone the openshift-ansible installer to your tower instance. In the future it would be ideal to have this integrated into tower as a project instead of stand alone.
```
git clone https://github.com/openshift/openshift-ansible.git /usr/share/ansible/openshift-ansible
```

Now you can clone the openshift-ansible-contrib repository and run the tower_config bootstrapping playbook. The table below explains the variables you should pass to it.
```
$ git clone https://github.com/strategicdesignteam/openshift-ansible-contrib.git
$ cd reference-architecture/ansible-tower-integration/tower_config
$ ansible-playbook tower_config.yaml --extra-vars "AWS_MACHINE_SSH_KEY=<PATH/TO/PRIVKEY> AWS_KEY=<AWS_KEY> AWS_SECRET=<YOUR_AWS_SECRET> TOWER_HOSTNAME=tower.acme.com TOWER_USER=admin TOWER_PASSWORD=password"
```

| Variable                   | Required           | Description                                   |
| ---------------------------|:------------------:| ---------------------------------------------:|
| AWS_MACHINE_KEY            | yes                | Your ssh key for connecting to AWS instances  |
| AWS_KEY                    | yes                | Your AWS Key                                  |
| AWS_SECRET                 | yes                | Your AWS Extra Key                            |
| TOWER_HOSTNAME             | yes                | The hostname of the tower instance            |
| TOWER_USER                 | yes                | Username (admin)                              |
| TOWER_PASSWORD             | yes                | Password for TOWER_USER                       |

This will configure tower with all the inventories, credentials, job_templates, and workflows to begin deploying across Amazon Web Services. After this is done you will need to log into Ansible Tower and edit the job named "workflow-ocp-aws-install". You will need to edit the extra_vars section of the job named workflow-ocp-aws-install and change the values wherever they are set to "CHANGEME" to the appropriate values for your environment. You can find the documentation for those values in the specific provider reference architectures. For example, here in the [AWS Reference Architecture](https://github.com/strategicdesignteam/openshift-ansible-contrib/tree/temp/reference-architecture/aws-ansible)

The workflow-ocp-aws-install can now be run. It will:

+ Create a cloudformations template on AWS
+ Install OCP on the instances provided by the cloudformations template
+ Enable Red Hat Insights on OCP
+ Deploy CloudForms and configure the OCP cluster as a provider (Coming Soon)

You can use the unconfig_tower playbook to remove everything that was created by the tower_config job.

```
$ cd reference-architecture/ansible-tower-integration/tower_config
$ ansible-playbook tower_unconfig.yaml
```

Some interesting thing that were learned:

There are many modules for tower (search tower_ [here](http://docs.ansible.com/ansible/list_of_all_modules.html)). There is no ansible module for creating a workflow. It would be helpful if this were available. For now, we will try to use the tower-cli. Also, there is no way to start an SCM update using the tower_project ansible module. It would be helpful if that existed, so the SCM update could be issued and then job_templates could reference the available playbooks that were synchronized.

It also appears that workflows can be exported via a schema. There is a great document [here](https://github.com/ansible/tower-cli/blob/master/docs/WORKFLOWS.md) on how to do workflows via tower-cli. The problem is that schemas requires IDs on inventories. These IDs are dynamically generated when a inventory is created, so it's impossible to export a schema with an inventory and pass it to another tower instance and have it imported correctly. Here is a [issue in github](https://github.com/ansible/tower-cli/issues/302) asking it to be changed.

### Future Sections for configuring deployments of OCP, Insights, CloudForms on Clouds

We would welcome the addition of the following sections:

+ Configuring Ansible Tower for deployments on Google Cloud Platform
+ Configuring Ansible Tower for deployments on Microsoft Azure
+ Configuring Ansible Tower for deployments on OpenStack
+ Configuring Ansible Tower for deployments on VMware



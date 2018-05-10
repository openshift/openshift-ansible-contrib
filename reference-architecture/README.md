# Reference Architecture for OpenShift

This repository contains a series of directories containing code used to deploy an OpenShift environment on different cloud providers. The code in this repository supplements the reference architecture guides for OpenShift 3. Different guides and documentation exists depending on the different providers. Regardless of the provider, the environment will deploy masters, infrastructure and application nodes. The code also deploys a Docker registry and scales the router to the number of infrastructure nodes.

**NOTE: Some repositories containing scripts and ansible playbooks are
deprecated.**

For documentation, please see the following links

* VMWare - [Deploying and Managing OpenShift 3.9 on VMware vSphere](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_vmware_vsphere/)
* OSP - [Deploying and Managing OpenShift 3.9 on Red Hat OpenStack Platform 10](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_red_hat_openstack_platform_10/)
* Azure - [Deploying and Managing OpenShift 3.9 on Azure](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_azure/)
* AWS - [Deploying and Managing OpenShift Container Platform 3.6 on Amazon Web Services](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_and_managing_openshift_container_platform_3.6_on_amazon_web_services/)
* GCP - [Deploying Red Hat OpenShift Container Platform 3 on Google Cloud Platform](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_and_managing_openshift_container_platform_3_on_google_cloud_platform/)
* RHV - [Deploying Red Hat OpenShift Container Platform 3.6 on Red Hat Virtualization 4](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3.6_on_red_hat_virtualization_4/)

For a list of more reference architectures, see [OpenShift Container Platform reference architectures](https://access.redhat.com/documentation/en-us/reference_architectures/?category=openshift%2520container%2520platform)

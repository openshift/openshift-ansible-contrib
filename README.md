# OpenShift and Atomic Platform Ansible Contrib

[![Build
Status](https://travis-ci.org/openshift/openshift-ansible-contrib.svg?branch=master)](https://travis-ci.org/openshift/openshift-ansible-contrib)

This repository contains *unsupported* code that can be used in conjunction with the
[openshift-ansible](https://github.com/openshift/openshift-ansible) repository, namely:
- additional [roles](https://github.com/openshift/openshift-ansible-contrib/tree/master/roles) for OpenShift deployment
- code for provisioning various cloud providers ([GCP](https://github.com/openshift/openshift-ansible-contrib/tree/master/reference-architecture/gcp), [AWS](https://github.com/openshift/openshift-ansible-contrib/tree/master/reference-architecture/aws-ansible), [VMware](https://github.com/openshift/openshift-ansible-contrib/tree/master/reference-architecture/vmware-ansible), [Azure](https://github.com/openshift/openshift-ansible-contrib/tree/master/reference-architecture/azure-ansible), [OpenStack](https://github.com/openshift/openshift-ansible-contrib/tree/master/playbooks/provisioning/openstack) and [Red Hat Virtualization (RHV) / oVirt](https://github.com/openshift/openshift-ansible-contrib/tree/master/reference-architecture/rhv-ansible))
- supporting scripts and playbooks for the various [reference architectures](https://github.com/openshift/openshift-ansible-contrib/tree/master/reference-architecture) Red Hat has published

## Contributing

If you're submitting a pull request or doing a code review, please
take a look at our [contributing guide](./CONTRIBUTING.md).

## Running tests locally
We use [tox](http://readthedocs.org/docs/tox/) to manage virtualenvs and run
tests. Alternatively, tests can be run using
[detox](https://pypi.python.org/pypi/detox/) which allows for running tests in
parallel


```
pip install tox detox
```

List the test environments available:
```
tox -l
```

Run all of the tests with:
```
tox
```

Run all of the tests in parallel with detox:
```
detox
```

Running a particular test environment (python 2.7 flake8 tests in this case):
```
tox -e py27-ansible22-flake8
```

Running a particular test environment in a clean virtualenv (python 3.5 yamllint
tests in this case):
```
tox -r -e py35-ansible22-yamllint
```

If you want to enter the virtualenv created by tox to do additional
testing/debugging (py27-flake8 env in this case):
```
source .tox/py27-ansible22-flake8/bin/activate
```

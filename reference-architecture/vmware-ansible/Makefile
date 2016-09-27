.PHONY: clean all ansible-container-image ansible-vcenter-inventory-container-imag

DOCKER_OPTS=time docker run -t --rm --dns=10.19.114.2 --volume `pwd`:/opt/ansible:Z
PLAYBOOK_RUN=playbooks/infrastructure.yaml
PLAYBOOK_CLEAN=playbooks/cleanup-vsphere.yaml
DOCKER_BUILD=docker build --rm
TAGS=--tags

#Ansible TAGS
TEST=test
OSEINSTALL=ose-install
OSECONFIGURE=ose-configure
OSEDEMO=ose-demo
HAPROXY=haproxy
INFRA=infrastructure
CLEANTEST=rmtest
CLEANPROD=rmprod
CLEANINFRA=rminfra
PROD=prod
NFS=nfs

ANSIBLE=ansible:2.1.0.0-1-latest 


cleantest:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(CLEANTEST) $(PLAYBOOK_CLEAN)

cleanprod:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(CLEANPROD) $(PLAYBOOK_CLEAN)

clean:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(CLEANPROD),$(CLEANINFRA) $(PLAYBOOK_CLEAN)

nfs:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(NFS) $(PLAYBOOK_RUN)

haproxy:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(HAPROXY) $(PLAYBOOK_RUN)

infra:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(INFRA) $(PLAYBOOK_RUN)

test:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(TEST) $(PLAYBOOK_RUN)

ose-install:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(OSEINSTALL) $(PLAYBOOK_RUN)

ose-configure:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(OSECONFIGURE) $(PLAYBOOK_RUN)

ose-demo:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(OSEDEMO) $(PLAYBOOK_RUN)

test-ose:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(TEST),$(OSE) $(PLAYBOOK_RUN)

alltest:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(INFRA),$(TEST),$(OSE) $(PLAYBOOK_RUN)

prod:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(PROD) $(PLAYBOOK_RUN)

prod-ose:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(PROD),$(OSEINSTALL) $(PLAYBOOK_RUN)

all:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(INFRA),$(PROD),$(OSEINSTALL),$(OSECONFIGURE),$(OSEDEMO) $(PLAYBOOK_RUN)

all-ose:
	$(DOCKER_OPTS) $(ANSIBLE) $(TAGS) $(PROD),$(OSEINSTALL),$(OSECONFIGURE),$(OSEDEMO) $(PLAYBOOK_RUN)

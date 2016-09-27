DOCKER_BUILD=docker build --rm --tag
ANSIBLE=ansible:2.2-latest

#TARGETS
all:
	$(DOCKER_BUILD) $(ANSIBLE) -f Dockerfile .

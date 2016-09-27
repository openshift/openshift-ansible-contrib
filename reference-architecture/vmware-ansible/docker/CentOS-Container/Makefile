DOCKER_BUILD=docker build --rm --tag
ANSIBLE=ansible:2.1.0.0-1-latest

#TARGETS
all:
	$(DOCKER_BUILD) $(ANSIBLE) -f Dockerfile .

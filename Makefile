PACKER_FILE = alpine.pkr.hcl

.DEFAULT_GOAL := all

.PHONY: all clean packer vagrant rebuild

all: packer vagrant

image box packer: 
	cd packer; packer init .
	cd packer; packer build $(PACKER_FILE)

vm vagrant:
	cd vagrant; vagrant box add --force alpine-local ../packer/alpine-3.23.2.box
	cd vagrant; vagrant up

clean:
	cd vagrant; vagrant destroy -f
	rm -f packer/*.box

rebuild: clean all
PACKER_FILE = alpine.pkr.hcl

.DEFAULT_GOAL := all

.PHONY: all clean packer vagrant rebuild

all: packer vagrant

image box packer: 
	packer init .
	packer build $(PACKER_FILE)

vm box vagrant: build
	vagrant up

clean:
	vagrant destroy -f
	rm -f *.box

rebuild: clean all
# Alpine Linux Vagrant Box built with Packer (VirtualBox)

This repository contains a **Packer configuration** to build a minimal, reproducible **Alpine Linux Vagrant box** using **VirtualBox**.

The goal is to provide a lightweight Alpine base image, suitable for local development environments.

Inspired by:  
https://github.com/bobfraser1/packer-alpine

## Features

- Alpine Linux **3.23.x**
- VirtualBox-compatible
- Vagrant box output
  .

## Requirements

You need the following tools installed:

- [Packer](https://developer.hashicorp.com/packer) ≥ 1.9
- [VirtualBox](https://www.virtualbox.org/) (tested with VBoxVGA controller)
- [Vagrant](https://www.vagrantup.com/) (optional, to consume the box)

Make sure hardware virtualization is enabled in your BIOS (Intel VT-x / AMD-V).

## Initialization

Before building, initialize Packer plugins:

```bash
packer init .
```

## Build the Vagrant box

Run:

```bash
packer build alpine.pkr.hcl
```

This will produce a Vagrant box file: `alpine-packer-alpine-3.23.2.box`.

## Using the generated Vagrant box

Add the box locally:

```bash
vagrant box add alpine-local alpine-packer-alpine-3.23.2.box
```

Example Vagrantfile:

```hcl
Vagrant.configure("2") do |config|
  config.vm.box = "alpine-local"
end
```

Then:

```bash
vagrant up
```

# Customization

You can easily customize:

- Alpine version (change iso_url and iso_checksum)
- Disk size
- Memory / CPU
- Installed packages
- Users and SSH configuration
- Provisioning steps

## License

This software is in public domain.

## Author

Built by a DevOps engineer for reproducible Alpine-based VirtualBox environments.

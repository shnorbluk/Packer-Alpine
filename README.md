# Alpine Linux Vagrant Box built with Packer (VirtualBox)

This repository contains a **Packer configuration** to build a minimal, reproducible **Alpine Linux Vagrant box** using **VirtualBox**.

The goal is to provide a lightweight Alpine base image, suitable for local development environments.

Inspired by:  
https://github.com/bobfraser1/packer-alpine

## Features

- Alpine Linux **3.23.x**
- VirtualBox-compatible
- Vagrant box output

## Requirements

You need the following tools installed:

- [Packer](https://developer.hashicorp.com/packer) ≥ 1.9
- [VirtualBox](https://www.virtualbox.org/) (tested with VBoxVGA controller)
- [Vagrant](https://www.vagrantup.com/) (optional, to consume the box)

Make sure hardware virtualization is enabled in your BIOS (Intel VT-x / AMD-V).

## Quick start

To make a useable Alpine Virtualbox VM:

```sh
make
```

And then connect to it:

```sh
cd vagrant
vagrant ssh
```

## Initialization

### 1. Build the box image

Work in `packer` directory:
```bash
cd packer
```

Before building, initialize Packer plugins:

```bash
packer init .
```

To build the Vagrant image, run:

```bash
packer build alpine.pkr.hcl
```

This will produce a Vagrant box file: `alpine-3.23.2.box`.

## 2. Using the generated Vagrant box

Work in `vagrant` directory:
```bash
cd ../vagrant
```

Add the box locally:

```bash
vagrant box add alpine-local ../packer/alpine-3.23.2.box
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

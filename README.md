# Alpine Linux Vagrant Box built with Packer (VirtualBox)

This repository contains a **Packer configuration** to build a minimal, reproducible **Alpine Linux Vagrant box** using **VirtualBox**.

The goal is to provide a lightweight Alpine base image, suitable for local development environments.

Inspired by:  
https://github.com/bobfraser1/packer-alpine

## Features

- Alpine Linux **3.24.x**
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

#### Build without any proxy
If you can access Internet directly, run the following to build the Vagrant image:

```bash
packer build alpine.pkr.hcl
```

Or, to build only the box for qemu :
```bash
packer build -only="qemu.alpine" alpine.pkr.hcl
```

This will produce a Vagrant box file: `alpine-3.23.2.box`.

#### Build with a proxy
If you have to use a proxy to access Internet, first create a `local.pkrvars.hcl` file:

```hcl
proxy_url = "http://proxy_ip:port"
```

Then run these commands to build the image:

```powershell
$env:https_proxy="http://proxy_ip:port"
packer build -var-file="local.pkrvars.hcl" alpine.pkr.hcl
```

This will produce a Vagrant box file: `alpine-3.23.2.box`, independent of your proxy : the proxy configuration will not
be included in the image.

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

And ssh into the VM:

```bash
vagrant ssh
```


# Customization

You can easily customize the image, by changing variables in top of `packer/alpine.pkr.hcl`:

- Alpine version (change `iso_url` and `iso_checksum` variable)
- Disk size (set size in MB in `disk_size_mb` variable)
- Docker installation (set `install_docker` variable to `true` or `false`)
- Podman installation (set `install_podman` variable to `true` or `false`)
- Installed packages (set list of apk packages in `additional_packages` variable)
- User passwords (set `vagrant_password` and `root_password` variables)

To customize VM, set Memory, CPU, shared folders and other parameters in `vagrant/Vagrantfile`

## License

This software is in public domain.

## Author

Built by a DevOps engineer for reproducible Alpine-based VirtualBox environments.

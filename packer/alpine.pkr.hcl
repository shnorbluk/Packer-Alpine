// -----------------------------------------------------------
// 1. DECLARATION DES VARIABLES (OPTIONNEL MAIS RECOMMANDE)
// -----------------------------------------------------------
variable "iso_url" {
  type    = string
  default = "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-standard-3.24.2-x86_64.iso"
  description = "URL de l'ISO Alpine"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:20c026e3a788bfb75fc8b50a54bcc12aee85e3c75909740bba6a6f4563d63296"
  description = "Checksum SHA256 de l'ISO Alpine"
}

variable "vm_name" {
  type    = string
  default = "alpine-3.24.2"
}

variable "disk_size_mb" {
  type    = number
  default = 8192 // 8 GB
}

variable "root_password" {
  type    = string
  default = "vagrant"
}

variable "vagrant_password" {
  type    = string
  default = "vagrant"
}

variable "install_docker" {
  type    = bool
  default = false
}

variable "install_podman" {
  type    = bool
  default = true
}

variable "additional_packages" {
  type    = list(string)
  default = ["bash", "curl", "vim"]
}

variable "proxy_url" {
  type    = string
  default = ""
  description = "Proxy URL, like http://host:port (or leave empty if no proxy)"
}

// -----------------------------------------------------------
// 1. BLOC PACKER (REQUIRED)
// -----------------------------------------------------------
packer {
  required_plugins {
    // Déclare le plugin pour VirtualBox
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = ">= 1.1.3"
    }
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.4"
    }
    vagrant = {
      version = "~> 1"
      source = "github.com/hashicorp/vagrant"
    }
  }
}

// -----------------------------------------------------------
// 2. BLOC SOURCE (BUILDER VIRTUALBOX-ISO)
// -----------------------------------------------------------
source "virtualbox-iso" "alpine" {
  // --- A. Configuration de l'ISO ---
  iso_url             = var.iso_url
  iso_checksum        = var.iso_checksum

  // Le dossier 'http' doit contenir 'answers.txt' et d'autres fichiers de support.
  http_directory      = "http"

  // --- B. Configuration de la VM ---
  vm_name             = "${var.vm_name}-vbox"
  guest_os_type       = "Linux26_64"
  disk_size           = var.disk_size_mb
  headless            = false // Lancer la VM sans interface graphique (plus rapide)

  // Configuration mémoire/CPU via VBoxManage
  vboxmanage          = [
    ["modifyvm", "{{ .Name }}", "--memory", "4096"],
    ["modifyvm", "{{ .Name }}", "--cpus", "4"],
    ["modifyvm", "{{ .Name }}", "--accelerate3d", "off"], // Désactiver 3D acceleration si activée
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],  // Spécifie VBoxVGA comme contrôleur graphique
    ["modifyvm", "{{ .Name }}", "--vram", "16"],  // 16M de mémoire vidéo
    ["modifyvm", "{{ .Name }}", "--pae", "off"]  // désactiver l'extension d'adresse physique (PAE) et le bit NX (No-Execute)
  ]

  // --- C. Configuration SSH (Post-installation) ---
  ssh_username        = "root"
  // Nous définissons le mot de passe dans le fichier 'answers.txt' pour l'installation
  ssh_password        = "p"
  ssh_wait_timeout    = "20m"

  // --- D. Commande de Démarrage (Automatisation de l'Installation) ---
  boot_wait           = "2m"
  boot_command        = [
    "<wait>",
    "root<enter>",
    "ifconfig eth0 up<enter>",
    "udhcpc -i eth0<enter>", // Alpine utilise généralement 'udhcpc'
    "<wait10>", // Attendre 10 secondes pour que l'interface obtienne une adresse IP
    "wget -O /tmp/answers.txt http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers.txt<enter>", // Télécharger le fichier de réponses
    "export ERASE_DISKS=/dev/sda<enter>",
    "export PROXYOPTS=${var.proxy_url}<enter>",
    "export https_proxy=${var.proxy_url}<enter>",
    "setup-alpine -f /tmp/answers.txt<enter>", // Lancer l'installation avec le fichier
    "<wait15>p<enter>p<enter>",
    "<wait1m>mount /dev/sda3 /mnt<enter>",
   "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
   "reboot<enter>"                 // Le script setup-alpine demande un reboot à la fin
  ]
  shutdown_command    = "poweroff"
}

source "qemu" "alpine" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  vm_name      = "${var.vm_name}-qemu"
  disk_size    = var.disk_size_mb
  # accelerator  = "kvm"
  format       = "qcow2"

  headless     = false

  http_directory = "http"

  ssh_username      = "root"
  ssh_password      = "p"
  ssh_wait_timeout  = "20m"

  boot_wait = "50s"
  boot_command = [
    "<wait>",
    "root<enter>",
    "ifconfig eth0 up<enter>",
    "udhcpc -i eth0<enter>",
    "<wait10>",
    "wget -O /tmp/answers.txt http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers.qemu.txt<enter>",
    "export ERASE_DISKS=/dev/vda<enter>",
    "setup-alpine -f /tmp/answers.txt<enter>",
    "<wait15>p<enter>p<enter>",
    "<wait25>mount /dev/vda3 /mnt<enter>",
    "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
    "reboot<enter>"
  ]

  shutdown_command = "poweroff"
}


// -----------------------------------------------------------
// 3. BLOC BUILD (PROVISIONERS ET POST-PROCESSORS)
// -----------------------------------------------------------
build {
  sources = [
    "source.virtualbox-iso.alpine",
    "source.qemu.alpine"
  ]

  // --- A. Provisioner Shell (Scripts de post-installation) ---
  provisioner "file" {
    source      = "vagrant.pub"
    destination = "/tmp/authorized_keys"
  }

  provisioner "shell" {
    inline = [
      // Mettre à jour et installer les dépendances de base
      "export https_proxy=${var.proxy_url}",
      "apk update",
      "apk upgrade",
      "apk add virtualbox-guest-additions ${join(" ", var.additional_packages)}",
      "rc-update add virtualbox-guest-additions default",
      "rc-update -u",

      // Configuring SSH for Vagrant user
      "mkdir /home/vagrant/.ssh",
      "mv /tmp/authorized_keys /home/vagrant/.ssh/authorized_keys",
      "chmod 600 /home/vagrant/.ssh/authorized_keys",
      "chown -R vagrant:vagrant /home/vagrant/.ssh",

      // Changing passwords
      "echo 'root:${var.root_password}' | chpasswd",
      "echo 'vagrant:${var.vagrant_password}' | chpasswd",

      // Configure doas with no password for user vagrant
      "echo permit nopass vagrant > /etc/doas.d/99-vagrant.conf",
      "ln -s /usr/bin/doas /usr/bin/sudo",

      // DOCKER
      "if ${var.install_docker}; then",
      " apk add docker",
      " addgroup vagrant docker",
      " rc-update add docker default",
      " rc-update -u",
      "fi",

      // PODMAN
      "if ${var.install_podman}; then",
      " apk add podman",
      " echo vagrant:100000:65536 | tee /etc/subuid > /etc/subgid", # for "cannot find UID/GID for user vagrant"
      " echo mount --make-shared / > /etc/local.d/mount-shared.start", # for "WARN[0000] "/" is not a shared mount"
      " chmod +x /etc/local.d/mount-shared.start",
      " echo tun >> /etc/modules",
      " rc-update add local default",
      " rc-update add cgroups default",
      " openrc",
      " if ! ${var.install_docker}; then",
      "  ln -s /usr/bin/podman /usr/bin/docker", // Créer un alias docker -> podman si docker n'est pas installé
      " fi",
      "fi",

      // Nettoyage des fichiers temporaires et de cache
      "rm -rf /var/cache/apk/*",
      "rm -f /tmp/answers.txt",
      "sed -i '/PermitRootLogin yes/d' /etc/ssh/sshd_config"
    ]
  }
      
  // --- B. Post-Processor Vagrant (Create the  Vagrant Box) ---
  post-processor "vagrant" {
     output = "${var.vm_name}.{{ .Provider }}.box"
  }
}

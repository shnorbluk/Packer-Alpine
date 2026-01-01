// -----------------------------------------------------------
// 0. BLOC PACKER (REQUIRED)
// -----------------------------------------------------------
packer {
  required_plugins {
    // Déclare le plugin pour VirtualBox
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = ">= 1.1.3"
    }
    vagrant = {
      version = "~> 1"
      source = "github.com/hashicorp/vagrant"
    }
  }
}

// -----------------------------------------------------------
// 1. DECLARATION DES VARIABLES (OPTIONNEL MAIS RECOMMANDE)
// -----------------------------------------------------------
variable "iso_url" {
  type    = string
  default = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.2-x86_64.iso"
  description = "URL de l'ISO Alpine"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:1b8be1ce264bf50048f2c93d8b4e72dd0f791340090aaed022b366b9a80e3518"
  description = "Checksum SHA256 de l'ISO Alpine"
}

variable "vm_name" {
  type    = string
  default = "alpine-3.23.2"
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
  vm_name             = var.vm_name
  guest_os_type       = "Linux26_64"
  disk_size           = var.disk_size_mb
  headless            = false // Lancer la VM sans interface graphique (plus rapide)

  // Configuration mémoire/CPU via VBoxManage
  vboxmanage          = [
    ["modifyvm", "{{ .Name }}", "--memory", "512"],
    ["modifyvm", "{{ .Name }}", "--cpus", "1"],
    ["modifyvm", "{{ .Name }}", "--accelerate3d", "off"], // Désactiver 3D acceleration si activée
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vboxvga"]  // Spécifie VBoxVGA comme contrôleur graphique
  ]

  // --- C. Configuration SSH (Post-installation) ---
  ssh_username        = "root"
  // Nous définissons le mot de passe dans le fichier 'answers.txt' pour l'installation
  ssh_password        = "p"
  ssh_wait_timeout    = "20m"

  // --- D. Commande de Démarrage (Automatisation de l'Installation) ---
  boot_wait           = "30s"
  boot_command        = [
    "<wait>",
    "root<enter>",
    "ifconfig eth0 up<enter>",
    "udhcpc -i eth0<enter>", // Alpine utilise généralement 'udhcpc'
    "<wait10>", // Attendre 10 secondes pour que l'interface obtienne une adresse IP
    "wget -O /tmp/answers.txt http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers.txt<enter>", // Télécharger le fichier de réponses
    "export ERASE_DISKS=/dev/sda<enter>",
    "setup-alpine -f /tmp/answers.txt<enter>", // Lancer l'installation avec le fichier
    "<wait15>p<enter>p<enter>",
    "<wait20>mount /dev/sda3 /mnt<enter>",
    "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
    "reboot<enter>"                 // Le script setup-alpine demande un reboot à la fin
  ]
  shutdown_command    = "poweroff"
}

// -----------------------------------------------------------
// 3. BLOC BUILD (PROVISIONERS ET POST-PROCESSORS)
// -----------------------------------------------------------
build {
  sources = ["source.virtualbox-iso.alpine"]

  // --- A. Provisioner Shell (Scripts de post-installation) ---
  provisioner "file" {
    source      = "vagrant.pub"
    destination = "/tmp/authorized_keys"
  }

  provisioner "shell" {
    inline = [
      // Mettre à jour et installer les dépendances de base
      "apk update",
      "apk upgrade",
      "apk add virtualbox-guest-additions sudo ${join(" ", var.additional_packages)}",
      "rc-update add virtualbox-guest-additions default",
      "rc-update -u",

      // Configuring SSH for Vagrant user
      "mkdir /home/vagrant/.ssh",
      "mv /tmp/authorized_keys /home/vagrant/.ssh/authorized_keys",
      "chmod 600 /home/vagrant/.ssh/authorized_keys",
      "chown -R vagrant:vagrant /home/vagrant/.ssh",
      "echo vagrant 'ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/vagrant",

      // Changing passwords
      "echo 'root:${var.root_password}' | chpasswd",
      "echo 'vagrant:${var.vagrant_password}' | chpasswd",

      // DOCKER
      "if ${var.install_docker}; then",
      " apk add docker",
      " addgroup vagrant docker",
      " rc-update add docker default",
      " rc-update -u",
      "fi",

      "if ${var.install_podman}; then",
      " apk add podman",
      " echo vagrant:100000:65536 | tee /etc/subuid > /etc/subgid", # for "cannot find UID/GID for user vagrant"
      " echo mount --make-shared / > /etc/local.d/mount-shared.start", # for "WARN[0000] "/" is not a shared mount"
      " chmod +x /etc/local.d/mount-shared.start",
      " mkdir /dev/net; mknod /dev/net/tun c 10 200; chmod 0666 /dev/net/tun", # (https://www.kernel.org/doc/html/latest/networking/tuntap.html) for /usr/bin/slirp4netns failed
      " rc-update add local default",
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
    output = "${var.vm_name}.box"
  }
}

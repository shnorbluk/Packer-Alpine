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
  default = "packer-alpine-3.23.2"
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
  disk_size           = 8192 // 8 GB
  headless            = false // Lancer la VM sans interface graphique (plus rapide)

  // Configuration mémoire/CPU via VBoxManage
  vboxmanage          = [
//    ["modifyvm", "{{ .Name }}", "--memory", "512"],
    ["modifyvm", "{{ .Name }}", "--memory", "4092"],
    ["modifyvm", "{{ .Name }}", "--cpus", "1"],
    ["modifyvm", "{{ .Name }}", "--accelerate3d", "off"], // Désactiver 3D acceleration si activée
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vboxvga"]  // Spécifie VBoxVGA comme contrôleur graphique
  ]

  // --- C. Configuration SSH (Post-installation) ---
  ssh_username        = "root"
  // Nous définissons le mot de passe dans le fichier 'answers.txt' pour l'installation
  ssh_password        = "passwordpass"
  ssh_wait_timeout    = "20m"

  // --- D. Commande de Démarrage (Automatisation de l'Installation) ---
  boot_wait           = "20s"
  boot_command        = [
    "<wait>",
    "root<enter>",
    "ifconfig eth0 up<enter>",
    "udhcpc -i eth0<enter>", // Alpine utilise généralement 'udhcpc'
    "<wait10>", // Attendre 10 secondes pour que l'interface obtienne une adresse IP
    "wget -O /tmp/answers.txt http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers.txt<enter>", // Télécharger le fichier de réponses
    "setup-alpine -f /tmp/answers.txt<enter>", // Lancer l'installation avec le fichier
    "<wait15>passwordpass<enter>passwordpass<enter>",
    "<wait20>y<enter>",
    "<wait20>mount /dev/sda3 /mnt<enter>",
    "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
    "reboot<enter>",                 // Le script setup-alpine demande un reboot à la fin
//    "<wait>"
  ]
  shutdown_command    = "poweroff"
}

// -----------------------------------------------------------
// 3. BLOC BUILD (PROVISIONERS ET POST-PROCESSORS)
// -----------------------------------------------------------
build {
  sources = ["source.virtualbox-iso.alpine"]

  // --- A. Provisioner Shell (Scripts de post-installation) ---
  provisioner "shell" {
    inline = [
      // Mettre à jour et installer les dépendances de base
      "apk update",
      "apk upgrade",
      "apk add open-vm-tools", // open-vm-tools pour VirtualBox/VMware

      // Nettoyage des fichiers temporaires et de cache
      "rm -rf /var/cache/apk/*",
      "rm -f /tmp/answers.txt",
    ]
  }

  // --- B. Post-Processor Vagrant (Cr�er la Box Vagrant) ---
  post-processor "vagrant" {
    output = "alpine-${var.vm_name}.box"
  }
}

# =============================================================================
# Packer Template: VyOS
# =============================================================================
# Builds a Proxmox VM template for VyOS with:
#   - VirtIO drivers (in-kernel)
#   - QEMU Guest Agent
#   - Minimal base configuration
# =============================================================================

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "cdx-pve-01"
}

variable "proxmox_storage_pool" {
  type    = string
  default = "QNAP"
}

variable "iso_file" {
  type        = string
  description = "Proxmox storage path to VyOS ISO"
}

variable "template_vm_id" {
  type    = number
  default = 2023
}

variable "template_name" {
  type    = string
  default = "cdx-vyos-base"
}

source "proxmox-iso" "vyos" {
  # Proxmox connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  pool                     = "CDX_TEMPLATES"

  # VM identification
  vm_id         = var.template_vm_id
  vm_name       = var.template_name
  template_name = var.template_name

  # ISO source
  iso_file = var.iso_file

  # Hardware - lightweight router
  memory   = 1024
  cores    = 1
  sockets  = 1
  cpu_type = "host"
  os       = "l26"

  # Storage - VirtIO SCSI
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "8G"
    storage_pool = var.proxmox_storage_pool
    format       = "raw"
  }

  # Network - VirtIO
  network_adapters {
    model    = "virtio"
    bridge   = "Layer0"
    firewall = false
  }

  # Display - serial console (no SPICE needed for routers)
  vga {
    type = "serial0"
  }
  serials = ["socket"]

  # QEMU Guest Agent
  qemu_agent = true

  # VyOS install sequence
  boot_wait = "10s"
  boot_command = [
    "vyos<enter><wait5>",
    "vyos<enter><wait5>",
    "install image<enter><wait3>",
    "<enter><wait>",  # Would you like to continue? (Yes)
    "<enter><wait>",  # Partition (Auto)
    "<enter><wait>",  # Install the image on? (sda)
    "y<enter><wait>", # Continue destroying all data on sda?
    "<enter><wait>",  # How big of a root partition? (default)
    "<enter><wait>",  # Image name (default)
    "<enter><wait>",  # Directory to copy config from (default)
    "vyos<enter>",    # Password for administrator account
    "vyos<enter>",    # Retype password
    "<enter><wait>",  # GRUB partition (default)
    "reboot<enter><wait30>",
    "vyos<enter><wait3>",
    "vyos<enter><wait5>"
  ]

  # Communicator - SSH
  communicator           = "ssh"
  ssh_username           = "vyos"
  ssh_password           = "vyos"
  ssh_timeout            = "20m"
  ssh_handshake_attempts = 20
}

build {
  sources = ["source.proxmox-iso.vyos"]

  # Enable QEMU guest agent in VyOS config
  provisioner "shell" {
    inline = [
      "source /opt/vyatta/etc/functions/script-template",
      "configure",
      "set service qemu-guest-agent",
      "set service ssh port 22",
      "commit",
      "save",
      "exit"
    ]
  }
  # ── Strip management NICs (shell-local: runs on Packer build host) ─────────
  # Removes all net* devices from the build VM via the Proxmox API before
  # Packer converts the VM to a template. Terraform owns all NIC definitions.
  provisioner "shell-local" {
    environment_vars = [
      "PROXMOX_API_URL=${var.proxmox_api_url}",
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "TEMPLATE_VMID=${var.template_vm_id}",
    ]
    inline = ["bash ../scripts/common/strip-nics.sh"]
  }
}

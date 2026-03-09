# =============================================================================
# Packer Template: CentOS 7
# =============================================================================
# Builds a Proxmox VM template for CentOS 7 with:
#   - VirtIO drivers (in-kernel)
#   - QEMU Guest Agent
#   - SPICE agent (spice-vdagent)
#   - CDX base config (cdxadmin account, SSH)
#
# Supports both Server (minimal) and GNOME Desktop variants via
# the kickstart_file variable.
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
  description = "Proxmox storage path to CentOS 7 ISO"
}

variable "template_vm_id" {
  type    = number
  default = 2043
}

variable "template_name" {
  type    = string
  default = "cdx-centos7-server"
}

variable "kickstart_file" {
  type    = string
  default = "ks-server.cfg"
}

variable "memory" {
  type    = number
  default = 2048
}

source "proxmox-iso" "centos-7" {
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

  # Hardware
  memory   = var.memory
  cores    = 2
  sockets  = 1
  cpu_type = "host"
  os       = "l26"

  # Storage - VirtIO SCSI (drivers in-kernel)
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "32G"
    storage_pool = var.proxmox_storage_pool
    format       = "raw"
  }

  # Network - VirtIO (drivers in-kernel)
  network_adapters {
    model    = "virtio"
    bridge   = "Layer0"
    firewall = true
  }

  # Display - QXL for SPICE
  vga {
    type   = "qxl"
    memory = 32
  }

  # QEMU Guest Agent
  qemu_agent = true

  # Kickstart via Packer HTTP server
  http_directory = "../http"
  boot_wait      = "5s"
  boot_command = [
    "<tab> inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kickstart/centos7/${var.kickstart_file}<enter>"
  ]

  # Communicator - SSH
  communicator           = "ssh"
  ssh_username           = "cdxadmin"
  ssh_password           = "IyTt+,uDhtR@.303"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20
}

build {
  sources = ["source.proxmox-iso.centos-7"]

  # Install QEMU guest agent and SPICE agent
  provisioner "shell" {
    script          = "../scripts/linux/install-qemu-guest-agent-yum.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # Cleanup for template generalization
  provisioner "shell" {
    script          = "../scripts/linux/cleanup-yum.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
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

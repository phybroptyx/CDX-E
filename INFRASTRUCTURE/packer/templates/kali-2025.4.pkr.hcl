# =============================================================================
# Packer Template: Kali Linux 2025.4
# =============================================================================
# Builds a Proxmox VM template for Kali Linux 2025.4 with:
#   - VirtIO drivers (in-kernel)
#   - QEMU Guest Agent
#   - SPICE agent (spice-vdagent)
#   - CDX base config (cdxadmin account, SSH)
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
  description = "Proxmox storage path to Kali Linux 2025.4 ISO"
}

variable "template_vm_id" {
  type    = number
  default = 2039
}

variable "template_name" {
  type    = string
  default = "cdx-kali-base"
}

source "proxmox-iso" "kali-2025-4" {
  # Proxmox connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # VM identification
  vm_id         = var.template_vm_id
  vm_name       = var.template_name
  template_name = var.template_name

  # ISO source
  iso_file = var.iso_file

  # Hardware
  memory   = 4096
  cores    = 2
  sockets  = 1
  cpu_type = "host"
  os       = "l26"

  # Storage - VirtIO SCSI (drivers in-kernel)
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "40G"
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

  # Preseed via Packer HTTP server
  http_directory = "../http"
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "/install.amd/vmlinuz ",
    "initrd=/install.amd/initrd.gz ",
    "auto=true ",
    "priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed/kali/preseed.cfg ",
    "locale=en_US.UTF-8 ",
    "keymap=us ",
    "hostname=kali-template ",
    "domain=cdx.lab ",
    "--- <enter>"
  ]

  # Communicator - SSH
  communicator           = "ssh"
  ssh_username           = "cdxadmin"
  ssh_password           = "IyTt+,uDhtR@.303"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20
}

build {
  sources = ["source.proxmox-iso.kali-2025-4"]

  # Install QEMU guest agent and SPICE agent
  provisioner "shell" {
    script          = "../scripts/linux/install-qemu-guest-agent.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # Cleanup for template generalization
  provisioner "shell" {
    script          = "../scripts/linux/cleanup.sh"
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
    script = "../scripts/common/strip-nics.sh"
  }
}

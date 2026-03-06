# =============================================================================
# Packer Template: Debian 12 (Bookworm)
# =============================================================================
# Builds a minimal Proxmox VM template for Debian 12.9 with:
#   - VirtIO drivers (in-kernel since 2.6.x — no separate ISO needed)
#   - QEMU Guest Agent
#   - Python3 (Ansible target capability)
#   - OpenSSH server (key-based access only after first boot)
#   - No desktop environment, no GUI packages
#
# Primary use: General-purpose minimal Debian infrastructure nodes
# (C2 servers, sensors, legacy-compatibility targets, etc.).
#
# Post-build template state:
#   - Debian 12 minimal install (no GUI)
#   - VirtIO SCSI and network drivers active
#   - QEMU Guest Agent running
#   - SSH enabled (password auth, hardened post-clone via Ansible)
#   - cdxadmin account with NOPASSWD sudo
#   - Python3 available (Ansible managed node requirement)
#   - hostname: debian-template (overridden at VM deployment by Ansible)
#
# Boot mode: BIOS (SeaBIOS)
#
# Build command (manual, run from INFRASTRUCTURE/packer/templates/):
#   packer build \
#     -var-file=../vars/common.pkrvars.hcl \
#     -var-file=../vars/debian_12.pkrvars.hcl \
#     debian-12.pkr.hcl
#   (set PKR_VAR_proxmox_api_token_secret in environment)
#
# Preseed: INFRASTRUCTURE/packer/http/preseed/debian-12/preseed.cfg
#   Served by the Packer HTTP server during install.
# =============================================================================

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# =============================================================================
# Variables — Proxmox connection
# =============================================================================
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

# =============================================================================
# Variables — ISO
# =============================================================================
variable "iso_file" {
  type        = string
  description = "Proxmox storage path to Debian 12 ISO. Example: QNAP:iso/debian-12.9.0-amd64-netinst.iso"
}

# =============================================================================
# Variables — VM specification
# =============================================================================
variable "template_vm_id" {
  type    = number
  default = 2038
}

variable "template_name" {
  type    = string
  default = "cdx-debian129-base"
}

# =============================================================================
# Source — proxmox-iso builder
# =============================================================================
source "proxmox-iso" "debian-12" {
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
  template_description = "CDX Debian 12.9 minimal base template — built by Packer on ${timestamp()}"

  # ISO source
  iso_file    = var.iso_file
  unmount_iso = true

  # Hardware — minimal (relay / infrastructure role)
  memory   = 2048
  cores    = 2
  sockets  = 1
  cpu_type = "x86-64-v2-AES"
  os       = "l26"

  # Storage — VirtIO SCSI (in-kernel drivers, no separate VirtIO ISO needed)
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = var.proxmox_storage_pool
    format       = "qcow2"
    cache_mode   = "writeback"
  }

  # Network — VirtIO (in-kernel drivers)
  network_adapters {
    model    = "virtio"
    bridge   = "Layer0"
    firewall = false
  }

  # QEMU Guest Agent — installed via preseed late_command
  qemu_agent = true

  # Preseed via Packer HTTP server
  # The Packer HTTP server serves INFRASTRUCTURE/packer/http/ during the build.
  # The Debian installer fetches preseed.cfg from the URL passed in boot_command.
  http_directory = "../http"

  # Boot command — Debian 12 netinst BIOS boot
  # Escapes to command line, passes preseed URL and suppresses interactive prompts.
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "/install.amd/vmlinuz ",
    "initrd=/install.amd/initrd.gz ",
    "auto=true ",
    "priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed/debian-12/preseed.cfg ",
    "locale=en_US.UTF-8 ",
    "keymap=us ",
    "hostname=debian-template ",
    "domain=cdx.lab ",
    "--- quiet<enter>"
  ]

  # Communicator — SSH
  # cdxadmin account created by preseed; hardened post-clone by Ansible.
  communicator           = "ssh"
  ssh_username           = "cdxadmin"
  ssh_password           = "IyTt+,uDhtR@.303"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20
}

# =============================================================================
# Build
# =============================================================================
build {
  sources = ["source.proxmox-iso.debian-12"]

  # Install QEMU guest agent and perform template cleanup
  provisioner "shell" {
    script          = "../scripts/linux/install-qemu-guest-agent.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

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

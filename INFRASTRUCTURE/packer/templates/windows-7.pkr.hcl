# =============================================================================
# Packer Template: Windows 7 SP1
# =============================================================================
# Builds a Proxmox VM template for Windows 7 SP1 with:
#   - VirtIO drivers (SCSI, network, balloon) — virtio-win 0.1.160
#   - QEMU Guest Agent
#   - SPICE agent (QXL display)
#   - WMF 3.0 (PowerShell 3.0) upgrade
#   - CDX base config (cdxadmin account, WinRM, RDP, ICMP)
#   - Sysprep generalized with OOBE-bypass unattend
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
  description = "Proxmox storage path to Windows 7 SP1 ISO"
}

variable "virtio_iso_file" {
  type        = string
  description = "Proxmox storage path to VirtIO-Win ISO (0.1.160 for Windows 7)"
}

variable "template_vm_id" {
  type    = number
  default = 2025
}

variable "template_name" {
  type    = string
  default = "cdx-win7-base"
}

source "proxmox-iso" "windows-7" {
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

  # ISO sources
  iso_file = var.iso_file
  additional_iso_files {
    device           = "sata1"
    iso_file         = var.virtio_iso_file
    unmount          = true
    iso_checksum     = "none"
  }
  additional_iso_files {
    device           = "sata2"
    cd_files         = ["../http/autounattend/win7/autounattend.xml"]
    cd_label         = "OEMDRV"
    iso_storage_pool = var.proxmox_storage_pool
  }

  # Hardware
  memory   = 4096
  cores    = 2
  sockets  = 1
  cpu_type = "host"
  os       = "win7"  # Proxmox OS type for Windows 7

  # Storage - VirtIO SCSI
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "60G"
    storage_pool = var.proxmox_storage_pool
    format       = "raw"
  }

  # Network - VirtIO
  network_adapters {
    model    = "virtio"
    bridge   = "Layer0"
    firewall = true
  }

  # Display - QXL for SPICE
  vga {
    type   = "std"
    memory = 32
  }

  # QEMU Guest Agent
  qemu_agent = true

  # Unattended install
  http_directory = "../http"
  boot_wait      = "5s"
  boot_command   = ["<spacebar>"]

  # Communicator - WinRM
  communicator   = "winrm"
  winrm_username = "cdxadmin"
  winrm_password = "IyTt+,uDhtR@.303"
  winrm_timeout  = "60m"
  winrm_use_ssl  = false
}

build {
  sources = ["source.proxmox-iso.windows-7"]

  # Install VirtIO guest tools (includes QEMU GA, balloon, SPICE agent)
  provisioner "powershell" {
    script = "../scripts/windows/install-virtio-guest-tools.ps1"
  }

  # Install WMF 3.0 (PowerShell 3.0) — required for modern cmdlets
  provisioner "powershell" {
    script = "../scripts/windows/install-wmf3.ps1"
  }

  # Reboot to complete WMF 3.0 installation
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # CDX base config (cdxadmin account, WinRM, RDP, ICMP)
  provisioner "powershell" {
    script = "../scripts/windows/configure-base.ps1"
  }

  # Sysprep and generalize (embeds OOBE-bypass unattend)
  provisioner "powershell" {
    script = "../scripts/windows/sysprep.ps1"
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

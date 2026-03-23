# =============================================================================
# Packer Template: Windows Server 2008 R2
# =============================================================================
# Builds a Proxmox VM template for Windows Server 2008 R2 with:
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
  default = "raid"
}

variable "iso_file" {
  type        = string
  description = "Proxmox storage path to Windows Server 2008 R2 ISO"
}

variable "template_vm_id" {
  type    = number
  default = 2024
}

variable "template_name" {
  type    = string
  default = "cdx-win2008r2-base"
}

source "proxmox-iso" "windows-server-2008r2" {
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
    device           = "sata2"
    cd_files         = ["../http/autounattend/win2008r2/autounattend.xml"]
    cd_label         = "OEMDRV"
    iso_storage_pool = var.proxmox_storage_pool
  }

  # Hardware
  memory   = 16384
  cores    = 4
  sockets  = 1
  cpu_type = "host"
  os       = "win7"  # Proxmox OS type for 2008 R2

  # Storage - VirtIO SCSI
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "60G"
    storage_pool = "raid"
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
  # winrm_host is set to the static build IP configured in specialize,
  # bypassing QEMU guest agent IP discovery (GA is not running until
  # provisioners complete the full SP1→.NET→WMF→GA chain).
  communicator   = "winrm"
  winrm_host     = "10.0.0.5"
  winrm_username = "cdxadmin"
  winrm_password = "IyTt+,uDhtR@.303"
  winrm_timeout  = "240m"
  winrm_use_ssl  = false
}

build {
  sources = ["source.proxmox-iso.windows-server-2008r2"]

  # ---------------------------------------------------------------------------
  # Bootstrap (winrm-bootstrap.cmd, CDX ISO D:\) runs via FirstLogonCommands
  # BEFORE Packer connects. UAC disabled in specialize → full elevated token.
  #
  # specialize pass: .NET 4.0 → WMF 3.0 → managed reboot → oobeSystem
  # FirstLogonCommands: cert pre-trust → QEMU drivers → SPICE pass1 →
  #   QEMU GA → SPICE pass2 → ICMP/RDP/cdxadmin → static IP → WinRM → sentinel
  #
  # configure-base.ps1 is NOT run — bootstrap covers all base config.
  # sysprep.ps1 generalizes the VM and shuts it down asynchronously;
  # shell-local provisioners run after Packer receives completion.
  # migrate-template-disk polls for VM stopped state before disk move.
  # ---------------------------------------------------------------------------

  # Sysprep and generalize (embeds OOBE-bypass unattend)
  provisioner "powershell" {
    pause_before = "5s"
    script       = "../scripts/windows/sysprep.ps1"
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

  # ── Migrate primary disk to QNAP (shell-local: runs on Packer build host) ──
  # Moves scsi0 from 'raid' (fast build storage) to 'QNAP' (template storage)
  # after the async shutdown provisioner stops the VM. Runs before Packer converts to template.
  provisioner "shell-local" {
    environment_vars = [
      "PROXMOX_API_URL=${var.proxmox_api_url}",
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "TEMPLATE_VMID=${var.template_vm_id}",
      "TARGET_STORAGE=QNAP",
    ]
    inline = ["bash ../scripts/common/migrate-template-disk.sh"]
  }
}

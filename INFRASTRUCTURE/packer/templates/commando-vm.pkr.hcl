# =============================================================================
# CDX-E Packer Template: Commando VM
# =============================================================================
# Builds the Commando VM offensive security toolkit template on Proxmox VE.
# Uses the proxmox-clone source — clones the Windows 10 base template (VMID
# 2035, cdx-win10-base) and installs the Commando VM toolset on top via
# PowerShell provisioner.
#
# Prerequisites:
#   The Windows 10 base template (VMID 2035) must already be built and
#   registered in Proxmox before running this build. Build windows-10.pkr.hcl
#   first if the template does not exist.
#
# Post-build template state:
#   - Windows 10 Pro with Commando VM toolset installed
#   - All base template configuration (VirtIO drivers, QEMU GA, WinRM) intact
#   - Additional Red Team tools installed (see Commando VM installer)
#   - hostname: CDX-TEMPLATE (overridden at VM deployment by Ansible)
#   - NO exercise-specific configuration
#
# Disk: 80G (expanded from the 40G base — tool-heavy install requires space)
#
# Build command (manual, run from INFRASTRUCTURE/packer/templates/):
#   packer build \
#     -var-file=../vars/common.pkrvars.hcl \
#     -var-file=../vars/commando_vm.pkrvars.hcl \
#     -var "proxmox_api_token_id=ansible@pam!ansible" \
#     commando-vm.pkr.hcl
#   (set PKR_VAR_proxmox_api_token_secret and PKR_VAR_winrm_password in environment)
#
# Timing notes:
#   Commando VM installs hundreds of packages via Chocolatey. The provisioner
#   timeout is 2h. On slow internet links the build may exceed this limit —
#   consider pre-caching Chocolatey packages or increasing winrm_timeout.
# =============================================================================

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# =============================================================================
# Variables — Proxmox connection
# =============================================================================
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API endpoint. Example: https://cdx-pve-01:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type        = string
  sensitive   = true
  description = "Proxmox API token in user@realm!tokenid format."
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret UUID. Injected via PKR_VAR_proxmox_api_token_secret."
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox cluster node to run the build VM on."
}

# =============================================================================
# Variables — Storage
# =============================================================================
variable "template_storage" {
  type        = string
  default     = "QNAP"
  description = "Proxmox storage pool where the finished template disk is registered."
}

variable "pool" {
  type        = string
  default     = "CDX_TEMPLATES"
  description = "Proxmox resource pool the finished template is assigned to."
}

# =============================================================================
# Variables — Clone source
# =============================================================================
variable "clone_vm_id" {
  type        = number
  default     = 2035
  description = "VMID of the source template to clone. Must be the Windows 10 base (cdx-win10-base)."
}

# =============================================================================
# Variables — VM specification
# =============================================================================
variable "vm_id" {
  type        = number
  default     = 2039
  description = "Proxmox VMID for the new Commando VM template."
}

variable "vm_name" {
  type        = string
  default     = "cdx-commandovm-base"
  description = "Proxmox VM/template name. Must match template_registry.commando_vm.proxmox_name."
}

variable "cores" {
  type        = number
  default     = 2
  description = "vCPU cores for the build VM."
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM (MB) for the build VM."
}

variable "disk_size" {
  type        = string
  default     = "80G"
  description = "Root disk size. 80G accommodates the large Commando VM tool set."
}

variable "disk_type" {
  type        = string
  default     = "qcow2"
  description = "Disk image format."
}

variable "disk_cache_mode" {
  type        = string
  default     = "writeback"
  description = "Disk cache mode used during the build."
}

# =============================================================================
# Variables — Authentication
# =============================================================================
variable "winrm_username" {
  type        = string
  default     = "Administrator"
  description = "Windows administrator account (inherited from Windows 10 base template)."
}

variable "winrm_password" {
  type        = string
  sensitive   = true
  description = "Administrator password (must match the Windows 10 base template password). Injected via PKR_VAR_winrm_password."
}

# =============================================================================
# Source — proxmox-clone builder
# =============================================================================
source "proxmox-clone" "commando_vm" {

  # ── Proxmox connection ──────────────────────────────────────────────────────
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # ── Clone source ────────────────────────────────────────────────────────────
  # Full clone so tool installation does not affect the Windows 10 base template.
  clone_vm_id = var.clone_vm_id
  full_clone  = true

  # ── VM identity ─────────────────────────────────────────────────────────────
  vm_id   = var.vm_id
  vm_name = var.vm_name
  pool    = var.pool

  # ── Template registration ───────────────────────────────────────────────────
  template_name        = var.vm_name
  template_description = "CDX Commando VM (Win10 base + offensive toolset) — built by Packer on ${timestamp()}"

  # ── QEMU Guest Agent ────────────────────────────────────────────────────────
  # Inherited from clone. Declared explicitly to confirm expected state.
  qemu_agent = true

  # ── Hardware ────────────────────────────────────────────────────────────────
  # Override cores/memory for the tool-install phase.
  cpu_type = "x86-64-v2-AES"
  cores    = var.cores
  memory   = var.memory

  # ── Disk resize ─────────────────────────────────────────────────────────────
  # The cloned disk starts at 40G (from the Win10 base). Resize to 80G to
  # accommodate the Commando VM tool chain. Proxmox handles the resize on
  # the cloned disk before Packer starts the VM.
  disks {
    disk_size    = var.disk_size
    format       = var.disk_type
    storage_pool = var.template_storage
    type         = "scsi"
    cache_mode   = var.disk_cache_mode
  }

  # ── Network ─────────────────────────────────────────────────────────────────
  # Management NIC. CDX-I provides the internet route for Chocolatey downloads.
  network_adapters {
    model  = "virtio"
    bridge = "Layer0"
  }

  # ── WinRM communicator ──────────────────────────────────────────────────────
  # Extended timeout (2h) — Commando VM installs 100+ packages via Chocolatey.
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "2h"
  winrm_use_ssl  = false
  winrm_insecure = true
}

# =============================================================================
# Build
# =============================================================================
build {
  sources = ["source.proxmox-clone.commando_vm"]

  # ── Commando VM installation ─────────────────────────────────────────────────
  # Downloads and runs the official Commando VM installer from the FireEye/
  # Mandiant GitHub repository. The installer uses Chocolatey to deploy tools.
  # The CDX-I virtual internet provides outbound connectivity for downloads.
  #
  # Note: Commando VM installation triggers a reboot mid-way. The installer
  # resumes automatically via a Run key. Packer reconnects via WinRM after
  # the reboot (within winrm_timeout). The final `done` file signals completion.
  provisioner "powershell" {
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
    inline = [
      "Write-Host '=== CDX-E Commando VM installation starting ==='",

      # Set execution policy
      "Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force",

      # Download the Commando VM installer
      "$installerUrl = 'https://raw.githubusercontent.com/mandiant/commando-vm/main/install.ps1'",
      "$installerPath = 'C:\\Windows\\Temp\\commando-install.ps1'",
      "Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing",

      # Run installer non-interactively with password pre-accepted
      "& $installerPath -nochecks 1 -password $env:PKR_VAR_winrm_password",

      "Write-Host '=== Commando VM installation complete ==='",
    ]
  }

  # ── Post-install verification ─────────────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "Write-Host '=== CDX-E Commando VM post-install check ==='",
      "Write-Host ('OS: ' + (Get-WmiObject Win32_OperatingSystem).Caption)",
      "Write-Host ('WinRM: ' + (Get-Service WinRM).Status)",
      "Write-Host ('QEMU GA: ' + (Get-Service QEMU-GA -ErrorAction SilentlyContinue).Status)",
      "Write-Host ('Chocolatey: ' + (choco --version 2>$null))",
      "Write-Host '=== Post-install check complete ==='",
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
      "TEMPLATE_VMID=${var.vm_id}",
    ]
    script = "../scripts/common/strip-nics.sh"
  }
}

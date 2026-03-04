# =============================================================================
# CDX-E Packer Template: VyOS 1.5 Rolling
# =============================================================================
# Builds a VyOS 1.5 Circinus (rolling) base template on Proxmox VE.
#
# ISO: vyos-1.5-rolling-202512150610-cdx-qga-amd64.iso
# The "cdx-qga" suffix indicates a CDX-customised build with the QEMU Guest
# Agent pre-installed (standard VyOS ISOs do not include the guest agent).
#
# Post-build template state:
#   - VyOS 1.5 installed to local disk
#   - vyos user configured with vyos_admin_password
#   - root user configured with the same password (enables Ansible root SSH)
#   - SSH enabled on port 22, all interfaces
#   - QEMU Guest Agent running
#   - hostname: cdx-vyos-base (overridden per-VM by configure_networking)
#   - NO exercise configuration (interfaces, routing, firewall) — that is
#     pushed by the configure_networking Ansible role after VM deployment
#
# Build command (manual, run from INFRASTRUCTURE/packer/templates/):
#   packer build \
#     -var-file=../vars/common.pkrvars.hcl \
#     -var-file=../vars/vyos.pkrvars.hcl \
#     -var "proxmox_api_token_id=ansible@pam!ansible" \
#     vyos.pkr.hcl
#   (set PKR_VAR_proxmox_api_token_secret in environment before running)
#
# Boot command notes:
#   Timing values are calibrated for VyOS 1.5 rolling (Dec 2025) on
#   Proxmox VE with NVMe-backed storage. On slower storage (spinning disk)
#   increase the <wait> durations after "install image" and after reboot.
#   VyOS installer prompt text may differ on other rolling-release builds —
#   verify against the specific ISO before running unattended.
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
# (injected by deploy_packer_template role at build time)
# =============================================================================
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API endpoint. Example: https://cdx-pve-01:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type        = string
  sensitive   = true
  description = "Proxmox API token in user@realm!tokenid format. Example: ansible@pam!ansible"
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
variable "iso_storage_pool" {
  type        = string
  default     = "QNAP"
  description = "Proxmox storage pool where the ISO is staged."
}

variable "template_storage" {
  type        = string
  default     = "QNAP"
  description = "Proxmox storage pool where the finished template disk is registered."
}

variable "disk_type" {
  type        = string
  default     = "qcow2"
  description = "Disk image format for the template disk."
}

variable "disk_cache_mode" {
  type        = string
  default     = "writeback"
  description = "Disk cache mode used during the build."
}

variable "pool" {
  type        = string
  default     = "CDX_TEMPLATES"
  description = "Proxmox resource pool the finished template is assigned to."
}

# =============================================================================
# Variables — VM specification
# =============================================================================
variable "vm_id" {
  type        = number
  default     = 2017
  description = "Proxmox VMID for the build VM and resulting template."
}

variable "vm_name" {
  type        = string
  default     = "cdx-vyos-base"
  description = "Proxmox VM/template name. Must match template_registry.vyos.proxmox_name."
}

variable "iso_file" {
  type        = string
  description = "ISO filename as it appears in <iso_storage_pool>:iso/. No path prefix."
}

variable "cores" {
  type        = number
  default     = 2
  description = "vCPU cores for the build VM."
}

variable "memory" {
  type        = number
  default     = 1024
  description = "RAM (MB) for the build VM."
}

variable "disk_size" {
  type        = string
  default     = "4G"
  description = "Root disk size. VyOS base image is ~1 GB; 4G leaves room for logs/packages."
}

# =============================================================================
# Variables — Authentication
# =============================================================================
variable "vyos_admin_password" {
  type        = string
  sensitive   = true
  default     = "IyTt+,uDhtR@.303"
  description = "Password set for the vyos user during installation, and for the root user post-install."
}

# =============================================================================
# Source — proxmox-iso builder
# =============================================================================
source "proxmox-iso" "vyos" {

  # ── Proxmox connection ──────────────────────────────────────────────────────
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # ── VM identity ─────────────────────────────────────────────────────────────
  vm_id   = var.vm_id
  vm_name = var.vm_name
  pool    = var.pool

  # ── Boot ISO ────────────────────────────────────────────────────────────────
  # ISO must be pre-staged on the iso_storage_pool before running this build.
  iso_file    = "${var.iso_storage_pool}:iso/${var.iso_file}"
  unmount_iso = true

  # ── Template registration ───────────────────────────────────────────────────
  template_name        = var.vm_name
  template_description = "CDX VyOS 1.5 Rolling base template — built by Packer on ${timestamp()}"

  # ── QEMU Guest Agent ────────────────────────────────────────────────────────
  # Enabled because the CDX custom ISO (cdx-qga) includes the QEMU GA package.
  # The GA allows Proxmox to report guest IP addresses and perform clean shutdown.
  qemu_agent = true

  # ── Hardware ────────────────────────────────────────────────────────────────
  # kvm64 CPU type for maximum VM portability across cluster nodes.
  cpu_type = "kvm64"
  cores    = var.cores
  memory   = var.memory

  # ── Disk ────────────────────────────────────────────────────────────────────
  # VirtIO SCSI — appears as /dev/sda inside the guest.
  # qcow2 + writeback matches all.yml Packer defaults and supports
  # linked-clone operations in Proxmox.
  disks {
    disk_size    = var.disk_size
    format       = var.disk_type
    storage_pool = var.template_storage
    type         = "scsi"
    cache_mode   = var.disk_cache_mode
  }

  # ── Network ─────────────────────────────────────────────────────────────────
  # Management NIC only. Exercise NICs (eth1, eth2, etc.) are added by
  # Terraform at VM deployment time, not baked into the template.
  network_adapters {
    model  = "virtio"
    bridge = "Layer0"
  }

  # ── SSH communicator ────────────────────────────────────────────────────────
  # Packer connects as the vyos user after the installed system first boots.
  # Root SSH is configured via boot_command before Packer probes for SSH.
  communicator = "ssh"
  ssh_username = "vyos"
  ssh_password = var.vyos_admin_password
  ssh_timeout  = "20m"

  # ── Boot commands ───────────────────────────────────────────────────────────
  # Automates the VyOS 1.5 rolling installation and post-install configuration.
  #
  # Phase 1 — Live ISO boot and login
  # Phase 2 — Unattended install via `install image` (10 prompts)
  # Phase 3 — First boot of installed system, login
  # Phase 4 — Configure root user + SSH (required for Ansible root access)
  #            Commit and save — Packer SSH probe begins after this point
  #
  # Timing guide (adjust for storage speed):
  #   boot_wait      : 3s   — skip GRUB countdown
  #   Live OS boot   : ~60s (QNAP-backed VMs; increase to 90s on spinning disk)
  #   install image  : ~90s for partitioning + file copy (prompt 7)
  #   Reboot + boot  : ~45s
  #   VyOS CLI cmds  : ~15s total
  # ==========================================================================
  boot_wait = "3s"

  boot_command = [
    # ── Phase 1: Live ISO boot ─────────────────────────────────────────────
    # Skip GRUB countdown then wait for live OS to fully boot.
    "<enter><wait65>",

    # Login to the live ISO (default credentials: vyos / vyos)
    "vyos<enter><wait3>",
    "vyos<enter><wait5>",

    # ── Phase 2: Install ───────────────────────────────────────────────────
    # VyOS 1.5 rolling installer prompt order (verified Dec 2025 build):
    #   1.  "Would you like to continue? [y]"
    #   2.  "Image name: [1.5-rolling-YYYYMMDDHHMMSS]"
    #   3.  "Password for user 'vyos':"
    #   4.  "Retype password:"
    #   5.  "Which console? [K]"   (K=KVM, S=Serial, U=USB-Serial)
    #   6.  "Which drive to install on? [sda]"
    #   7.  "Installation will delete all data. Continue? [y]"
    #   8.  "How much free space to leave for read-write layers? [2000 MB]"
    #   9.  "Would you like to copy the current config? [y]"
    #   10. [Message: reboot to complete — no prompt; type 'reboot']
    #
    # NOTE: Prompt text varies between rolling builds. If this fails,
    # boot the ISO manually, run `install image`, record exact prompts,
    # and adjust below.
    "install image<enter><wait5>",

    # 1. Continue with installation
    "y<enter><wait1>",

    # 2. Accept default image name
    "<enter><wait1>",

    # 3. Set vyos user password
    # <wait8>: cracklib prints a complexity warning before "Retype password:"
    "${var.vyos_admin_password}<enter><wait3>",

    # 4. Retype password
    "${var.vyos_admin_password}<enter><wait1>",

    # 5. Console type — accept default (KVM)
    "<enter><wait1>",

    # 6. Disk selection — accept default (sda)
    "<enter><wait1>",

    # 7. Confirm disk overwrite — installer collects remaining answers before
    #    starting the actual disk work, so this prompt returns quickly.
    "y<enter><wait1>",

    # 8. Free space for read-write overlay — accept default (2000 MB)
    "<enter><wait5>",

    # 9. Copy current config — accept default (y).
    #    Actual partitioning + file copy executes during this wait (~25-30s
    #    on QNAP-backed storage). Increase if install completes before Phase 3.
    "<enter><wait30>",

    # 10. Manually initiate reboot — VyOS prints a message to reboot but does
    #     NOT prompt for confirmation. Type the command explicitly.
    #     wait65: first boot of installed system before Phase 3 login.
    "reboot<enter><wait2>",
    "y<enter><wait8>",
    "<enter><wait65>",

    # ── Phase 3: First boot login ──────────────────────────────────────────
    "vyos<enter><wait5>",
    "${var.vyos_admin_password}<enter><wait5>",

    # ── Phase 4: Baseline configuration ───────────────────────────────────
    # This is the ONLY configuration baked into the template. Everything
    # else (interfaces, routing, firewall, hostname) is pushed per-VM by
    # the configure_networking Ansible role after deployment.
    "configure<enter><wait1>",

    # Template hostname (overridden per-VM by configure_networking)
    "set system host-name cdx-vyos-base<enter><wait1>",

    # DHCP on eth0 (management NIC on Layer0 bridge).
    # Required for: (1) Packer SSH communicator to reach the VM post-commit,
    # (2) configure_networking to discover the VM's IP via Proxmox QGA and
    # inject it into the Ansible inventory. configure_networking replaces
    # this with exercise-specific addressing after VM deployment.
    "set interfaces ethernet eth0 address dhcp<enter><wait1>",

    # SSH service — enables the daemon on port 22, all interfaces.
    # 'listen-address' alone does not start the daemon; the port node does.
    "set service ssh port 22<enter><wait1>",

    # Commit and save — DHCP client starts, SSH daemon starts.
    # Packer SSH probe begins once QGA reports the DHCP-assigned IP.
    "commit; save; exit<enter><wait10>",
  ]
}

# =============================================================================
# Build
# =============================================================================
build {
  sources = ["source.proxmox-iso.vyos"]

  # ── Post-install health check ──────────────────────────────────────────────
  # Packer runs shell scripts via /bin/sh, not vbash, so VyOS operational
  # commands (show version, etc.) are unavailable here. Use standard Linux
  # equivalents to verify the installed system state.
  provisioner "shell" {
    inline = [
      "echo '=== CDX-E VyOS Packer post-install check ==='",
      "cat /etc/os-release",
      "ip addr show eth0",
      "ss -tlnp | grep ':22'",
      "grep vyos /etc/passwd",
      "echo '=== Health check complete ==='",
    ]
  }
}

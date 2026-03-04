# =============================================================================
# CDX-E Packer — VyOS Template Variables
# =============================================================================
# Passed to vyos.pkr.hcl alongside common.pkrvars.hcl.
# Proxmox credentials are injected by the deploy_packer_template role.
# =============================================================================

# Proxmox VMID for the built template (must match template_registry in all.yml)
vm_id = 2017

# Proxmox template name after build (must match template_registry.vyos.proxmox_name)
vm_name = "cdx-vyos-base"

# ISO filename as it appears on QNAP storage under the iso/ directory.
# Full Proxmox path: QNAP:iso/<iso_file>
# CDX custom build includes QEMU Guest Agent (cdx-qga suffix).
iso_file = "vyos-1.5-rolling-202512150610-cdx-qga-amd64.iso"

# VM hardware
cores  = 2
memory = 1024

# Disk
disk_size = "4G"

# VyOS admin account password set during installation.
# Root SSH password is configured to the same value via VyOS CLI
# post-install (root access required by CDX-E Ansible inventory).
# Change this to a site-specific value before building.
vyos_admin_password = "IyTt+,uDhtR@.303"

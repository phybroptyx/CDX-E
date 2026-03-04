# =============================================================================
# CDX-E Packer — Common Variables
# =============================================================================
# Shared by all template builds. Override individual values in the
# per-template .pkrvars.hcl file.
#
# Proxmox credentials (proxmox_api_token_id, proxmox_api_token_secret)
# are NOT defined here — they are injected at build time by the
# deploy_packer_template Ansible role via:
#   -var "proxmox_api_token_id=..."   (command-line arg)
#   PKR_VAR_proxmox_api_token_secret  (environment variable — keeps secret
#                                      out of process list and Ansible logs)
# =============================================================================

# Proxmox API endpoint
proxmox_api_url = "https://cdx-pve-01:8006/api2/json"

# Target Proxmox node for the build VM
proxmox_node = "cdx-pve-01"

# Proxmox storage pool where ISOs are staged (shared across all nodes)
iso_storage_pool = "QNAP"

# Proxmox storage pool where finished templates are registered
# All Packer-built templates land on QNAP; per-node RAID copies are
# staged separately (qm clone → convert template).
template_storage = "QNAP"

# Disk format for all template builds
disk_type = "qcow2"

# Disk cache mode — writeback gives best build performance
disk_cache_mode = "writeback"

# Proxmox resource pool all built templates are assigned to
pool = "CDX_TEMPLATES"

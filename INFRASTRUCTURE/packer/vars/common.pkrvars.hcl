# =============================================================================
# Common Packer Variables
# =============================================================================
# Shared across all template builds. Override per-template in <os>.pkrvars.hcl.
# Secrets should be passed via environment variables or a separate vault file.
# =============================================================================

proxmox_api_url  = "https://cdx-pve-01:8006/api2/json"
proxmox_node     = "cdx-pve-01"

# Storage pool for template disks
# proxmox_storage_pool = "QNAP"
proxmox_storage_pool = "QNAP"

# VirtIO-Win driver ISO (shared by all Windows builds)
# virtio_iso_file = "QNAP:iso/virtio-win.iso"
virtio_iso_file = "QNAP:iso/virtio-win.iso"
virtio_iso_file_81_2012r2 = "QNAP:iso/virtio-win-0.1.185.iso"
virtio_iso_file_7_2008r2 = "QNAP:iso/virtio-win-0.1.160.iso"

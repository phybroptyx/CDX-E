# Windows Server 2008 R2 - template-specific variables
template_vm_id   = 2024
template_name    = "cdx-win2008r2-base"
iso_file         = "QNAP:iso/Windows.Server.2008.R2-cdx.iso"

# Override common virtio_iso_file — 2008 R2 requires the oldest driver set
virtio_iso_file         = "QNAP:iso/virtio-win-0.1.160.iso"

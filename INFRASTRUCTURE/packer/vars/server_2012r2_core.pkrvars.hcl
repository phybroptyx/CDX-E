# Windows Server 2012 R2 Datacenter (Server Core) - template-specific variables
template_vm_id     = 2027
template_name      = "cdx-win2012r2-core"
iso_file         = "QNAP:iso/Windows.Server.2012.R2-cdx.iso"
autounattend_file  = "../http/autounattend/win2012r2/autounattend-core.xml"

# Override common virtio_iso_file - 2012 R2 requires the legacy driver set
virtio_iso_file         = "QNAP:iso/virtio-win-0.1.185.iso"

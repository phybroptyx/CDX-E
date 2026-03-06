# FLARE VM (Mandiant malware analysis toolkit) — template-specific variables
# Paired with: flare-vm.pkr.hcl (proxmox-clone builder)
# Clone source: cdx-win10-base (vm_id 2035) must be built first.
vm_id       = 2049
vm_name     = "cdx-flarevm-base"
clone_vm_id = 2035
cores       = 2
memory      = 4096
disk_size   = "80G"

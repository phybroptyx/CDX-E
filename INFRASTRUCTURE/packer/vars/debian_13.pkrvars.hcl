# Debian 13.3.0 (Trixie) minimal — template-specific variables
# Paired with: debian-13.pkr.hcl
# VMID 2039 — CDX-RELAY VM base (relay VMID 102, 10.0.0.10/22)
#   Provisioned by provision_relay.yml — do not rebuild per exercise.
template_vm_id = 2039
template_name  = "cdx-debian133-base"
iso_file       = "QNAP:iso/debian-13.3.0-amd64-DVD-1.iso"

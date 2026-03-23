# =============================================================================
# Terraform: CDX-RELAY outputs
# =============================================================================

output "relay_vmid" {
  description = "Proxmox VMID of the CDX-RELAY VM"
  value       = proxmox_virtual_environment_vm.relay.vm_id
}

output "relay_name" {
  description = "Proxmox VM name of the CDX-RELAY"
  value       = proxmox_virtual_environment_vm.relay.name
}

output "relay_management_ip" {
  description = "Layer0 management IP for the CDX-RELAY (Ansible controller target)"
  value       = var.relay_management_ip
}

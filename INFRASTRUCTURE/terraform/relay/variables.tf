# =============================================================================
# Terraform: CDX-RELAY variables
# =============================================================================

# Proxmox connection
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g. https://cdx-pve-01:8006/api2/json)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g. root@pam!packer)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "proxmox_node" {
  type    = string
  default = "cdx-pve-01"
}

# Template
variable "debian13_template_vmid" {
  type        = number
  default     = 2039
  description = "Proxmox VMID of cdx-debian133-base template (built by debian-13.pkr.hcl)"
}

# Relay identity
variable "relay_management_ip" {
  type    = string
  default = "10.0.0.10"
}

variable "relay_management_cidr" {
  type    = number
  default = 22
}

variable "layer0_gateway" {
  type    = string
  default = "10.0.0.1"
}

# Network
variable "cdxi_bridge" {
  type        = string
  default     = "EQIX4"
  description = "Proxmox bridge for CDX-I EQIX4 uplink (eth1)"
}

# Access
variable "acn_ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for cdxadmin user (ACN management access)"
  default     = []
}

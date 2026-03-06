# =============================================================================
# Terraform: CDX-RELAY VM (VMID 102)
# =============================================================================
# Provisions the single persistent management relay VM for CDX-E.
# This resource is created ONCE and persists across all exercise deployments.
#
# Architecture:
#   - eth0 (net0): Layer0 static 10.0.0.10/22 — ACN connects here
#   - eth1 (net1): CDX-I EQIX4 bridge — Internet relay path
#   - eth2-4 (net2-4): NOT defined here — managed dynamically by configure_relay
#     via Proxmox API (PUT /qemu/102/config) during exercise setup/teardown.
#
# Provider: bpg/proxmox >= 0.95.0
# Template: cdx-debian133-base (VMID 2039, built by debian-13.pkr.hcl)
#
# Build command:
#   cd INFRASTRUCTURE/terraform/relay
#   terraform init
#   terraform apply \
#     -var "proxmox_api_url=https://cdx-pve-01:8006/api2/json" \
#     -var "proxmox_api_token_id=root@pam!packer" \
#     -var "proxmox_api_token_secret=<secret>"
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.95.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "relay" {
  node_name = var.proxmox_node
  vm_id     = 102
  name      = "cdx-relay"
  tags      = ["cdx-infrastructure", "relay"]

  # Full clone — relay is persistent infrastructure, not a per-exercise VM
  clone {
    vm_id = var.debian13_template_vmid
    full  = true
  }

  # Resources — lightweight relay host
  memory {
    dedicated = 1024
  }

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  vga {
    type   = "serial"
    memory = 0
  }

  # eth0 — Layer0 static management interface
  # Cloud-init sets 10.0.0.10/22 so Ansible controller can connect immediately
  network_device {
    model    = "virtio"
    bridge   = "Layer0"
    firewall = false
  }

  # eth1 — CDX-I EQIX4 uplink (Internet path)
  network_device {
    model    = "virtio"
    bridge   = var.cdxi_bridge
    firewall = false
  }

  # eth2-4 — NOT defined here.
  # configure_relay manages them dynamically via Proxmox API:
  #   Assign: PUT /qemu/102/config  body: net2=virtio,bridge=<bridge>
  #   Release: PUT /qemu/102/config  body: delete=net2,net3,net4

  # Cloud-init: static management IP on eth0
  initialization {
    ip_config {
      ipv4 {
        address = "${var.relay_management_ip}/${var.relay_management_cidr}"
        gateway = var.layer0_gateway
      }
    }
    user_account {
      username = "cdxadmin"
      keys     = var.acn_ssh_public_keys
    }
  }

  started = true

  lifecycle {
    # Relay is persistent infrastructure — never destroy it with Terraform
    prevent_destroy = true

    # Ignore network_device after initial creation.
    # configure_relay manages net2-4 dynamically and Terraform must not
    # fight those assignments on subsequent plan/apply runs.
    ignore_changes = [
      network_device,
    ]
  }
}

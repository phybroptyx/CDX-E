# CDX-E Exercise Lifecycle Management

## Overview

The CDX-E (Cyber Defense Exercise - Enterprise) framework provides automated tools for deploying and managing cybersecurity training environments on Proxmox virtualization infrastructure. This document covers the two primary PowerShell scripts used to orchestrate exercise lifecycles:

| Script | Purpose |
|--------|---------|
| `Init-CDX-E.ps1` | Full exercise orchestration (network, pools, VMs) |
| `Invoke-CDX-E.ps1` | VM-specific operations (deploy, destroy, start, stop, status) |

These scripts work together to automate what would otherwise be a complex, error-prone manual process involving multiple Proxmox hosts, network configurations, resource pools, and virtual machines.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Script Overview](#script-overview)
  - [Init-CDX-E.ps1](#init-cdx-eps1)
  - [Invoke-CDX-E.ps1](#invoke-cdx-eps1)
- [Exercise YAML Specification](#exercise-yaml-specification)
- [Template Registry](#template-registry)
- [Host Network Configuration](#host-network-configuration)
- [Usage Examples](#usage-examples)
- [Parameters Reference](#parameters-reference)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

---

## Prerequisites

### PowerShell Environment

- **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (Cross-platform)
- **powershell-yaml module** - Install via:
  ```powershell
  Install-Module -Name powershell-yaml -Force -Scope CurrentUser
  ```

### Proxmox Infrastructure

- Proxmox VE cluster with SSH access enabled
- **SSH key authentication** configured from the management workstation to all Proxmox nodes
- VM templates created and available on the template node (default: `cdx-pve-01`)
- **Cloud-init** enabled on templates requiring static IP configuration (ide2 cloud-init drive)

### SSH Key Setup

Generate and distribute SSH keys to enable passwordless authentication:

```powershell
# Generate SSH key (if not already created)
ssh-keygen -t ed25519 -C "cdx-admin"

# Copy public key to each Proxmox host
ssh-copy-id root@cdx-pve-01
ssh-copy-id root@cdx-pve-02
ssh-copy-id root@cdx-pve-03
```

Verify connectivity:
```powershell
ssh root@cdx-pve-01 "hostname"
```

### Host Network Configuration

Network configuration (OVS bridges, CDX-I patch ports, VLAN tags) is managed centrally via Ansible. Each exercise YAML includes a `network_topology` section that defines the required bridges per Proxmox node. During deploy, Ansible templates `/etc/network/interfaces` on each affected node via SSH and reloads networking with `ifreload -a`.

**Per-host base config** (management IPs, physical interfaces) is stored in `inventory/host_vars/<node>.yml`.

> **Note:** This replaces the legacy `exercise.sh` script and per-host `interfaces.<exercise>` files. Those are no longer required on Proxmox hosts.

---

## Directory Structure

When the CDX-E repository is cloned, the structure is as follows:

```
CDX-E/                              # Repository Root
├── DOCUMENTATION/                  # Framework documentation
├── EXERCISES/                      # Exercise definitions and scripts
│   ├── OBSIDIAN_DAGGER/
│   │   └── obsidian_dagger_vms.yaml
│   ├── DESERT_CITADEL/
│   │   └── desert_citadel_vms.yaml
│   ├── ... (other exercises)
│   ├── Invoke-CDX-E.ps1            # VM lifecycle management script
│   └── Init-CDX-E.ps1              # Exercise orchestration script
└── UTILITIES/                      # Additional tools and utilities
```

---

## Script Overview

### Init-CDX-E.ps1

**Purpose:** Full exercise lifecycle orchestration - handles the complete setup and teardown of a training exercise environment.

**Version:** 1.0

#### What It Does

**Deploy Action (Setup Flow):**

1. **Phase 1: Network Configuration**
   - Connects to each Proxmox host via SSH
   - Executes `./exercise.sh <exercise_name>` to activate exercise-specific network interfaces
   - Aborts if any host fails (prevents partial deployments)

2. **Phase 2: Resource Pool Creation**
   - Creates a Proxmox resource pool named `EX_<EXERCISE_NAME>`
   - Adds a descriptive comment (e.g., "Operation Desert Citadel")
   - Skips if pool already exists

3. **Phase 3: VM Deployment**
   - Calls `Invoke-CDX-E.ps1` with the `-Action Deploy` parameter
   - Deploys all VMs defined in the exercise YAML specification

**Destroy Action (Teardown Flow):**

1. **Phase 1: VM Destruction**
   - Calls `Invoke-CDX-E.ps1` with the `-Action Destroy` parameter
   - Removes all exercise VMs (skips non-existent VMs gracefully)

2. **Phase 2: Resource Pool Deletion**
   - Removes the exercise resource pool
   - Continues even if pool doesn't exist

3. **Phase 3: Network Revert**
   - Executes `./exercise.sh revert` on each Proxmox host
   - Restores original network configuration

---

### Invoke-CDX-E.ps1

**Purpose:** VM-specific lifecycle operations - handles the creation, destruction, and management of individual virtual machines.

**Version:** 3.1

#### What It Does

| Action | Description |
|--------|-------------|
| `Deploy` | Clone VMs from templates, configure resources, networking, and cloud-init |
| `Destroy` | Stop and permanently remove VMs |
| `Start` | Start stopped VMs |
| `Stop` | Stop running VMs |
| `Status` | Report current state of all exercise VMs |

#### Key Features

- **Template Registry:** Embedded hashtable mapping template names to IDs - update once when templates change
- **Mixed-Node Deployment:** Clone from template node, deploy to any target node in the cluster
- **Cloud-Init Integration:** Automatic static IP configuration via cloud-init
- **Idempotency:** Safe to run multiple times - skips existing VMs on deploy, skips missing VMs on destroy
- **Selective Operations:** Filter operations to specific VMs by ID or name

---

## Exercise YAML Specification

Each exercise is defined by a YAML file containing VM specifications. The file includes exercise metadata, SSH configuration, and detailed VM definitions.

### Basic Structure

```yaml
exercise:
  name: "DESERT_CITADEL"
  description: "IT/OT Convergence Training Environment"
  classification: "mission_partner"

ssh:
  user: "root"
  auth: "key"

virtual_machines:
  - vmid: 5100
    name: "SDP-MDP-1"
    role: "Service Delivery Point"
    site: "Singapore"
    organization: "Madripoor"
    
    template: "vyos"              # References template registry
    
    clone:
      type: "linked"              # or "full"
      start_after_clone: true
    
    resources:
      memory_mb: 2048
      cores: 1
      sockets: 1
    
    network:
      preserve_net0: true
      additional_nics:
        - nic_id: 1
          model: "virtio"
          bridge: "vmbr100"
          firewall: true
    
    proxmox:
      node: "cdx-pve-03"          # Target deployment node
      pool: "EX_DESERT_CITADEL"
      tags:
        - "exercise"
        - "router"

  - vmid: 5101
    name: "MDP-DC-01"
    # ... additional VM definitions
```

### Template Reference Options

**Option 1: Template Name (Recommended)**
```yaml
template: "server_2012r2"    # Resolved from script's template registry
```

**Option 2: Direct Specification (Legacy)**
```yaml
template:
  id: 2006
  os: "Windows Server 2012 R2"
```

### Cloud-Init Configuration

For VMs requiring static IP addresses:

```yaml
cloud_init:
  ip: "10.0.1.50"
  cidr: 24
  gateway: "10.0.1.1"
  nameserver: "10.0.1.10"
```

---

## Template Registry

The `Invoke-CDX-E.ps1` script contains an embedded template registry near the top of the file. When templates are recreated with new IDs (common after updates), edit this section rather than modifying every exercise YAML.

```powershell
$Script:TemplateNode = "cdx-pve-01"  # Node where templates reside

$Script:Templates = @{
    # Windows Server Templates
    "server_2025"   = @{ id = 2001; os = "Windows Server 2025" }
    "server_2022"   = @{ id = 2002; os = "Windows Server 2022" }
    "server_2019"   = @{ id = 2003; os = "Windows Server 2019" }
    "server_2016"   = @{ id = 2004; os = "Windows Server 2016" }
    "server_2012r2" = @{ id = 2006; os = "Windows Server 2012 R2" }
    "server_2008r2" = @{ id = 2008; os = "Windows Server 2008 R2" }
    
    # Windows Desktop Templates
    "windows_11"    = @{ id = 2009; os = "Windows 11" }
    "windows_10"    = @{ id = 2010; os = "Windows 10" }
    "windows_8.1"   = @{ id = 2011; os = "Windows 8.1" }
    "windows_7"     = @{ id = 2016; os = "Windows 7" }
    
    # Linux / Network Templates
    "kali_purple"   = @{ id = 2007; os = "Kali Purple 2025.3" }
    "vyos"          = @{ id = 2015; os = "VyOS 2025" }
}
```

### Updating Templates

When a template is recreated:

1. Clone the existing template to a new VM
2. Make modifications to the VM
3. Convert the VM to a template (Proxmox assigns a new ID)
4. Update the `id` value in `$Script:Templates`
5. All exercises automatically use the new template on next deployment

---

## Host Network Configuration (Ansible-Managed)

### How It Works

Network configuration is fully managed by Ansible. No per-host scripts or pre-staged interface files are required.

**Data sources:**

| Source | Content |
|--------|---------|
| `inventory/host_vars/<node>.yml` | Per-host base config (management IPs, physical interfaces, bridge structure) |
| Exercise YAML `network_topology:` | OVS bridges, CDX-I patch ports, VLAN tags per site |
| `roles/cdx_e/templates/interfaces.j2` | Jinja2 template composing the full `/etc/network/interfaces` |

**Deploy flow:**
1. Ansible parses `network_topology` from the exercise YAML
2. Builds per-node site assignments (which bridges go on which host)
3. Templates `/etc/network/interfaces` on each affected node via SSH (`delegate_to`)
4. Runs `ifreload -a` to apply (only if the file changed)

**Revert flow:**
1. Re-templates `/etc/network/interfaces` with base config only (no exercise bridges)
2. Runs `ifreload -a` — OVS patch ports and exercise bridges are removed

### What the Template Produces

For each exercise bridge, the template generates:
- OVS bridge definition with STP disabled
- For external (`_ex`) bridges: OVS patch port pair connecting to vmbr303 (CDX-I) with a VLAN tag
- CDX-I bridge (vmbr303) `post-up` directives for its side of each patch port pair

### Legacy Approach (Deprecated)

The previous approach used per-host `exercise.sh` scripts and pre-staged `/etc/network/interfaces.<exercise>` files. These are no longer needed and can be removed from Proxmox hosts.

---

## Usage Examples

All examples assume you are in the `EXERCISES` directory.

### Full Exercise Deployment

Deploy the complete DESERT_CITADEL exercise with all phases:

```powershell
.\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml"
```

With auto-confirmation (no prompts):

```powershell
.\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm
```

Deploy but leave VMs stopped (useful for staged rollouts):

```powershell
.\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm -NoStart
```

Preview deployment without executing (dry run):

```powershell
.\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -DryRun
```

### Full Exercise Teardown

Destroy all VMs, remove the pool, and revert network configuration:

```powershell
.\Init-CDX-E.ps1 -Action Destroy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm
```

### VM-Only Operations

When you need to work with VMs without affecting network configuration or pools, use `Invoke-CDX-E.ps1` directly.

**Deploy VMs only:**
```powershell
.\Invoke-CDX-E.ps1 -Action Deploy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm
```

**Destroy VMs only:**
```powershell
.\Invoke-CDX-E.ps1 -Action Destroy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm
```

**Check VM status:**
```powershell
.\Invoke-CDX-E.ps1 -Action Status -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml"
```

**Start all exercise VMs:**
```powershell
.\Invoke-CDX-E.ps1 -Action Start -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm
```

**Stop all exercise VMs:**
```powershell
.\Invoke-CDX-E.ps1 -Action Stop -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -Confirm
```

### Selective VM Operations

Target specific VMs using the `-VmFilter` parameter.

**By VM ID:**
```powershell
.\Invoke-CDX-E.ps1 -Action Start -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -VmFilter 5101
```

**By VM name:**
```powershell
.\Invoke-CDX-E.ps1 -Action Stop -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -VmFilter "MDP-DC-01"
```

**Multiple VMs:**
```powershell
.\Invoke-CDX-E.ps1 -Action Destroy -YamlPath ".\DESERT_CITADEL\desert_citadel_vms.yaml" -VmFilter "5101,5102,5103" -Confirm
```

---

## Parameters Reference

### Init-CDX-E.ps1

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | `Deploy` or `Destroy` |
| `-YamlPath` | Yes | Path to exercise YAML specification file |
| `-Confirm` | No | Bypass confirmation prompts |
| `-NoStart` | No | Leave VMs stopped after deployment (Deploy only) |
| `-DryRun` | No | Preview commands without executing |

### Invoke-CDX-E.ps1

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | `Deploy`, `Destroy`, `Start`, `Stop`, or `Status` |
| `-YamlPath` | Yes | Path to exercise YAML specification file |
| `-VmFilter` | No | Target specific VMs by ID or name (default: `all`) |
| `-Confirm` | No | Bypass confirmation prompts |
| `-NoStart` | No | Leave VMs stopped after deployment (Deploy only) |
| `-DryRun` | No | Preview commands without executing |

---

## Troubleshooting

### SSH Connection Failures

**Symptom:** Script hangs or fails with SSH timeout errors.

**Solutions:**
1. Verify SSH key authentication is configured:
   ```powershell
   ssh root@cdx-pve-01 "echo 'SSH OK'"
   ```
2. Ensure the Proxmox host is reachable:
   ```powershell
   Test-Connection cdx-pve-01
   ```
3. Check for SSH agent issues on Windows:
   ```powershell
   Get-Service ssh-agent | Start-Service
   ```

### Template Not Found

**Symptom:** `Template 'server_2012r2' not found in script registry!`

**Solutions:**
1. Verify the template name matches an entry in `$Script:Templates`
2. Check that the template ID exists on the template node:
   ```bash
   qm list | grep <template_id>
   ```
3. Update the template registry if IDs have changed

### Pool Already Exists / Pool Not Found

**Symptom:** Warning about pool existence during deploy/destroy.

**Solution:** These are non-fatal warnings. The script handles existing/missing pools gracefully.

### Network Configuration Failures

**Symptom:** Network setup task fails during deploy

**Solutions:**
1. Verify SSH connectivity from the Ansible control node:
   ```bash
   ssh root@cdx-pve-01 "hostname"
   ```
2. Verify `host_vars` exists for the target node:
   ```bash
   ls inventory/host_vars/cdx-pve-01.yml
   ```
3. Check the exercise YAML has a `network_topology` section with correct node assignments
4. Verify `ifreload` is available on the Proxmox host:
   ```bash
   ssh root@cdx-pve-01 "which ifreload"
   ```

### VM Already Exists (Deploy)

**Symptom:** `VM 5101 (MDP-DC-01) already exists - skipping creation`

**Explanation:** This is expected idempotent behavior. The VM was previously deployed and won't be recreated. To redeploy, first destroy the existing VM.

### VM ID Conflict

**Symptom:** `VM ID 5101 exists but has different name`

**Explanation:** A VM with the specified ID exists but has a different name than expected. This is a safety check to prevent accidental overwrites.

**Solution:** Manually verify the VM in Proxmox and either:
- Remove the conflicting VM
- Update the YAML to use a different VM ID

### Cloud-Init IP Not Applied

**Symptom:** VM boots but doesn't have the expected static IP.

**Solutions:**
1. Verify the template has cloud-init configured (ide2 drive)
2. Check that `qm cloudinit update` completed successfully
3. Ensure the VM's network interface matches the cloud-init config (`net1` for `ipconfig1`)

### Windows "Run Script" Security Prompt

**Symptom:** PowerShell prompts "Do you want to run this script?"

**Solution:** Unblock the downloaded scripts:
```powershell
Unblock-File -Path ".\Init-CDX-E.ps1"
Unblock-File -Path ".\Invoke-CDX-E.ps1"
```

### powershell-yaml Module Not Found

**Symptom:** Script fails to parse YAML files.

**Solution:** Install the required module:
```powershell
Install-Module -Name powershell-yaml -Force -Scope CurrentUser
```

---

## Related Documentation

*[Placeholder - Additional documentation links to be added]*

- CDX-E Framework Overview
- YAML Specification Reference
- Template Creation Guide
- Network Topology Design
- Exercise Development Guide

---

## Version History

### Init-CDX-E.ps1
| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-25 | Initial release |

### Invoke-CDX-E.ps1
| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-22 | Initial release (Deploy-ProxmoxVM.ps1) |
| 1.1 | 2026-01-22 | Fixed ASCII encoding, linked clone logic, SSH quoting |
| 1.2 | 2026-01-22 | Multi-NIC support with optional MAC addresses |
| 2.0 | 2026-01-23 | Multi-VM support, VmFilter, Confirm parameter |
| 2.1 | 2026-01-23 | Multi-action refactor (Deploy, Destroy, Start, Stop, Status) |
| 2.2 | 2026-01-23 | Cloud-init integration for static IP configuration |
| 2.3 | 2026-01-23 | Cloud-init fix, auto-generated descriptions |
| 2.4 | 2026-01-23 | Markdown-formatted VM descriptions |
| 2.5 | 2026-01-23 | Mixed-node deployment support |
| 3.0 | 2026-01-25 | Embedded template registry |
| 3.1 | 2026-01-25 | Idempotency checks for Deploy/Destroy actions |

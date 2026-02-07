# CDX-E Framework - Exercise Lifecycle Management (Ansible)

Ansible-based automation for deploying, managing, and tearing down CDX exercise environments on Proxmox VE. Replaces the legacy PowerShell toolchain (`init-cdx-e.ps1` + `Invoke-CDX-E.ps1`).

## Overview

The framework is **exercise-agnostic**. A single Ansible role (`cdx_e`) handles the full VM lifecycle for any exercise. Exercise-specific topology, networking, and VM definitions live in standalone YAML specification files.

```
CDX-E/
├── site.yml                       # Main playbook (entry point)
├── ansible.cfg                    # Ansible configuration
├── requirements.yml               # Galaxy collection dependencies
├── inventory/hosts.yml            # Proxmox cluster inventory
├── roles/cdx_e/                   # Shared lifecycle role
│   ├── defaults/main.yml          #   API connection & timing defaults
│   ├── vars/main.yml              #   Template registry (VMID mappings)
│   └── tasks/                     #   Action task files
│       ├── main.yml               #     Entry point & action router
│       ├── load_exercise.yml      #     Exercise YAML loader & idempotency setup
│       ├── deploy.yml             #     Full deploy orchestration
│       ├── deploy_single_vm.yml   #     Per-VM clone/configure/start
│       ├── destroy.yml            #     Full teardown orchestration
│       ├── destroy_single_vm.yml  #     Per-VM stop/destroy
│       ├── start.yml              #     Start VMs
│       ├── stop.yml               #     Stop VMs
│       ├── status.yml             #     Query & display VM status
│       ├── network_setup.yml      #     OVS bridge creation via API
│       ├── network_revert.yml     #     OVS bridge removal via API
│       ├── pool_create.yml        #     Resource pool creation
│       └── pool_delete.yml        #     Resource pool deletion
│
└── EXERCISES/
    └── <EXERCISE_NAME>/
        ├── <exercise>_vms.yaml    # VM specification (exercise data)
        └── VyOS/                  # Router configs (if applicable)
```

## Prerequisites

- **Ansible** >= 2.15
- **Python** `proxmoxer` library (for `community.general.proxmox_kvm`)
- **community.general** collection >= 8.0.0
- **Proxmox VE** cluster with API token configured
- **Proxmox API token** with `Sys.Modify` on `/nodes/{node}` (for OVS bridge management)

Install dependencies:

```bash
ansible-galaxy collection install -r requirements.yml
pip install proxmoxer requests
```

## Actions

| Action    | Description |
|-----------|-------------|
| `deploy`  | Full exercise standup: network setup, pool creation, VM cloning/configuration/start |
| `destroy` | Full exercise teardown: VM destruction, pool deletion, network revert |
| `start`   | Start existing exercise VMs |
| `stop`    | Stop (force) existing exercise VMs |
| `status`  | Query and display current state of all exercise VMs |

## Usage

### Basic Syntax

```bash
ansible-playbook site.yml \
  -e action=<ACTION> \
  -e exercise_yaml=<PATH_TO_EXERCISE_YAML> \
  -e proxmox_api_token_secret=<API_TOKEN_SECRET>
```

### Required Variables

| Variable | Description |
|----------|-------------|
| `action` | Lifecycle action: `deploy`, `destroy`, `start`, `stop`, `status` |
| `exercise_yaml` | Relative or absolute path to the exercise VM specification YAML |
| `proxmox_api_token_secret` | Proxmox API token secret (see [Authentication](#authentication)) |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `vm_filter` | `all` | Comma-separated list of VMIDs or VM names to target |
| `no_start` | `false` | Deploy VMs but leave them stopped |
| `dry_run` | `false` | Preview actions without executing |

## Examples

### Deploy an entire exercise

```bash
ansible-playbook site.yml \
  -e action=deploy \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e proxmox_api_token_secret="your-secret-here"
```

### Deploy without starting VMs

```bash
ansible-playbook site.yml \
  -e action=deploy \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e no_start=true \
  -e proxmox_api_token_secret="your-secret-here"
```

### Dry run (preview changes)

```bash
ansible-playbook site.yml \
  -e action=deploy \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e dry_run=true
```

### Check status of all exercise VMs

```bash
ansible-playbook site.yml \
  -e action=status \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e proxmox_api_token_secret="your-secret-here"
```

### Stop specific VMs by VMID

```bash
ansible-playbook site.yml \
  -e action=stop \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e vm_filter=5205,5206 \
  -e proxmox_api_token_secret="your-secret-here"
```

### Start a single VM by name

```bash
ansible-playbook site.yml \
  -e action=start \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e vm_filter=SCT-DC-01 \
  -e proxmox_api_token_secret="your-secret-here"
```

### Full teardown

```bash
ansible-playbook site.yml \
  -e action=destroy \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml \
  -e proxmox_api_token_secret="your-secret-here"
```

### Deploy a different exercise (same role, different data)

```bash
ansible-playbook site.yml \
  -e action=deploy \
  -e exercise_yaml=EXERCISES/DESERT_CITADEL/desert_citadel_vms.yaml \
  -e proxmox_api_token_secret="your-secret-here"
```

## Authentication

The Proxmox API token secret should **never** be committed to source control. Supply it using one of these methods:

### Extra vars (ad-hoc)

```bash
ansible-playbook site.yml -e proxmox_api_token_secret="your-secret"
```

### Ansible Vault

```bash
# Create encrypted vars file
ansible-vault create inventory/vault.yml

# Contents:
# proxmox_api_token_secret: "your-secret"

# Run with vault
ansible-playbook site.yml --ask-vault-pass -e action=status \
  -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml
```

### Environment variable

```bash
export PROXMOX_API_TOKEN_SECRET="your-secret"
ansible-playbook site.yml -e proxmox_api_token_secret="$PROXMOX_API_TOKEN_SECRET" \
  -e action=status -e exercise_yaml=EXERCISES/HARDENED_CHAMPION/hardened_champion_vms.yaml
```

## Deploy Workflow

The `deploy` action executes three phases in order:

1. **Network Setup** - Creates OVS bridges on Proxmox nodes via the API (only on nodes with VMs referencing them; idempotent)
2. **Pool Creation** - Creates a Proxmox resource pool (`EX_<EXERCISE_NAME>`) via the API
3. **VM Deployment** - For each VM in the specification:
   - Clones from the template registered in `roles/cdx_e/vars/main.yml`
   - Configures resources (CPU, memory, description, tags)
   - Adds additional NICs (bridges, VLANs, MAC addresses)
   - Applies cloud-init networking (static IP, gateway, DNS)
   - Starts the VM (unless `no_start=true`)

## Destroy Workflow

The `destroy` action executes three phases in reverse order:

1. **VM Destruction** - For each VM: force-stop, then remove (with name-match safety check)
2. **Pool Deletion** - Removes the resource pool via the API
3. **Network Revert** - Removes exercise OVS bridges via the API (only on full teardown; partial destroys preserve bridges)

## Idempotency

All actions include idempotency checks:

- **Deploy** skips VMs that already exist with a matching name. Fails if a VMID exists with a different name (conflict protection).
- **Destroy** skips VMs that don't exist. Skips VMs where the VMID exists but the name doesn't match (safety check).
- **Start/Stop** only target VMs that exist and whose names match the specification.

## Exercise YAML Schema

Each exercise is defined by a YAML specification file. The schema:

```yaml
exercise:
  name: "EXERCISE_NAME"           # Used for pool naming, network scripts
  description: "Description"      # Displayed in status output

ssh:
  user: "root"
  auth: "key"

cloud_init_defaults:              # Shared cloud-init credentials
  username: "cdxadmin"
  password: "P@ssw0rd"
  ssh_public_key: "ssh-rsa ..."

virtual_machines:
  - vmid: 5201                    # Unique Proxmox VMID
    name: "VM-NAME"               # VM display name
    role: "Domain Controller"     # Descriptive role
    site: "Location"
    organization: "Org Name"

    template: "server_2022"       # Key from template registry

    clone:
      type: "linked"             # "linked" or "full"
      start_after_clone: true

    resources:
      memory_mb: 4096
      cores: 2
      sockets: 1

    network:
      preserve_net0: true        # Keep management NIC
      additional_nics:
        - nic_id: 1
          model: "virtio"
          bridge: "bridge_name"
          firewall: true
          tag: 210               # Optional VLAN tag
          mac: "AA:BB:CC:DD:EE:FF"  # Optional static MAC

    cloud_init:                  # Optional - omit for DHCP/manual
      ip: "10.0.0.10"
      cidr: 24
      gateway: "10.0.0.1"
      nameserver: "10.0.0.10"

    proxmox:
      node: "cdx-pve-01"        # Target Proxmox node
      pool: "EX_EXERCISE_NAME"
      tags:
        - "exercise_name"
```

## Template Registry

VM templates are mapped by name in `roles/cdx_e/vars/main.yml`. Exercise YAMLs reference templates by name rather than VMID, allowing template rebuilds without updating every exercise file.

Current registry:

| Template Key | VMID | OS |
|-------------|------|-----|
| `server_2025` | 2001 | Windows Server 2025 |
| `server_2022` | 2002 | Windows Server 2022 |
| `server_2019` | 2003 | Windows Server 2019 |
| `server_2016` | 2004 | Windows Server 2016 |
| `server_2012r2` | 2006 | Windows Server 2012 R2 |
| `server_2008r2` | 2008 | Windows Server 2008 R2 |
| `windows_11` | 2009 | Windows 11 |
| `windows_10` | 2010 | Windows 10 |
| `windows_8.1` | 2011 | Windows 8.1 |
| `windows_7` | 2016 | Windows 7 |
| `centos_7` | 2019 | CentOS 7 |
| `centos_7_server` | 2020 | CentOS 7 Server |
| `ubuntu_2110` | 2021 | Ubuntu 21.10 |
| `kali_purple` | 2007 | Kali Purple 2025.3 |
| `vyos` | 2017 | VyOS 2025 |

## Proxmox Cluster Defaults

| Setting | Default | Override via |
|---------|---------|-------------|
| API Host | `cdx-pve-01` | `proxmox_api_host` |
| API Port | `8006` | `proxmox_api_port` |
| API User | `root@pam` | `proxmox_api_user` |
| Token ID | `ansible` | `proxmox_api_token_id` |
| Validate Certs | `false` | `proxmox_validate_certs` |
| Template Node | `cdx-pve-01` | `template_node` |
| Clone Timeout | `300s` | `clone_timeout` |
| Post-Clone Delay | `8s` | `post_clone_delay` |
| Post-Stop Delay | `3s` | `post_stop_delay` |

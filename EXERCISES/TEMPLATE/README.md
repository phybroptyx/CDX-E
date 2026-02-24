# CDX-E Exercise Template

This directory is the canonical starting point for all new CDX-E exercises.
Copy the entire folder and fill in the required fields.

## Quick Start

```bash
# 1. Copy the template
cp -r EXERCISES/TEMPLATE EXERCISES/MY_EXERCISE_NAME

# 2. Rename to match your exercise name (uppercase, underscores)
# 3. Edit each file — search for REQUIRED and EXERCISE_NAME
# 4. Run a dry-run to validate
ansible-playbook playbooks/scenario_deployment.yml \
  -e "exercise=MY_EXERCISE_NAME" \
  --check --diff
```

---

## Files in This Template

| File | Purpose | Consumed By |
|---|---|---|
| `scenario.yml` | Pipeline control: phases, domain, network, Proxmox defaults | Ansible `read_exercise_config` |
| `vms.yaml` | VM inventory: templates, resources, group assignments, cloud-init | Ansible `read_exercise_config` |
| `exercise_template.json` | AD structure: sites, site links, OU hierarchy | `generate_structure.ps1` |
| `users.json` | AD user accounts and security groups | `configure_active_directory` / `ad_deploy.ps1` |
| `gpo.json` | Group Policy Objects | `deploy_group_policy_objects` / `ad_deploy.ps1` |
| `services.json` | DNS zones, records, DHCP scopes | `configure_active_directory` / `ad_deploy.ps1` |

---

## Configuration Checklist

### scenario.yml
- [ ] `exercise.name` — uppercase, matches folder name
- [ ] `exercise.codename` — human-friendly operation name
- [ ] `exercise.description` — one-line scenario summary
- [ ] `exercise.teams` — set which teams participate
- [ ] `exercise.vm_id_ranges` — document VMID namespace for this exercise
- [ ] `domain.name` — exercise domain FQDN
- [ ] `domain.netbios` — NetBIOS name (≤15 chars)
- [ ] `domain.admin_password` — vault reference (never plaintext)
- [ ] `domain.sites` — at least one site defined
- [ ] `phases.*` — enable/disable pipeline phases
- [ ] `network.management_vlan` — Proxmox management VLAN
- [ ] `network.dns_servers` — CDX-I upstream DNS
- [ ] `proxmox.node` — default target Proxmox node
- [ ] `proxmox.storage` — default storage pool

### vms.yaml
- [ ] `exercise.name` — matches scenario.yml
- [ ] `cloud_init_defaults` — vault references populated
- [ ] `network_topology.sites` — OVS bridges defined per Proxmox node
- [ ] `network_topology.*.cdxi_patch.vlan_tag` — CDX-I VLAN assigned to each external site
- [ ] At least one domain controller defined (`ansible_group: domain_controllers`)
- [ ] All `template` values exist in `inventory/group_vars/all.yml → template_registry`
- [ ] All `vmid` values are unique and within the ranges declared in `scenario.yml`
- [ ] Red team VMs use `ansible_group: red_team` or `apt`
- [ ] Blue team VMs use `ansible_group: blue_team` or `soc`

### exercise_template.json
- [ ] `sites` — one entry per geographic/logical site
- [ ] `siteLinks` — defined for multi-site exercises (remove for single-site)
- [ ] `organizationalStructure.siteMappings` — sites mapped to departments

### users.json
- [ ] Replace placeholder personas with exercise characters
- [ ] All `ou` paths match OUs defined in `exercise_template.json`
- [ ] All `groups` references defined in the `groups` array
- [ ] At least one domain admin account exists

### gpo.json
- [ ] `__DOMAIN__` replaced with exercise FQDN in all paths
- [ ] GPO `links` reference OUs that exist in the exercise structure
- [ ] Branding images placed in `Domain Files/` subdirectory

### services.json
- [ ] `__AD_DOMAIN__` replaced with exercise FQDN
- [ ] One reverse DNS zone per IP subnet used in the exercise
- [ ] DHCP scopes defined only if `scenario.yml → phases.services.dhcp: true`

---

## VM ID Allocation Reference

| Range | Purpose |
|---|---|
| 1–999 | CDX Management infrastructure |
| 1000–1999 | Blue Team / SOC VMs |
| 2000–2999 | Proxmox VM templates (Packer-built) |
| 3000–3999 | Red Team / APT VMs |
| 4000–4999 | CDX-I backbone (grey space) |
| 5000–5999 | Exercise servers (scenario) |
| 6000–6999 | Exercise workstations (scenario) |

Each exercise should claim a contiguous sub-range and document it in
`scenario.yml → exercise.vm_id_ranges`.

---

## Template Keys (inventory/group_vars/all.yml)

| Key | OS |
|---|---|
| `vyos` | VyOS 2025 |
| `server_2025` | Windows Server 2025 |
| `server_2022` | Windows Server 2022 |
| `server_2019` | Windows Server 2019 |
| `server_2016` | Windows Server 2016 |
| `server_2012r2` | Windows Server 2012 R2 |
| `server_2008r2` | Windows Server 2008 R2 |
| `windows_11` | Windows 11 |
| `windows_10` | Windows 10 |
| `windows_8_1` | Windows 8.1 |
| `windows_7` | Windows 7 |
| `kali_purple` | Kali Purple |
| `ubuntu_server` | Ubuntu Server LTS |
| `centos_7_server` | CentOS 7 |

> When a new OS template is added to Packer and Proxmox, add it to
> `template_registry` in `inventory/group_vars/all.yml` — it becomes
> available to all exercises automatically.

---

## Updating This Template

When new pipeline requirements are introduced (new scenario.yml fields,
new VM attributes, new JSON sections), **update this template first**,
then propagate changes to active exercise directories as needed.

This template is the single source of truth for exercise structure.

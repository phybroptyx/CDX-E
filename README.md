# CDX-E — Cyber Defense Exercise Automation Framework

Ansible-based pipeline for deploying, configuring, and tearing down CDX exercise environments on a Proxmox VE cluster. Integrates Packer (template builds), Terraform (VM provisioning via the bpg/proxmox provider), and Ansible (OS configuration, Active Directory, service deployment, and adversary/SOC infrastructure).

---

## Architecture

The framework is **exercise-agnostic and phase-driven**. Each exercise is defined by two YAML files in `EXERCISES/<NAME>/`. A global library of modular Ansible roles handles the full lifecycle — from building Packer templates through adversary and SOC infrastructure — without touching any exercise-specific code.

Red Team infrastructure is driven by **APT profiles** (`APTs/<NAME>/`). Blue Team infrastructure is driven by **SOC layouts** (`SOC_LAYOUTS/<NAME>/`). Both are reusable, exercise-independent libraries.

```
Packer → Stage → Terraform → Inventory → Power → Network → Configure → AD → Services → Red Team → Blue Team → Agents
```

All shared configuration (Proxmox API endpoints, template registry, timing, Terraform provider versions) lives in a single file: `inventory/group_vars/all.yml`.

---

## Directory Structure

```
CDX-E/
├── ansible.cfg
├── requirements.yml                     # Galaxy collection dependencies
│
├── playbooks/                           # One playbook per pipeline phase
│   ├── provision_relay.yml              # One-time: provision + configure CDX-RELAY VM
│   ├── exercise_initiation.yml          # Phase 0 — load exercise config
│   ├── template_deployment.yml          # Phase 1 — Packer template builds
│   ├── template_staging.yml             # Phase 1b — Stage RAID-local template copies (standalone)
│   ├── vm_management.yml                # Phase 2 — Terraform deploy/destroy (scenario VMs)
│   ├── inventory_refresh.yml            # Phase 3 — write dynamic inventory
│   ├── vm_power_management.yml          # Phase 4 — power on, wait for agent
│   ├── network_management.yml           # Phase 5 — OVS bridges + VyOS config
│   ├── server_configuration.yml         # Phase 6 — Windows/Linux base config
│   ├── workstation_configuration.yml    # Phase 6 — workstation base config
│   ├── domain_management.yml            # Phase 7 — Active Directory
│   ├── domain_services.yml              # Phase 8 — GPO, SQL, Exchange, SCCM
│   ├── red_team_deployment.yml          # Phase 9 — Red Team / adversary infra
│   ├── blue_team_deployment.yml         # Phase 10 — Blue Team / SOC infra
│   └── endpoint_agent_deployment.yml    # Phase 11 — SIEM agent deployment
│
├── roles/
│   ├── read_exercise_config/            # Loads scenario.yml + vms.yaml → facts
│   ├── read_apt_config/                 # Loads APTs/<apt>/apt.yml + vms.yaml → facts
│   ├── read_soc_layout/                 # Loads SOC_LAYOUTS/<layout>/layout.yml + vms.yaml → facts
│   ├── deploy_packer_template/          # Packer build: check Proxmox → build missing
│   ├── stage_templates/                 # Phase 1b: full-copy QNAP masters → per-node RAID
│   ├── deploy_scenario/                 # Terraform: scenario VMs
│   ├── deploy_red_team/                 # Terraform: Red Team VMs (from APT profile)
│   ├── deploy_blue_team/                # Terraform: Blue Team VMs (from SOC layout)
│   ├── destroy_scenario/                # Terraform destroy: scenario VMs
│   ├── destroy_red_team/                # Terraform destroy: Red Team VMs
│   ├── destroy_blue_team/               # Terraform destroy: Blue Team VMs
│   ├── inventory_refresh/               # Read TF outputs → write exercise_hosts.yml
│   ├── vm_power_management/             # Start VMs, poll QEMU agent, wait for ports
│   ├── configure_vm/                    # Base OS: hostname, timezone, WinRM, PS policy
│   ├── configure_networking/            # Proxmox OVS SDN + VyOS router config
│   ├── revert_networking/               # Restore base network, remove exercise bridges
│   ├── configure_active_directory/      # DC promotion, OU structure, sites, users, groups
│   ├── install_windowsfeature/          # Windows Server role installation
│   ├── deploy_group_policy_objects/     # GPO deployment (dual-schema v1.0/v2.0 support)
│   ├── deploy_sql_server/               # SQL Server unattended install
│   ├── deploy_microsoft_exchange/       # Exchange 2010/2013/2016 deployment
│   ├── deploy_configuration_manager/    # SCCM/MECM deployment
│   ├── configure_red_team/              # C2 framework config, operator tooling
│   ├── configure_blue_team/             # Malcolm, Hedgehog sensor, analyst workstations
│   ├── deploy_endpoint_agents/          # SIEM agents: wazuh / elastic / splunk_uf
│   ├── configure_relay/                 # CDX-RELAY lifecycle: provision, assign/release NICs, verify
│   └── cdx_e/                          # Legacy monolithic role (reference only)
│
├── APTs/                                # Global APT adversary profile library
│   ├── TEMPLATE/                        # Schema template — copy to create a new APT
│   │   ├── apt.yml                      # APT identity, C2 platforms, objectives
│   │   └── vms.yaml                     # Red Team VM specification
│   └── GENERIC_RED/                     # Default generic adversary profile
│       ├── apt.yml
│       └── vms.yaml
│
├── SOC_LAYOUTS/                         # Global SOC layout library
│   ├── TEMPLATE/                        # Schema template — copy to create a new layout
│   │   ├── layout.yml                   # SOC identity, Malcolm/sensor/firewall config
│   │   └── vms.yaml                     # Blue Team VM specification
│   └── malcolm_basic/                   # Malcolm + Hedgehog + OPNsense + Kali Purple
│       ├── layout.yml
│       └── vms.yaml
│
├── inventory/
│   ├── hosts.yml                        # Static: Proxmox cluster nodes, relay, localhost
│   ├── exercise_hosts.yml               # Generated by inventory_refresh (gitignored)
│   ├── group_vars/
│   │   ├── all.yml                      # Single source of truth: API, timing,
│   │   │                                #   Packer paths, Terraform, template_registry
│   │   ├── windows_hosts.yml            # WinRM connection params for Windows VMs
│   │   ├── linux_hosts.yml              # SSH connection params for Linux VMs
│   │   └── vyos_hosts.yml               # SSH connection params for VyOS routers
│   └── host_vars/
│       ├── cdx-pve-01.yml               # Proxmox node base_network (vault-encrypted)
│       ├── cdx-pve-02.yml
│       ├── cdx-pve-03.yml
│       └── *.yml.example                # Unencrypted templates showing structure
│
├── Secrets/
│   ├── README.md                        # Setup instructions
│   └── credentials.yml                  # Template — copy, fill in, vault-encrypt
│                                        # (gitignored after population)
│
└── EXERCISES/
    ├── TEMPLATE/                        # Canonical template for new exercises
    │   ├── scenario.yml                 # Phase gates, domain, proxmox, APT/SOC defaults
    │   ├── vms.yaml                     # Scenario VM specs + network_topology
    │   ├── exercise_template.json
    │   ├── users.json
    │   ├── gpo.json
    │   ├── services.json
    │   └── README.md
    └── <EXERCISE_NAME>/
        ├── scenario.yml                 # Exercise control: phases, domain, proxmox,
        │                                #   red_team.apt, blue_team.layout
        ├── vms.yaml                     # Scenario VM specs + network_topology
        │                                #   (Red/Blue VMs come from APT/SOC libraries)
        ├── VyOS/                        # Per-router VyOS CLI config files
        │   └── <VM-NAME>.conf
        ├── terraform/                   # Generated by deploy_scenario (gitignored)
        ├── terraform_red_team/          # Generated by deploy_red_team (gitignored)
        └── terraform_blue_team/         # Generated by deploy_blue_team (gitignored)
```

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Ansible** >= 2.15 | On the controller node |
| **Packer** >= 1.10 | At `/usr/local/bin/packer` (configurable via `packer_binary`) |
| **Terraform** >= 1.6 | At `terraform` in PATH (configurable via `terraform_binary`) |
| **Python** `proxmoxer`, `requests` | Required by `community.general.proxmox_kvm` |
| **xorriso** or **genisoimage** | Required by Packer for ISO assembly |
| **Proxmox VE** 8.x cluster | API token with VM and pool management permissions |
| **SSH access** (root) | Controller → all Proxmox cluster nodes (for SDN config) |

Install Ansible collections:

```bash
ansible-galaxy collection install -r requirements.yml
pip install proxmoxer requests
```

---

## Secrets and Vault

All secrets flow through `Secrets/credentials.yml` and vault-encrypted `host_vars`.

```bash
# Copy the template, populate with real values
cp Secrets/credentials.yml.example Secrets/credentials.yml

# Encrypt
ansible-vault encrypt Secrets/credentials.yml

# Use at runtime
ansible-playbook playbooks/vm_management.yml \
  -e "exercise=OBSIDIAN_DAGGER action=deploy" \
  -e "@Secrets/credentials.yml" \
  --ask-vault-pass
```

---

## Pipeline Phases

Each phase is a standalone playbook. Run them sequentially for a full exercise standup.

| # | Playbook | Role(s) | Status | Description |
|---|---|---|---|---|
| 0 | `exercise_initiation.yml` | `read_exercise_config` | ✅ | Loads `scenario.yml` + `vms.yaml`; sets cacheable facts for all subsequent plays |
| 1 | `template_deployment.yml` | `deploy_packer_template` | ✅ | Queries Proxmox for existing templates; builds missing ones with Packer; validates post-build |
| 1b | `template_staging.yml` | `stage_templates` | ✅ | Full-copies QNAP master templates to per-node RAID storage so Terraform can create linked clones locally; skips `qnap_direct` templates and VMIDs already staged |
| 2 | `vm_management.yml` | `deploy_scenario` | ✅ | Generates and applies Terraform config for scenario VMs; independent state dir per exercise |
| 3 | `inventory_refresh.yml` | `inventory_refresh` | ✅ | Reads Terraform outputs from all three state dirs; writes `inventory/exercise_hosts.yml` |
| 4 | `vm_power_management.yml` | `vm_power_management` | ✅ | Starts VMs via Proxmox API; polls QEMU guest agent until OS is ready; waits for WinRM/SSH |
| 5 | `network_management.yml` | `configure_networking` `revert_networking` | ✅ | SDN: templates `/etc/network/interfaces`, pre-creates OVS bridges. VyOS: pushes per-router configs |
| 6 | `server_configuration.yml` `workstation_configuration.yml` | `configure_vm` `install_windowsfeature` | ✅ | Hostname, timezone, PS policy, WinRM, local admin, Windows features |
| 7 | `domain_management.yml` | `configure_active_directory` `deploy_group_policy_objects` | ✅ | DC promotion, OU structure, AD sites, users, groups; dual-schema GPO deployment |
| 8 | `domain_services.yml` | `deploy_sql_server` `deploy_microsoft_exchange` `deploy_configuration_manager` | ✅ | Application services — enabled per-exercise via `scenario.phases.services.*` |
| 9 | `red_team_deployment.yml` | `read_apt_config` `deploy_red_team` `configure_red_team` | ✅ | Loads APT profile, provisions Red Team VMs via Terraform, configures C2 and operator tooling |
| 10 | `blue_team_deployment.yml` | `read_soc_layout` `deploy_blue_team` `configure_blue_team` | ✅ | Loads SOC layout, provisions Blue Team VMs via Terraform, configures Malcolm/sensors/analysts |
| 11 | `endpoint_agent_deployment.yml` | `deploy_endpoint_agents` | ✅ | Deploys Wazuh/Elastic/Splunk agents to VMs with `monitor: true` in vms.yaml |

**Destroy:** `vm_management.yml -e action=destroy`, `red_team_deployment.yml -e action=destroy`, `blue_team_deployment.yml -e action=destroy`

---

## Exercise Configuration

Each exercise lives in `EXERCISES/<NAME>/`. Bootstrap from the template:

```bash
cp -r EXERCISES/TEMPLATE/ EXERCISES/MY_EXERCISE/
```

### scenario.yml

Controls which phases run and sets domain, network, Proxmox defaults, and APT/SOC selections:

```yaml
exercise:
  name: MY_EXERCISE
  codename: "Operation ..."
  teams:
    white_cell: true
    red_team: true
    blue_team: true

phases:
  packer: true
  terraform: true
  networking: true
  domain: true
  servers: true
  services:
    sql: false
    exchange: false
    sccm: false
  red_team: true       # Phase 9 — triggers Red Team deployment
  blue_team: true      # Phase 10 — triggers Blue Team deployment
  endpoint_agents: true  # Phase 11 — deploys SIEM agents to monitored VMs

red_team:
  apt: GENERIC_RED     # APT library key — override at runtime with -e "apt=APT29"

blue_team:
  layout: malcolm_basic  # SOC layout key — override at runtime with -e "layout=malcolm_basic"
  endpoint_agent_platform: wazuh

domain:
  name: example.cdx.lab
  netbios: EXAMPLE
  functional_level: Win2019
  admin_password: "{{ vault_domain_admin_password }}"

proxmox:
  node: cdx-pve-01
  storage: QNAP
```

### vms.yaml

Defines **scenario VMs only** (defended network). Red Team and Blue Team VMs are defined in their respective APT and SOC layout libraries.

```yaml
virtual_machines:
  - vmid: 5001
    name: "EX-DC-01"
    template: "server_2022"
    ansible_group: "domain_controllers"
    monitor: true            # true = deploy SIEM agent on this VM
    resources:
      memory_mb: 8192
      cores: 4
    cloud_init:
      ip: "10.0.0.10"
      cidr: 24
      gateway: "10.0.0.1"
      nameserver: "10.0.0.10"
```

Valid `ansible_group` values for scenario VMs: `domain_controllers`, `servers`, `workstations`, `routers`

---

## APT Adversary Profiles

APT profiles live in `APTs/<NAME>/` and define the Red Team's adversary simulation:

```
APTs/
├── TEMPLATE/               # Copy this to create a new APT profile
│   ├── apt.yml             # APT identity, C2 platforms, objectives, TTPs
│   └── vms.yaml            # Red Team VM fleet (VMIDs 3000-3099 range)
└── GENERIC_RED/            # Default profile — Adaptix C2, Kali operator
```

### apt.yml key fields

```yaml
apt:
  name: GENERIC_RED
  description: "Generic Red Team profile"
  ttps:
    - "T1566.001 - Spearphishing Attachment"

c2_platforms:
  - name: adaptix              # adaptix / cobalt_strike / sliver
    vm: "RT-C2-01"            # VM hostname from vms.yaml that runs this C2
    listener_port: 443
    listener_protocol: https
    teamserver_password: "{{ vault_c2_teamserver_password }}"

operator_vms:
  - "RT-OPS-01"
```

### APT VM groups

| ansible_group | Purpose | Terraform state |
|---|---|---|
| `red_team` | C2 servers and operator workstations | `terraform_red_team/` |
| `apt` | Pre-positioned implant VMs (appear as exercise endpoints) | `terraform_red_team/` |

---

## SOC Layouts

SOC layouts live in `SOC_LAYOUTS/<NAME>/` and define the Blue Team's defensive infrastructure:

```
SOC_LAYOUTS/
├── TEMPLATE/               # Copy this to create a new layout
│   ├── layout.yml          # SOC identity, Malcolm/sensor/firewall config
│   └── vms.yaml            # Blue Team VM fleet (VMIDs 1000-1099 range)
└── malcolm_basic/          # Malcolm + Hedgehog sensor + OPNsense + Kali Purple
```

### layout.yml key fields

```yaml
soc_layout:
  name: malcolm_basic
  description: "Malcolm network analysis SOC with OPNsense firewall"

malcolm:
  vm: "SOC-MALCOLM-01"      # Malcolm server VM hostname
  web_port: 443

sensors:
  - vm: "SOC-HH-01"         # Hedgehog Linux sensor VM hostname
    capture_interface: eth1
    malcolm_server: "SOC-MALCOLM-01"

firewall:
  vm: "SOC-FW-01"           # OPNsense firewall VM hostname
  management_ip: "10.0.1.1"

analysts:
  - vm: "SOC-WKS-01"        # Kali Purple analyst workstation
    malcolm_url: "https://10.0.1.10"
```

### SOC VM groups

| ansible_group | Purpose | Terraform state |
|---|---|---|
| `soc` | SOC servers (Malcolm, SIEM, sensors, firewalls) | `terraform_blue_team/` |
| `blue_team` | Analyst workstations | `terraform_blue_team/` |

---

## Quick Reference

```bash
# ── Full Exercise Standup ────────────────────────────────────────────────────

# 0. Load config (prereq for all subsequent phases)
ansible-playbook playbooks/exercise_initiation.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 1. Build missing Packer templates + stage RAID-local copies (Phase 1 + 1b combined)
ansible-playbook playbooks/template_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 1b. (Optional standalone) Re-stage templates without rebuilding them
ansible-playbook playbooks/template_staging.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 2. Deploy scenario VMs via Terraform
ansible-playbook playbooks/vm_management.yml \
  -e "exercise=OBSIDIAN_DAGGER action=deploy" -e "@Secrets/credentials.yml" --ask-vault-pass

# 3. Write dynamic inventory
ansible-playbook playbooks/inventory_refresh.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 4. Power on VMs and wait for readiness
ansible-playbook playbooks/vm_power_management.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 5. Configure Proxmox SDN + VyOS routers
ansible-playbook playbooks/network_management.yml \
  -e "exercise=OBSIDIAN_DAGGER action=deploy" -e "@Secrets/credentials.yml" --ask-vault-pass

# 6. Base OS configuration (servers and workstations)
ansible-playbook playbooks/server_configuration.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass
ansible-playbook playbooks/workstation_configuration.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 7. Active Directory
ansible-playbook playbooks/domain_management.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 8. Application services (SQL, Exchange, SCCM — as enabled in scenario.phases.services)
ansible-playbook playbooks/domain_services.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# 9. Red Team deployment (uses scenario.red_team.apt; override with -e "apt=APT29")
ansible-playbook playbooks/red_team_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER action=deploy" -e "@Secrets/credentials.yml" --ask-vault-pass

# 10. Blue Team deployment (uses scenario.blue_team.layout; override with -e "layout=malcolm_basic")
ansible-playbook playbooks/blue_team_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER action=deploy" -e "@Secrets/credentials.yml" --ask-vault-pass

# 11. Deploy SIEM endpoint agents to monitored VMs
ansible-playbook playbooks/endpoint_agent_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER" -e "@Secrets/credentials.yml" --ask-vault-pass

# ── Teardown ────────────────────────────────────────────────────────────────

ansible-playbook playbooks/red_team_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER action=destroy" -e "@Secrets/credentials.yml" --ask-vault-pass

ansible-playbook playbooks/blue_team_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER action=destroy" -e "@Secrets/credentials.yml" --ask-vault-pass

ansible-playbook playbooks/vm_management.yml \
  -e "exercise=OBSIDIAN_DAGGER action=destroy" -e "@Secrets/credentials.yml" --ask-vault-pass

ansible-playbook playbooks/network_management.yml \
  -e "exercise=OBSIDIAN_DAGGER action=destroy" -e "@Secrets/credentials.yml" --ask-vault-pass

# ── Force rebuild all Packer templates ──────────────────────────────────────

ansible-playbook playbooks/template_deployment.yml \
  -e "exercise=OBSIDIAN_DAGGER force_rebuild=true" -e "@Secrets/credentials.yml" --ask-vault-pass
```

---

## Template Registry

Defined in `inventory/group_vars/all.yml` → `template_registry`. All templates have planned Packer build files.

### VMID Namespace Allocation

| Range | Storage | Purpose |
|---|---|---|
| `2000–2099` | QNAP | Packer master / golden templates (shared NAS) |
| `2100–2199` | RAID (cdx-pve-01) | Staged copies for linked-clone source on node 01 |
| `2200–2299` | RAID (cdx-pve-02) | Staged copies for linked-clone source on node 02 |
| `2300–2399` | RAID (cdx-pve-03) | Staged copies for linked-clone source on node 03 |

Staged VMID formula: `staged_vmid = master_vmid + proxmox_node_template_offset[node]`
(offsets: cdx-pve-01 = +100, cdx-pve-02 = +200, cdx-pve-03 = +300)

Templates flagged `qnap_direct: true` (e.g. `vyos`) are linked-cloned directly from QNAP and are never staged to RAID.

### Template Inventory

Staged VMID = QNAP master VMID + per-node offset. `vyos` is `qnap_direct: true` — linked-cloned directly from the QNAP master; never RAID-staged.

> **NIC policy:** All Packer builds strip every `net*` interface from the build VM via the Proxmox API (`scripts/common/strip-nics.sh`) before converting to a template. Templates have no NICs. Terraform populates all NIC definitions when cloning exercise VMs.

| Key | OS | Status | QNAP | pve-01 | pve-02 | pve-03 |
|---|---|---|---|---|---|---|
| `vyos` | VyOS 2025 | planned | 2017 | — | — | — |
| `opnsense` | OPNsense 25.7 | planned | 2043 | 2143 | 2243 | 2343 |
| `server_2025` | Windows Server 2025 | built | 2037 | 2137 | 2237 | 2337 |
| `server_2025_core` | Windows Server 2025 Core | planned | 2050 | 2150 | 2250 | 2350 |
| `server_2022` | Windows Server 2022 | built | 2033 | 2133 | 2233 | 2333 |
| `server_2022_core` | Windows Server 2022 Core | planned | 2034 | 2134 | 2234 | 2334 |
| `server_2019` | Windows Server 2019 | built | 2031 | 2131 | 2231 | 2331 |
| `server_2019_core` | Windows Server 2019 Core | planned | 2032 | 2132 | 2232 | 2332 |
| `server_2016` | Windows Server 2016 | built | 2029 | 2129 | 2229 | 2329 |
| `server_2016_core` | Windows Server 2016 Core | planned | 2030 | 2130 | 2230 | 2330 |
| `server_2012r2` | Windows Server 2012 R2 | built | 2026 | 2126 | 2226 | 2326 |
| `server_2012r2_core` | Windows Server 2012 R2 Core | planned | 2027 | 2127 | 2227 | 2327 |
| `server_2008r2` | Windows Server 2008 R2 | built | 2024 | 2124 | 2224 | 2324 |
| `server_2008r2_core` | Windows Server 2008 R2 Core | planned | 2023 | 2123 | 2223 | 2323 |
| `windows_11` | Windows 11 | built | 2036 | 2136 | 2236 | 2336 |
| `windows_10` | Windows 10 | built | 2035 | 2135 | 2235 | 2335 |
| `windows_8.1` | Windows 8.1 | built | 2028 | 2128 | 2228 | 2328 |
| `windows_7` | Windows 7 | built | 2025 | 2125 | 2225 | 2325 |
| `kali` | Kali Linux 2025.4 | built | 2018 | 2118 | 2218 | 2318 |
| `kali_purple` | Kali Purple 2025.4 | in-progress | 2016 | 2116 | 2216 | 2316 |
| `parrot` | Parrot OS | planned | 2048 | 2148 | 2248 | 2348 |
| `ubuntu_2110` | Ubuntu 21.10 | built | 2021 | 2121 | 2221 | 2321 |
| `ubuntu_server_1604` | Ubuntu Server 16.04 | built | 2022 | 2122 | 2222 | 2322 |
| `debian_12` | Debian 12.9 (Bookworm) | ready | 2038 | 2138 | 2238 | 2338 |
| `debian_13` | Debian 13.3.0 (Trixie) | ready | 2039 | 2139 | 2239 | 2339 |
| `centos_7` | CentOS 7 | built | 2019 | 2119 | 2219 | 2319 |
| `centos_7_server` | CentOS 7 Server | built | 2020 | 2120 | 2220 | 2320 |
| `centos_7_gnome` | CentOS 7 GNOME | planned | 2040 | 2140 | 2240 | 2340 |
| `docker_base` | Docker Host (Ubuntu) | planned | 2045 | 2145 | 2245 | 2345 |
| `commando_vm` | Commando VM (Win 10) — Mandiant | built | 2044 | 2144 | 2244 | 2344 |
| `flare_vm` | FLARE VM (Windows) — Mandiant | built | 2049 | 2149 | 2249 | 2349 |
| `cobalt_strike_c2` | Cobalt Strike C2 Server | planned | 2041 | 2141 | 2241 | 2341 |
| `adaptix_c2` | Adaptix C2 Server | planned | 2042 | 2142 | 2242 | 2342 |
| `hh_sensor` | Hedgehog Linux (Sensor) | planned | 2046 | 2146 | 2246 | 2346 |
| `malcolm_server` | Malcolm Network Analysis | planned | 2047 | 2147 | 2247 | 2347 |

---

## CDX-RELAY Infrastructure

The CDX-RELAY is a **persistent** Debian 13 VM (VMID 102, `10.0.0.10/22`) that provides management connectivity to all exercise VMs. It is provisioned once and shared across all exercises. Exercise VMs have **no Layer0 management NIC** — all Ansible connections route through the relay.

### Connectivity model

| VM type | Protocol | Path |
|---|---|---|
| Linux / VyOS | SSH | ProxyJump via `ansible@10.0.0.10` |
| Windows | WinRM | SOCKS5 proxy via `10.0.0.10:1080` |

### Relay networking

| Interface | Bridge | Address | Purpose |
|---|---|---|---|
| eth0 | Layer0 | 10.0.0.10/22 (static) | ACN management — Ansible controller connects here |
| eth1 | EQIX4 | 10.1.1.2/30 (static) | CDX-I Internet uplink |
| eth2–4 | Dynamic | Per-exercise | Hot-attached by `configure_relay` at exercise start |

Exercise routes (enterprise, SOC, red team segments) live **on the relay only** — never on the ACN — to avoid conflicts with CDX-I public IP address space.

### One-time provisioning

```bash
# 1. Build the Debian 13 base template (if not already on Proxmox)
cd INFRASTRUCTURE/packer/templates
packer build \
  -var-file=../vars/common.pkrvars.hcl \
  -var-file=../vars/debian_13.pkrvars.hcl \
  debian-13.pkr.hcl

# 2. Provision and configure the relay VM
ansible-playbook playbooks/provision_relay.yml \
  -e "@secrets/credentials.yml" --ask-vault-pass
```

### Mid-pipeline NIC management

The `configure_relay` role is called by `exercise_initiation.yml` / teardown playbooks:

```yaml
- role: configure_relay
  vars:
    relay_action: assign_nics        # provision | assign_nics | release_nics | verify
    relay_nic_assignments:
      - { slot: 2, bridge: "Enterprise", ip: "192.168.10.1", cidr: "24" }
      - { slot: 3, bridge: "SOC",        ip: "192.168.20.1", cidr: "24" }
    relay_routes:
      - { net: "192.168.10.0/24", via: "eth2" }
      - { net: "192.168.20.0/24", via: "eth3" }
```

---

## Proxmox Cluster Defaults

Set in `inventory/group_vars/all.yml`. Override via `-e` or `Secrets/credentials.yml`.

| Setting | Default | Key |
|---|---|---|
| API host | `cdx-pve-01` | `proxmox_api_host` |
| API port | `8006` | `proxmox_api_port` |
| API user | `ansible@pam` | `proxmox_api_user` |
| Token ID | `ansible` | `proxmox_api_token_id` |
| Validate certs | `false` | `proxmox_validate_certs` |
| Template node | `cdx-pve-01` | `template_node` |
| Template storage (QNAP) | `QNAP` | `packer_template_storage` |
| Clone storage (RAID) | `raid` | `vm_clone_storage` |
| Clone type | `linked` | `vm_clone_type` |
| VM timezone | `UTC` | `vm_timezone` |
| Guest agent delay | `30s` | `guest_agent_initial_delay` |
| WinRM/SSH wait timeout | `300s` | `vm_power_wait_timeout` |

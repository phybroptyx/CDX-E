# CDX-E Playbooks Reference

This directory contains one playbook per pipeline phase. All phases are orchestrated by
`site.yml` at the project root. Individual playbooks can also be run standalone for targeted
operations.

---

## Pipeline Overview

```
site.yml
  Phase 0   exercise_initiation.yml       — load scenario config (always runs)
  Phase 1   template_deployment.yml       — Packer template builds + RAID staging
  Phase 2   vm_management.yml             — Terraform: deploy/destroy scenario VMs
  Phase 2.5 network_management.yml        — OVS bridge creation (pre-power-on)
  Phase 2a  inventory_refresh.yml         — write dynamic inventory from TF outputs
  Phase 2b  vm_power_management.yml       — power on VMs, wait for connectivity
  Phase 3   network_management.yml        — VyOS router configuration (VMs now running)
  Phase 4   domain_management.yml         — Active Directory + GPOs
  Phase 5   server_configuration.yml      — base config for member servers
  Phase 6   domain_services.yml           — DHCP, SQL, Exchange, SCCM, IIS (conditional)
  Phase 7   workstation_configuration.yml — base config for workstation endpoints
  Phase 8   vulnerability_deployment.yml  — intentional vulnerable configs (optional)
  Phase 9   red_team_deployment.yml       — Red Team / APT infrastructure (optional)
  Phase 10  blue_team_deployment.yml      — Blue Team / SOC infrastructure (optional)

Standalone (not in site.yml pipeline):
  cluster_setup.yml           — one-time Proxmox cluster bootstrap
  environment_check.yml       — pre-exercise readiness validation
  template_staging.yml        — re-stage RAID template copies without rebuilding
  dhcp_management.yml         — targeted DHCP configuration
  sql_management.yml          — targeted SQL Server deployment
  exchange_management.yml     — targeted Exchange deployment
  sccm_management.yml         — targeted SCCM deployment
  iis_management.yml          — targeted IIS configuration
  endpoint_agent_deployment.yml — SIEM agent deployment (White Cell operational)
```

---

## Phase Gate Flags

Each pipeline phase is controlled by a flag in `scenario.yml`. Phases default as shown.
Set to `false` to skip a phase entirely without modifying the command line.

```yaml
phases:
  packer:       true    # Phase 1 — build missing Packer templates
  terraform:    true    # Phase 2, 2a, 2b — VM provisioning + inventory + power-on
  networking:   true    # Phase 2.5 + 3 — OVS bridges + VyOS config
  domain:       true    # Phase 4 — Active Directory
  servers:      true    # Phase 5 — server base configuration
  services:
    dhcp:       false   # Phase 6 — DHCP Server
    sql:        false   # Phase 6 — SQL Server
    exchange:   false   # Phase 6 — Microsoft Exchange (requires sql: true)
    sccm:       false   # Phase 6 — SCCM/MECM (requires sql: true)
    iis:        false   # Phase 6 — IIS Web Server
  workstations: true    # Phase 7 — workstation base configuration
  vulnerabilities: false # Phase 8 — vulnerability deployment
  red_team:     false   # Phase 9 — Red Team / adversary infrastructure
  blue_team:    false   # Phase 10 — Blue Team / SOC infrastructure
  endpoint_agents: false # Phase 11 — SIEM agent deployment
```

---

## Pipeline Playbooks

### Phase 0 — `exercise_initiation.yml`

**Role:** `read_exercise_config`

Loads `EXERCISES/<name>/scenario.yml` and `EXERCISES/<name>/vms.yaml`, validates their
structure, and sets cacheable Ansible facts (`scenario`, `virtual_machines`,
`network_topology`, `exercise_dir`) for all subsequent plays in the run.

Always runs first. Tagged `always` — `--tags` filtering does not skip it.

**Standalone use:** Almost never run in isolation; it runs as a pre-play in every
multi-playbook execution. Run standalone only to verify that a new exercise's configuration
files parse cleanly before attempting a full pipeline run.

```bash
ansible-playbook playbooks/exercise_initiation.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 1 — `template_deployment.yml`

**Roles:** `read_exercise_config` → `deploy_packer_template` → `stage_templates`

**Part A — Packer build (`deploy_packer_template`):**
Queries Proxmox for existing VM templates. Derives which templates are needed from
`virtual_machines[].template` keys in `vms.yaml`. Builds any missing templates using
Packer against the QNAP NAS. Validates post-build by re-querying Proxmox.

**Part B — RAID staging (`stage_templates`):**
Full-copies QNAP master templates to per-node RAID storage. Terraform then creates
linked clones from these RAID-local copies, keeping all VM I/O off the NAS. Skips
templates flagged `qnap_direct: true` and VMIDs already present on the target node.

**Gates on:** `scenario.phases.packer` (Part A). Part B always runs unless `action=destroy`.

**Standalone use:** Run when you need to force-rebuild a specific template (`force_rebuild=true`)
or when RAID-local copies are stale after a QNAP master update.

```bash
# Normal run (build missing + stage)
ansible-playbook playbooks/template_deployment.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass

# Force rebuild all templates (ignores existing Proxmox entries)
ansible-playbook playbooks/template_deployment.yml \
  -e "exercise=MY_EXERCISE force_rebuild=true" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 1b (standalone) — `template_staging.yml`

**Role:** `read_exercise_config` → `stage_templates`

Re-stages QNAP master templates to RAID without running Packer. Use this when RAID copies
have been deleted (e.g., after manually cleaning up stale staged templates following a QNAP
master rebuild) and you do not need to rebuild the templates themselves.

Supports `proxmox_node_override` to stage to a specific node regardless of the scenario default.

```bash
ansible-playbook playbooks/template_staging.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass

# Stage to a specific node
ansible-playbook playbooks/template_staging.yml \
  -e "exercise=MY_EXERCISE proxmox_node_override=cdx-pve-02" \
  -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 2 — `vm_management.yml`

**Roles:** `read_exercise_config` → `deploy_scenario` (deploy) | `destroy_scenario` (destroy)

Generates a Terraform configuration from the scenario's `vms.yaml` and applies it to
Proxmox. On deploy, VMs are created as linked clones and left **powered off** — power-on
is handled separately in Phase 2b. On destroy, Terraform removes all scenario VMs and
deletes the exercise resource pool.

Excludes team-tier VMs (`red_team`, `blue_team`, `soc`, `apt` groups) — those are handled
by `red_team_deployment.yml` and `blue_team_deployment.yml`.

**Gates on:** `scenario.phases.terraform`

```bash
# Deploy
ansible-playbook playbooks/vm_management.yml \
  -e "exercise=MY_EXERCISE action=deploy" -e "@../secrets/credentials.yml" --ask-vault-pass

# Destroy
ansible-playbook playbooks/vm_management.yml \
  -e "exercise=MY_EXERCISE action=destroy" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 2a — `inventory_refresh.yml`

**Roles:** `read_exercise_config` + `read_apt_config` + `read_soc_layout` → `inventory_refresh`

Reads Terraform state outputs from all three exercise state directories
(`terraform/`, `terraform_red_team/`, `terraform_blue_team/`), cross-references with
VM specifications, and writes `inventory/exercise_hosts.yml`. Also refreshes the
in-memory Ansible inventory so subsequent plays can target VMs by group.

Must run **after** `vm_management.yml` (Terraform state must exist) and **before**
`vm_power_management.yml` (IPs must be in inventory for connectivity waits).

Runs on `localhost` — VMs do not need to be powered on.

**Gates on:** `scenario.phases.terraform`

```bash
ansible-playbook playbooks/inventory_refresh.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 2b — `vm_power_management.yml`

**Role:** `vm_power_management`

Powers on all scenario VMs via the Proxmox API. Performs a pre-check to identify
already-running VMs (idempotent — will not attempt to start them again). After power-on:

1. Waits for the QEMU guest agent to respond (OS has booted)
2. Queries the guest agent for actual management IPs (handles cloud-init reboot window)
3. Waits for WinRM (port 5985) or SSH (port 22) connectivity on the discovered management IP
4. Writes discovered management IPs to `inventory/host_vars/<vm-name>.yml` and updates
   in-memory inventory for the pipeline run

Must run **after** `inventory_refresh.yml` and bridge creation (Phase 2.5).

**Gates on:** `scenario.phases.terraform`

```bash
ansible-playbook playbooks/vm_power_management.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml"
```

---

### Phase 2.5 + Phase 3 — `network_management.yml`

**Roles:** `configure_networking` (deploy) | `revert_networking` (destroy)

**Two invocations in `site.yml`:**

**Phase 2.5** (`networking_scope=bridges`): Creates exercise OVS bridges on Proxmox nodes
*before* VMs are powered on. Proxmox refuses to start a VM whose configured bridge does not
exist. Skips VyOS router configuration (routers are not yet running).

**Phase 3** (full scope): Idempotently re-applies bridge configuration, then pushes
per-router VyOS CLI config files (`EXERCISES/<name>/VyOS/<vm-name>.conf`) via SSH.

On destroy (`action=destroy`), restores the base-only `/etc/network/interfaces` on each
Proxmox node, removing all exercise-specific bridges. VyOS routers are not modified on
destroy (they persist across exercises).

**Gates on:** `scenario.phases.networking`

```bash
# Deploy (apply bridges + VyOS config)
ansible-playbook playbooks/network_management.yml \
  -e "exercise=MY_EXERCISE action=deploy" -e "@../secrets/credentials.yml"

# Destroy (revert to base network)
ansible-playbook playbooks/network_management.yml \
  -e "exercise=MY_EXERCISE action=destroy" -e "@../secrets/credentials.yml"
```

---

### Phase 4 — `domain_management.yml`

**Roles:** `read_exercise_config` → `configure_vm` → `install_windowsfeature` →
`configure_active_directory` → `deploy_group_policy_objects`

Targets: `domain_controllers` inventory group. Runs `serial: 1` to ensure DCs are
promoted one at a time, preventing replication conflicts.

Performs the full Active Directory lifecycle:
- Promotes first DC (new forest/domain from `scenario.yml` settings)
- Promotes additional DCs as replicas
- Creates OU structure, AD sites and subnets, site links
- Populates users and groups
- Creates and links GPOs (supports schema v1.0 and v2.0)

**Gates on:** `scenario.phases.domain`

**Standalone use:** Re-run to re-apply GPO changes or add new OUs/users without redeploying VMs.

```bash
ansible-playbook playbooks/domain_management.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 5 — `server_configuration.yml`

**Roles:** `read_exercise_config` → `configure_vm` → `install_windowsfeature`

Targets: `servers` inventory group (member servers — not DCs, not workstations).

Applies base OS configuration (hostname, timezone, WinRM, PS policy, local admin,
auto-update disabled) and installs Windows features from the `servers` feature set defined
in `inventory/group_vars/all.yml`.

**Gates on:** `scenario.phases.servers`

**Standalone use:** Re-run after adding a new member server VM to an existing exercise,
or to remediate a misconfigured server without touching DCs or workstations.

```bash
ansible-playbook playbooks/server_configuration.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 6 — `domain_services.yml`

**Roles:** `read_exercise_config` → (per service) `configure_vm` + `install_windowsfeature` +
`deploy_dhcp` | `deploy_sql_server` | `deploy_microsoft_exchange` | `deploy_configuration_manager`

Multi-service orchestrator. Each service is a separate play gated on its own
`scenario.phases.services.<service>` flag. Services are independent except:
- Exchange requires SQL (`scenario.phases.services.sql: true`)
- SCCM requires SQL (`scenario.phases.services.sql: true`)

Targets: `dhcp_servers`, `sql_servers`, `exchange_servers`, `sccm_servers`, `iis_servers`
inventory groups (populated from `ansible_group` in `vms.yaml`).

**Standalone use:** Use individual service playbooks (`dhcp_management.yml`,
`sql_management.yml`, etc.) for targeted operations. The service-specific playbooks
perform the same role calls but can be targeted without loading the full service orchestrator.

```bash
ansible-playbook playbooks/domain_services.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 7 — `workstation_configuration.yml`

**Roles:** `read_exercise_config` → `configure_vm` → `install_windowsfeature`

Targets: `workstations` inventory group (Windows 7, 10, 11 endpoints).

Same role pipeline as `server_configuration.yml` but targets the workstation host group.
Feature set comes from `windows_feature_sets['workstations']` in `all.yml`.

**Gates on:** `scenario.phases.workstations`

```bash
ansible-playbook playbooks/workstation_configuration.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 8 — `vulnerability_deployment.yml`

**Role:** `deploy_vulnerability`

Deploys intentionally insecure configurations and vulnerable applications to designated
hosts per the scenario specification. Supports Red Team objectives and Blue Team detection
training.

> **Warning:** This playbook intentionally introduces security weaknesses. Only run against
> isolated CDX range hosts.

**Gates on:** `scenario.phases.vulnerabilities` (default: `false`)

```bash
ansible-playbook playbooks/vulnerability_deployment.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml"
```

---

### Phase 9 — `red_team_deployment.yml`

**Roles:** `read_exercise_config` + `read_apt_config` → `deploy_red_team` | `destroy_red_team`
→ `vm_power_management` (target_tier=red_team) → `configure_red_team`

**Play 1 (Provisioning):** Loads APT profile, generates Terraform configuration from
`APTs/<apt>/vms.yaml`, and applies it to Proxmox (or destroys on `action=destroy`).
Red Team VMs use a separate Terraform state directory (`terraform_red_team/`).

**Play 2 (Configuration):** Powers on Red Team VMs and configures C2 platforms and
operator tooling per `apt.yml`. Only runs on deploy.

APT profile selection: runtime `-e "apt=APT29"` overrides `scenario.red_team.apt` which
overrides the default `GENERIC_RED`.

**Gates on:** `scenario.phases.red_team` (default: `false`)

```bash
# Deploy
ansible-playbook playbooks/red_team_deployment.yml \
  -e "exercise=MY_EXERCISE action=deploy" -e "@../secrets/credentials.yml" --ask-vault-pass

# Deploy with explicit APT override
ansible-playbook playbooks/red_team_deployment.yml \
  -e "exercise=MY_EXERCISE action=deploy apt=APT29" -e "@../secrets/credentials.yml" --ask-vault-pass

# Destroy
ansible-playbook playbooks/red_team_deployment.yml \
  -e "exercise=MY_EXERCISE action=destroy" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Phase 10 — `blue_team_deployment.yml`

**Roles:** `read_exercise_config` + `read_soc_layout` → `deploy_blue_team` | `destroy_blue_team`
→ `vm_power_management` (target_tier=blue_team) → `configure_blue_team`

Mirrors the Red Team deployment pattern for Blue Team infrastructure. Provisions Blue Team
VMs from `SOC_LAYOUTS/<layout>/vms.yaml`, powers them on, and configures the SOC stack
(Malcolm, Hedgehog sensor, analyst workstations).

SOC layout selection: runtime `-e "layout=malcolm_extended"` overrides
`scenario.blue_team.layout` which overrides the default `malcolm_basic`.

**Gates on:** `scenario.phases.blue_team` (default: `false`)

```bash
# Deploy
ansible-playbook playbooks/blue_team_deployment.yml \
  -e "exercise=MY_EXERCISE action=deploy" -e "@../secrets/credentials.yml" --ask-vault-pass

# Deploy with layout override
ansible-playbook playbooks/blue_team_deployment.yml \
  -e "exercise=MY_EXERCISE action=deploy layout=malcolm_extended" \
  -e "@../secrets/credentials.yml" --ask-vault-pass

# Destroy
ansible-playbook playbooks/blue_team_deployment.yml \
  -e "exercise=MY_EXERCISE action=destroy" -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

## Standalone-Only Playbooks

These playbooks are not included in `site.yml` and are run independently for specific
operational purposes.

---

### `cluster_setup.yml`

**Role:** `configure_proxmox_nodes`

One-time cluster bootstrap. Installs OVS and `ifupdown2` prerequisites on all Proxmox
cluster nodes, then deploys the base `/etc/network/interfaces` from each node's
vault-encrypted `host_vars`. Pre-creates the CDX-I OVS bridge and SOC trunk port.

Does **not** require `exercise` to be specified. Idempotent — safe to re-run after adding
a new node.

**Prerequisites:** SSH (root) access from the controller to all cluster nodes; `host_vars`
populated and vault-encrypted for all nodes.

```bash
ansible-playbook playbooks/cluster_setup.yml \
  -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### `environment_check.yml`

**Role:** `check_network_paths`

> **Status:** Role stub — not yet implemented.

Intended for White Cell to run immediately before exercise start to validate network
connectivity across all scenario hosts. Will confirm expected network paths are functional
and surface any misconfigured routers or firewall rules before players connect.

```bash
ansible-playbook playbooks/environment_check.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml"
```

---

### `endpoint_agent_deployment.yml`

**Role:** `read_exercise_config` → `deploy_endpoint_agents`

Deploys SIEM endpoint agents to all VMs tagged with `monitor: true` in `vms.yaml`.
White Cell controls monitoring scope via the `monitor:` flag — VMs without `monitor: true`
are skipped entirely.

Supports multiple agent platforms:
- `wazuh` (default) — Wazuh agent; Windows and Linux
- `elastic` — Elastic Agent (requires Fleet server pre-configured)
- `splunk_uf` — Splunk Universal Forwarder

Typically run after `blue_team_deployment.yml` so the SOC SIEM is ready to receive data.

```bash
ansible-playbook playbooks/endpoint_agent_deployment.yml \
  -e "exercise=MY_EXERCISE" -e "@../secrets/credentials.yml" --ask-vault-pass

# Override agent platform
ansible-playbook playbooks/endpoint_agent_deployment.yml \
  -e "exercise=MY_EXERCISE endpoint_agent_platform=elastic" \
  -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

### Service-Specific Playbooks

These are equivalent to the individual plays inside `domain_services.yml` but can be run
in isolation. Use them for targeted re-deployment, remediation, or when only one service
needs to be updated without running the full service orchestrator.

Each requires the exercise to have already progressed through Phase 4 (Active Directory).

| Playbook | Target Group | Role(s) | Phase Gate |
|---|---|---|---|
| `dhcp_management.yml` | `dhcp_servers` | `configure_vm`, `install_windowsfeature` | `scenario.phases.services.dhcp` |
| `sql_management.yml` | `sql_servers` | `configure_vm`, `install_windowsfeature`, `deploy_sql_server` | `scenario.phases.services.sql` |
| `exchange_management.yml` | `exchange_servers` | `configure_vm`, `install_windowsfeature`, `deploy_microsoft_exchange` | `scenario.phases.services.exchange` |
| `sccm_management.yml` | `sccm_servers` | `configure_vm`, `install_windowsfeature`, `deploy_configuration_manager` | `scenario.phases.services.sccm` |
| `iis_management.yml` | `iis_servers` | `configure_vm`, `install_windowsfeature` | `scenario.phases.services.iis` |

```bash
# Example: re-deploy Exchange on an existing exercise
ansible-playbook playbooks/exchange_management.yml \
  -e "exercise=MY_EXERCISE exchange_version=2016" \
  -e "@../secrets/credentials.yml" --ask-vault-pass
```

---

## Common Variables

| Variable | Description | Default |
|---|---|---|
| `exercise` | Exercise name (directory under `EXERCISES/`) | — (required) |
| `action` | `deploy` or `destroy` | `deploy` |
| `apt` | APT profile override (Phase 9) | `scenario.red_team.apt` |
| `layout` | SOC layout override (Phase 10) | `scenario.blue_team.layout` |
| `force_rebuild` | Force Packer rebuild even if templates exist | `false` |
| `endpoint_agent_platform` | `wazuh`, `elastic`, or `splunk_uf` | `wazuh` |
| `proxmox_node_override` | Force template staging to a specific node | `scenario.proxmox.node` |
| `networking_scope` | `bridges` (SDN only) or `all` (SDN + VyOS) | `all` |

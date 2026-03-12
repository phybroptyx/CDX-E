# CDX-E Roles Reference

This document describes all roles in the CDX-E framework, organized by functional category.
Each role is designed to be called from a specific playbook (or set of playbooks) and expects
facts to be set by upstream roles in the same pipeline run.

---

## Role Categories

- [Configuration Loaders](#configuration-loaders) — load exercise/APT/SOC data into Ansible facts
- [Infrastructure Provisioning](#infrastructure-provisioning) — Packer, Terraform, Inventory
- [VM Lifecycle](#vm-lifecycle) — power management, OS base config, Windows features, domain join
- [Networking](#networking) — OVS SDN, VyOS router config, SOCKS5 relay tunnel
- [Active Directory](#active-directory) — DC promotion, OU structure, GPOs
- [Domain Services](#domain-services) — DHCP, SQL, Exchange, SCCM
- [Team Configuration](#team-configuration) — Red Team C2, Blue Team SOC stack
- [Operational](#operational) — agents, validation, cluster bootstrap
- [Stub / Placeholder](#stub--placeholder) — not yet implemented
- [Legacy](#legacy) — retained for reference only

---

## Configuration Loaders

### `read_exercise_config`

**Called from:** `exercise_initiation.yml` (pre-play in nearly every playbook)

Loads and validates the exercise configuration files, then sets cacheable Ansible facts
for use by all subsequent plays in the run.

**Input:** `-e "exercise=MY_EXERCISE"` on the command line.

**Steps:**
1. Asserts `exercise` variable is defined and non-empty
2. Validates `EXERCISES/<name>/` directory exists
3. Loads `scenario.yml` → `scenario` fact
4. Loads `vms.yaml` → `virtual_machines` fact
5. Validates `scenario.phases` and `virtual_machines` are present
6. Sets cacheable facts: `exercise_dir`, `scenario`, `virtual_machines`, `network_topology`
7. Displays scenario summary (exercise name, VM count, active phases)

**Facts set:**

| Fact | Description |
|---|---|
| `exercise_dir` | Absolute path to `EXERCISES/<name>/` |
| `scenario` | Parsed `scenario.yml` content |
| `virtual_machines` | List of VM objects from `vms.yaml` |
| `network_topology` | `network_topology` block from `vms.yaml` (default: `{}`) |

---

### `read_apt_config`

**Called from:** `red_team_deployment.yml` + `inventory_refresh.yml` (pre-play)

Loads an APT adversary profile from the `APTs/` library and sets cacheable facts.

**APT selection priority (highest wins):**
1. Runtime: `-e "apt=APT29"`
2. Scenario: `scenario.red_team.apt`
3. Default: `GENERIC_RED`

**Steps:**
1. Resolves APT name from the priority chain
2. Validates `APTs/<name>/` directory exists
3. Loads `apt.yml` → validates `apt.name`, `c2_platforms` (≥1), `operator_vms` (≥1)
4. Loads `vms.yaml` → validates `virtual_machines` (≥1)
5. Sets cacheable facts
6. Displays APT profile summary

**Facts set:**

| Fact | Description |
|---|---|
| `apt_name` | Resolved APT directory name (e.g., `GENERIC_RED`) |
| `apt_dir` | Absolute path to the APT directory |
| `apt_config` | Parsed `apt.yml` content |
| `apt_vms` | List of VM objects from APT `vms.yaml` |

---

### `read_soc_layout`

**Called from:** `blue_team_deployment.yml` + `inventory_refresh.yml` (pre-play)

Loads a SOC layout from the `SOC_LAYOUTS/` library and sets cacheable facts. Mirrors
`read_apt_config` in structure.

**Layout selection priority (highest wins):**
1. Runtime: `-e "layout=malcolm_extended"`
2. Scenario: `scenario.blue_team.layout`
3. Default: `malcolm_basic`

**Facts set:**

| Fact | Description |
|---|---|
| `soc_layout_name` | Resolved layout directory name |
| `soc_layout_dir` | Absolute path to the layout directory |
| `soc_layout` | Parsed `layout.yml` content |
| `soc_vms` | List of VM objects from layout `vms.yaml` |

---

## Infrastructure Provisioning

### `deploy_packer_template`

**Called from:** `template_deployment.yml` (Phase 1)

Checks Proxmox for existing VM templates and builds any missing ones using Packer.

**Steps:**
1. Asserts `virtual_machines` and `scenario` facts are present
2. Validates Packer binary exists at `packer_binary`
3. Validates ISO creation tool (`xorriso` or `genisoimage`) is available
4. Derives required template keys from `virtual_machines[].template` (unique set)
5. Queries Proxmox cluster resources for existing templates
6. Computes `templates_to_build` = required minus existing (unless `force_rebuild=true`)
7. Early exits (no error) if all required templates already exist
8. Displays build plan
9. Initializes Packer plugins (skipped if pre-staged offline)
10. Runs `packer build` for each missing template
11. Re-queries Proxmox post-build to validate each template registered
12. Reports per-template build result

**Key variables:**

| Variable | Default | Description |
|---|---|---|
| `packer_binary` | `/usr/local/bin/packer` | Path to Packer binary |
| `packer_dir` | `../Packer` | Path to Packer build files directory |
| `force_rebuild` | `false` | Ignore existing templates and rebuild |
| `packer_template_map` | (see `defaults/main.yml`) | Template key → `.pkr.hcl` filename |

---

### `stage_templates`

**Called from:** `template_deployment.yml` (Phase 1b), `template_staging.yml` (standalone)

Full-copies QNAP master templates to per-node RAID storage so Terraform can create
linked clones locally. All VM I/O stays on RAID; the QNAP NAS is only read during staging.

**VMID formula:** `staged_vmid = master_vmid + proxmox_node_template_offset[node]`

Templates flagged `qnap_direct: true` (e.g., `vyos`) are skipped — they are linked-cloned
directly from QNAP at Terraform apply time.

Staged copies persist after exercise teardown. Destroy roles do not touch them.

**Key variables:**

| Variable | Description |
|---|---|
| `proxmox_node_override` | Override the target node (default: `scenario.proxmox.node`) |
| `proxmox_node_template_offset` | Node → VMID offset map (defined in `all.yml`) |
| `template_registry` | Master template definitions (defined in `all.yml`) |

---

### `deploy_scenario`

**Called from:** `vm_management.yml` (action=deploy, Phase 2)

Generates a Terraform HCL configuration (`main.tf`) from the scenario's `virtual_machines`
list and applies it to Proxmox using the `bpg/proxmox` Terraform provider.

Excludes VMs whose `ansible_group` is in `team_groups` (red_team, blue_team, soc, apt) —
those are managed by `deploy_red_team` and `deploy_blue_team`.

VMs are left **powered off** after Terraform apply. Power-on is handled by `vm_power_management`.

State stored in `EXERCISES/<name>/terraform/`.

---

### `deploy_red_team`

**Called from:** `red_team_deployment.yml` (action=deploy)

Generates and applies Terraform configuration for Red Team VMs from `apt_vms`
(loaded by `read_apt_config`). State stored in `EXERCISES/<name>/terraform_red_team/`.
VMs are tagged with `pool_id: EX_<exercise>`.

---

### `deploy_blue_team`

**Called from:** `blue_team_deployment.yml` (action=deploy)

Generates and applies Terraform configuration for Blue Team VMs from `soc_vms`
(loaded by `read_soc_layout`). State stored in `EXERCISES/<name>/terraform_blue_team/`.

---

### `destroy_scenario`

**Called from:** `vm_management.yml` (action=destroy)

Runs `terraform destroy` on the scenario state directory, removing all scenario VMs.
Deletes the exercise Proxmox resource pool after VMs are removed. No-op if the Terraform
state directory does not exist.

---

### `destroy_red_team`

**Called from:** `red_team_deployment.yml` (action=destroy)

Runs `terraform destroy` on `terraform_red_team/`. Mirrors `destroy_scenario`.

---

### `destroy_blue_team`

**Called from:** `blue_team_deployment.yml` (action=destroy)

Runs `terraform destroy` on `terraform_blue_team/`. Mirrors `destroy_scenario`.

---

### `inventory_refresh`

**Called from:** `inventory_refresh.yml` (Phase 2a)

Reads Terraform state outputs from all three state directories, merges VM IP maps, and
writes `inventory/exercise_hosts.yml`. Also refreshes the in-memory Ansible inventory
so subsequent plays in the same pipeline run can target VMs by group.

**State directories checked:**

| Directory | VM Tier | Required |
|---|---|---|
| `EXERCISES/<name>/terraform/` | Scenario VMs | Yes |
| `EXERCISES/<name>/terraform_red_team/` | Red Team VMs | No (optional) |
| `EXERCISES/<name>/terraform_blue_team/` | Blue Team VMs | No (optional) |

**Output:** `inventory/exercise_hosts.yml` containing per-host variables:
- `ansible_host` — absent (populated later by `vm_power_management` via `host_vars/`)
- `cloud_init_ip` — exercise-network static IP (from `vms.yaml`)
- `ansible_group` — inventory group (e.g., `domain_controllers`)
- `ansible_os_type` — `windows`, `linux`, or `vyos`
- `cloud_init_ip` — exercise IP for use by service roles

---

## VM Lifecycle

### `vm_power_management`

**Called from:** `vm_power_management.yml` (Phase 2b), `red_team_deployment.yml`,
`blue_team_deployment.yml`

Powers on VMs via the Proxmox API, configures static IPs via QEMU guest-exec, migrates
DC NICs to the exercise bridge, and waits for management connectivity via the relay.
Supports three VM tiers via `target_tier`:

| `target_tier` | VM source |
|---|---|
| (unset) | `virtual_machines` — scenario VMs |
| `red_team` | `apt_vms` — Red Team VMs |
| `blue_team` | `soc_vms` — Blue Team VMs |

A `vm_include_groups` whitelist controls which groups are processed in each pipeline stage
(e.g., `domain_controllers` for Phase 2b-r, `workstations` for Phase 6.5).

**Readiness sequence:**
1. Pre-check current power state; filter to only VMs that need to be started (idempotent)
2. POST `/qemu/<vmid>/status/start` for each VM that isn't already running
3. Pause for initial boot delay (`guest_agent_initial_delay`)
4. Poll QEMU guest agent via `/agent/ping` until responsive
5. Windows: poll DHCP IP via `/agent/network-get-interfaces` (boot-complete signal)
6. Guest-exec: configure static exercise IP via PowerShell/netsh (modern) or WMI EnableStatic
   (legacy Windows 2008R2/Win7). No WinRM required — uses virtio-serial channel
7. Poll exec-status PIDs for completion
8. Verify exercise IP via QEMU guest agent; build `_vms_static_configured` allow-list
9. Read current DC net0 config (GET) to preserve MAC; PUT net0 to exercise bridge for DCs only
   (member servers and workstations clone directly onto exercise bridge — no migration needed)
10. Guest-exec: ensure WinRM is started after NIC bridge migration (no-op if already running)
11. Write exercise IP to `inventory/host_vars/<vm-name>.yml`; update in-memory `ansible_host`
12. Workstations (no `cloud_init.ip`): write QGA-discovered DHCP IP to `host_vars`
13. Wait for WinRM port 5985 (Windows) or SSH port 22 (Linux/VyOS) via relay (`delegate_to: cdx-relay`)

**Key timing variables (in `all.yml`):**

| Variable | Default | Description |
|---|---|---|
| `guest_agent_initial_delay` | `30` | Seconds to wait after power-on before polling |
| `guest_agent_poll_interval` | `10` | Seconds between guest agent poll attempts |
| `guest_agent_poll_retries` | `30` | Max poll attempts |
| `vm_power_wait_timeout` | `300` | Max seconds for port connectivity wait |
| `vm_power_wait_sleep` | `10` | Seconds between port checks |
| `windows_sysprep_settle_delay` | `60` | Flat pause after guest agent confirms boot, before DHCP poll |
| `dhcp_discovery_retries` | `30` | Max attempts for DHCP IP discovery via QGA |
| `dhcp_discovery_delay` | `10` | Seconds between DHCP discovery attempts |

---

### `configure_vm`

**Called from:** `server_configuration.yml`, `workstation_configuration.yml`,
`domain_management.yml`

Applies base OS configuration to each exercise VM. Branches on `ansible_os_type`.

**Windows tasks (in order):**
- `wait_for` port 5985 delegated to `cdx-relay` (confirms NIC migration complete and VM
  is reachable via relay SOCKS5 proxy before any WinRM tasks run)
- `win_ping` retry loop (NTLM handshake — confirms WinRM is functionally ready, not just
  TCP-open; retries 20 times × 15s to handle post-Sysprep WinRM initialization delay)
- Set hostname; reboot if changed
- Set timezone (`vm_timezone`, Windows format e.g. `"Eastern Standard Time"`)
- Disable automatic updates and auto-reboot (registry)
- Set PowerShell execution policy to `Unrestricted`
- Ensure `ansible_user` is in local Administrators (skipped for `domain_controllers` —
  cdxadmin is a domain account post-promotion; Domain Admins are already in Administrators)
- Ensure WinRM NTLM and Basic auth are enabled
- Disable IPv6 on all adapters if `scenario.network.disable_ipv6: true`

**Linux tasks:**
- Set hostname
- Set timezone (IANA format, e.g. `"UTC"`)
- Disable `unattended-upgrades` service (non-fatal if not installed)

**VyOS:** Skipped — VyOS routers are managed entirely by `configure_networking`.

---

### `install_windowsfeature`

**Called from:** `domain_management.yml`, `server_configuration.yml`,
`workstation_configuration.yml`, and all `domain_services.yml` service plays

Skips Linux and VyOS hosts automatically. Installs Windows Server roles and features
appropriate for each host's `ansible_group`.

**Feature resolution (priority order):**
1. `windows_features` — explicit list set on the host (full override)
2. `windows_feature_sets[ansible_group]` + `windows_features_extra` — group default from
   `all.yml`, optionally extended per-host with `windows_features_extra: [...]`
3. Empty list — no features; role skips cleanly

Management tools and sub-features are included by default. A reboot is performed
immediately if any feature reports `reboot_required`.

**Key variables:**

| Variable | Description |
|---|---|
| `windows_feature_sets` | Dict mapping group name → feature list (in `all.yml`) |
| `windows_features` | Per-host full override list |
| `windows_features_extra` | Per-host additions to the group default |
| `windowsfeature_include_mgmt_tools` | Include management tools (default: `true`) |

---

## Networking

### `relay_tunnel`

**Called from:** Pre-play in `domain_management.yml`, `server_configuration.yml`,
`workstation_configuration.yml`, `domain_services.yml`, `exercise_initiation.yml`;
`relay_tunnel_teardown.yml` (standalone)

Manages the SSH dynamic-forwarding SOCKS5 tunnel from the ACN to the CDX-RELAY VM.
All WinRM connections from Ansible route through this tunnel via
`socks5://127.0.0.1:{{ relay_tunnel_port }}` (set in `group_vars/windows_hosts.yml`).

Always runs on `localhost` (the ACN). Does not touch the relay VM itself.

**Actions:**

| Action | Behavior |
|---|---|
| `open` | Checks for existing PID file and running process; starts `ssh -D <port> -N -f` if not already running (idempotent) |
| `close` | Kills the process by PID file and removes the PID file |

**Key variables:**

| Variable | Default | Description |
|---|---|---|
| `relay_tunnel_action` | `open` | `open` or `close` |
| `relay_tunnel_host` | `10.0.0.10` | CDX-RELAY management IP (Layer0 static) |
| `relay_tunnel_user` | `cdxadmin` | SSH user on relay |
| `relay_tunnel_key` | `~/.ssh/id_ed25519` | SSH key path on ACN |
| `relay_tunnel_port` | `1080` | Local SOCKS5 port (must match `windows_hosts.yml`) |
| `relay_tunnel_pid_file` | `/tmp/cdx_relay_tunnel.pid` | PID file location on ACN |

---

### `configure_networking`

**Called from:** `network_management.yml` (action=deploy)

Two responsibilities:

**Part 1 — Proxmox SDN:** Templates `/etc/network/interfaces` on each Proxmox node to
create OVS bridges, CDX-I patch ports, and VLAN assignments defined in `network_topology`
(from `vms.yaml`). Reloads networking via `ifreload -a` on nodes where the file changed.
All node tasks are delegated from `localhost` via SSH.

**Part 2 — VyOS router configuration:** Stages per-router VyOS CLI config files
(`EXERCISES/<name>/VyOS/<vm-name>.conf`) to `/tmp/` on each router and applies them via:
```
vbash -c "source /opt/vyatta/etc/functions/script-template && source /tmp/vyos-<name>.conf"
```
Routers with no config file emit a warning and are skipped (not a failure; manual config is valid).

**When invoked with `networking_scope=bridges`** (Phase 2.5 in `site.yml`): Only Part 1
runs. Part 2 is skipped because VyOS routers are not yet powered on.

**Expects:**
- Proxmox nodes in `inventory/hosts.yml` → `proxmox_cluster` group
- VyOS hosts in `inventory/exercise_hosts.yml` with `ansible_host` populated

---

### `revert_networking`

**Called from:** `network_management.yml` (action=destroy)

Restores the base-only `/etc/network/interfaces` on each Proxmox node, removing all
exercise-specific OVS bridges and CDX-I patch ports. Reloads networking where the file changed.

VyOS routers are **not** modified — they persist across exercises and must be reconfigured
or reset manually if needed.

Uses the same `interfaces.j2` template as `configure_networking` but renders only the
base network stanza (no exercise bridges).

---

## Active Directory

### `configure_active_directory`

**Called from:** `domain_management.yml` (Phase 4)

Targets: `domain_controllers` group. Runs with `serial: 1` from the calling playbook.

Performs the full Active Directory deployment lifecycle:

**Section 1 — Preflight assertions:** Validates `scenario.domain.*` facts are defined.

**Section 2 — DC status check:** Queries `Win32_ComputerSystem.DomainRole`; sets
`_is_dc` fact. Already-promoted DCs skip Sections 3–5.

**Section 3 — Domain existence check:** Tests LDAP port 389 on the domain FQDN;
sets `_domain_exists` fact. Used to select forest-creation vs. replica-DC path.

**Section 4a — Forest creation (first DC):** `win_domain` installs a new AD forest using
`scenario.domain.*` parameters. Reboots automatically.

**Section 4b — Replica DC promotion:** `win_domain_controller` promotes additional DCs
into the existing domain. Reboots automatically. Assigns DC to its AD site if `ad_site`
is set in `host_vars`.

**Section 5 — Wait for AD readiness:** Polls `Import-Module ActiveDirectory; Get-ADDomain`
until successful.

**Section 5.5 — NLA restart:** Restarts the Network Location Awareness service
(`NlaSvc`) with `force_dependent_services: true` so the network adapter is reclassified
as `DomainAuthenticated` (not `Public`). Without this, Windows Firewall blocks WinRM
on the domain-joined DC. Runs only on freshly promoted DCs (`when: not _is_dc`).

**Section 5.6 — Enable built-in Administrator:** The built-in Administrator is the only
guaranteed Enterprise Admin in a fresh forest. `cdxadmin` is Domain Admin but not Enterprise
Admin and cannot manage the Configuration partition (Sites & Services, GPO linking).
This section enables the Administrator account and sets its password via `net user` while
still connected as `cdxadmin`. Runs only on the forest-creating DC.

**Section 5.7 — W32TM NTP configuration:** Configures the PDC emulator to sync from
`scenario.ntp_server` (default: CDX-I NTP container at `46.244.164.88`). Runs as
`Administrator`. Runs only on the forest-creating DC. W32TM hierarchy propagates NTP
settings to member machines automatically.

**Sections 6 — Stage JSON files:** Copies `exercise_template.json` and `users.json` to
a temp directory on DC-01 for PowerShell consumption.

**Sections 7–11 — AD configuration (block, runs as Administrator):** All tasks in this
block use `vars: ansible_user: Administrator`. Only runs when `not _domain_exists` (i.e.,
the forest-creating DC only). `run_once: true` is avoided because with `serial: 1` it
would fire once per batch — `when: not _domain_exists` achieves the same single-execution
semantics safely.

- **Section 7:** Create/rename AD sites, subnets, and site links from `exercise_template.json`
- **Section 7.5:** Create DNS reverse lookup zones; trigger DDNS re-registration for PTR records
- **Section 8:** Create OU hierarchy (root OU → site key OUs → department OUs → sub-OUs)
- **Section 9:** Create AD security groups from `users.json`
- **Section 10:** Create user accounts and assign group memberships from `users.json`
- **Section 11:** Remove staging directory from DC

All PowerShell AD filter comparisons use string-based `-Filter "Name -eq '$var'"` syntax to
avoid PowerShell scope resolution issues with `-Filter { scriptblock }` syntax.

**Key input variables (from `scenario.yml`):**

| Variable | Description |
|---|---|
| `scenario.domain.name` | Domain FQDN (e.g., `example.cdx.lab`) |
| `scenario.domain.netbios` | NetBIOS name |
| `scenario.domain.functional_level` | Forest/domain functional level |
| `scenario.domain.admin_password` | Domain admin password (vault reference) |
| `scenario.ntp_server` | NTP server for PDC emulator (default: `46.244.164.88`) |

---

### `deploy_group_policy_objects`

**Called from:** `domain_management.yml` (Phase 4, after `configure_active_directory`)

Creates GPOs, applies registry-based settings, links GPOs to OUs, applies security
filtering, and stages branding images to `NETLOGON`.

Supports two `gpo.json` schema versions:
- **v1.0** — links embedded in each GPO object as a plain OU-path array
- **v2.0** — top-level `links` array with `enforced`/`enabled`/`linkOrder` metadata;
  optional `securityGroups` and `imageFiles` sections

Registry value placement is automatic from the key hive:
- `HKLM\*` → Computer Configuration policy
- `HKCU\*` → User Configuration policy

`__DOMAIN__` placeholder in any setting value is replaced at runtime with the domain FQDN.

All tasks use `run_once: true` — with `serial: 1` in the calling playbook, only DC-01
executes them; AD replication propagates the result to other DCs.

---

### `join_domain`

**Called from:** `server_configuration.yml` (post_tasks), `workstation_configuration.yml`
(post_tasks) — via `include_role`

Joins a Windows VM to the exercise Active Directory domain. Called from `post_tasks` in
both configuration playbooks so it always runs after `configure_vm` (which sets the
hostname and reboots if needed). Setting the hostname while still in workgroup avoids
the Access Denied error that occurs when renaming an already domain-joined computer.

**Idempotent:** checks `Win32_ComputerSystem.PartOfDomain` via WMI before attempting
the join. If the machine is already a member of the correct domain, the role exits cleanly
without making any changes.

**Gate variable:** `domain_join` (default: `true`) — set `false` in `vms.yaml` per-VM
for standalone systems that should not join the domain (external DNS resolvers, DMZ hosts,
intentionally isolated endpoints).

**Sections:**
1. Gate: skips non-Windows hosts (`ansible_os_type != 'windows'`), hosts with `domain_join: false`,
   and hosts where `scenario.domain` is not defined
2. Idempotency check: WMI query for current domain membership
3. Domain join: `ansible.windows.win_domain_membership`; uses `Administrator@<domain>` as
   the joining account (guaranteed Domain Admin)
4. Reboot if required
5. Summary

**Key variables:**

| Variable | Default | Description |
|---|---|---|
| `domain_join` | `true` | Set `false` in `vms.yaml` to skip join for standalone VMs |
| `scenario.domain.name` | — | Domain FQDN; sourced from `read_exercise_config` |
| `scenario.domain.admin_password` | — | Domain Administrator password (vault reference) |

---

## Domain Services

### `deploy_dhcp`

**Called from:** `domain_services.yml`, `dhcp_management.yml` (Phase 4.7 / Phase 7)

Configures Windows DHCP Server on domain-joined Windows hosts. All DHCP Server operations
run as domain `Administrator` via a block-level `vars: ansible_user: Administrator` override.
`cdxadmin` is used only for local OS tasks (not in this role).

**Sections:**
1. Phase gate + preflight (asserts `scenario.phases.services.dhcp` and scopes are defined)
2. Ensures `DHCPServer` service is started and set to automatic
3. **DHCP post-install AD initialization:** Runs `Add-DhcpServerSecurityGroup` if the
   `DHCP Administrators` AD group does not exist. This creates the DHCP AD security groups
   and initializes the DHCP Server module's AD connectivity — equivalent to the Server Manager
   "Complete DHCP configuration" banner. Idempotent (guarded by group existence check).
   The DHCPServer service is restarted unconditionally after initialization and polled until
   the scope database is ready.
4. Authorizes the DHCP server in Active Directory (uses `cloud_init_ip` — the exercise-network
   IP — to avoid management NIC ambiguity on dual-NIC hosts)
5. Detects existing scopes by subnet address
6. Creates missing scopes (idempotent — existing scopes are skipped)
7. Applies scope options 3 (router), 6 (DNS), 15 (domain name) with `-Force`
8. Ensures all configured scopes are in `Active` state

DHCP scopes come from `scenario.services.dhcp.scopes` in `scenario.yml`.

**Key variable:** `cloud_init_ip` — set per-host by `inventory_refresh`; the exercise-network
IP used for DHCP server AD authorization (not the management NIC IP).

---

### `deploy_sql_server`

**Called from:** `domain_services.yml`, `sql_management.yml` (Phase 6)

Unattended installation of Microsoft SQL Server. Validates SQL setup media is present on
the target host, runs the installer silently, configures the Windows firewall, and waits
for the `localhost` SQL instance to accept connections.

**Prerequisites:** SQL Server setup media pre-staged at `sql_setup_path` on the target host.

---

### `deploy_microsoft_exchange`

**Called from:** `domain_services.yml`, `exchange_management.yml` (Phase 6)

Unattended installation of Microsoft Exchange Server (2010, 2013, 2016).

Runs AD preparation steps (`PrepareSchema` → `PrepareAD` → `PrepareAllDomains`) automatically
on the first Exchange host. Configures virtual directories (OWA, ECP, EWS, OAB, ActiveSync)
using the `exchange_external_fqdn` FQDN — no NIC auto-discovery.

**Prerequisites:**
- AD deployed (`domain_management.yml` complete)
- Exchange setup media pre-staged at `exchange_setup_path`
- Ansible user is a member of Schema Admins and Enterprise Admins

---

### `deploy_configuration_manager`

**Called from:** `domain_services.yml`, `sccm_management.yml` (Phase 6)

Unattended installation of Microsoft System Center Configuration Manager (SCCM/MECM).

Installs Windows ADK, prepares AD schema for SCCM, and runs the SCCM unattended installer.
All service endpoints (SDKServer, ManagementPoint, DistributionPoint) are configured using
FQDNs (`inventory_hostname.scenario.domain.name`) — no NIC auto-discovery.

**Prerequisites:**
- AD deployed and SQL Server deployed
- SCCM setup media, prerequisites, and ADK pre-staged on the target host

---

## Team Configuration

### `configure_red_team`

**Called from:** `red_team_deployment.yml` (Play 2, after power-on)

Configures Red Team adversary infrastructure on deployed VMs. Reads `apt_config` (loaded
by `read_apt_config`) to determine which C2 platforms and operator tools to configure on
which VMs.

> **Current status:** Core scaffolding with preflight assertions in place; specific C2
> platform configuration tasks (Cobalt Strike, Sliver, Adaptix) are implemented per
> `apt.yml` `c2_platforms` entries.

---

### `configure_blue_team`

**Called from:** `blue_team_deployment.yml` (Play 2, after power-on)

Configures Blue Team SOC infrastructure on deployed VMs. Reads `soc_layout` (loaded
by `read_soc_layout`) to determine which SOC components (Malcolm, Hedgehog sensor,
OPNsense, analyst workstations) to configure on which VMs.

> **Current status:** Core scaffolding with preflight assertions in place; component-specific
> configuration tasks are implemented per `layout.yml` entries.

---

## Operational

### `configure_proxmox_nodes`

**Called from:** `cluster_setup.yml` (one-time bootstrap, not in pipeline)

Bootstraps all Proxmox cluster nodes for CDX-E use. Exercise-agnostic — does not require
`read_exercise_config`.

**Steps:**
1. Preflight assertions (validates `host_vars` and `base_network` completeness per node)
2. Displays bootstrap plan
3. Installs `openvswitch-switch` and `ifupdown2` via `apt`
4. Deploys base `/etc/network/interfaces` (no exercise bridges, only management and CDX-I)
5. Pre-creates CDX-I OVS bridge (`vmbr303`) and SOC trunk port
6. Reloads networking on nodes where the interfaces file changed
7. Verifies Proxmox API is reachable post-reload

All operations are delegated from `localhost` via SSH to each Proxmox node.

---

### `deploy_endpoint_agents`

**Called from:** `endpoint_agent_deployment.yml`

Deploys SIEM endpoint agents to all VMs with `monitor: true` in `vms.yaml`. Hosts without
`monitor: true` are skipped. White Cell controls the monitoring scope via this flag.

**Supported platforms:**

| Platform | Variable value | Notes |
|---|---|---|
| Wazuh | `wazuh` (default) | Works on Windows and Linux |
| Elastic | `elastic` | Requires Fleet server pre-configured |
| Splunk UF | `splunk_uf` | Splunk Universal Forwarder |

Set platform via `endpoint_agent_platform` variable.

---

## Stub / Placeholder

These roles exist in the directory structure but contain only placeholder tasks.
They are not yet implemented.

| Role | Intended Purpose |
|---|---|
| `check_network_paths` | Pre-exercise network connectivity validation (called by `environment_check.yml`) |
| `deploy_vulnerability` | Intentional vulnerable configuration deployment (called by `vulnerability_deployment.yml`) |
| `deploy_mpnet_vms` | MPNET VM provisioning (future multi-provider network support) |
| `deploy_mpnet_networking` | MPNET network configuration |
| `destroy_mpnet_vms` | MPNET VM teardown |
| `destroy_mpnet_networking` | MPNET network revert |

---

## Legacy

### `cdx_e`

**Status:** Legacy monolithic role — retained for reference only. Not called by any current playbook.

Original entry point for the CDX-E framework before the modular playbook architecture was
implemented. Loads exercise spec and dispatches to action-specific task files via
`include_tasks`. Superseded by the current `read_exercise_config` + individual role pattern.

---

## Facts Reference

The following facts are set by the loader roles and consumed by all downstream roles.
All are `cacheable: true` and available across plays within the same pipeline run.

| Fact | Set By | Description |
|---|---|---|
| `exercise_dir` | `read_exercise_config` | Path to `EXERCISES/<name>/` |
| `scenario` | `read_exercise_config` | Parsed `scenario.yml` |
| `virtual_machines` | `read_exercise_config` | Scenario VM list from `vms.yaml` |
| `network_topology` | `read_exercise_config` | Network topology block from `vms.yaml` |
| `apt_name` | `read_apt_config` | Active APT profile name |
| `apt_config` | `read_apt_config` | Parsed APT `apt.yml` |
| `apt_vms` | `read_apt_config` | Red Team VM list |
| `soc_layout_name` | `read_soc_layout` | Active SOC layout name |
| `soc_layout` | `read_soc_layout` | Parsed `layout.yml` |
| `soc_vms` | `read_soc_layout` | Blue Team VM list |
| `cloud_init_ip` | `inventory_refresh` | Per-host exercise-network IP (from `vms.yaml`) |
| `ansible_host` | `vm_power_management` | Per-host management IP written to `host_vars/` |

### Per-host role facts (set during task execution, not cacheable)

| Fact | Set By | Description |
|---|---|---|
| `_is_dc` | `configure_active_directory` | `true` if host's DomainRole >= 4 |
| `_domain_exists` | `configure_active_directory` | `true` if LDAP port 389 responds on domain FQDN |
| `_already_joined` | `join_domain` | `true` if host is already a member of the exercise domain |
| `_vm_dhcp_ips` | `vm_power_management` | Dict of VM name → Layer0 DHCP IP (used for workstations) |
| `_vms_static_configured` | `vm_power_management` | List of VMs whose exercise IPs were verified by QGA |

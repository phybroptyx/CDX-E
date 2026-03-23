# CHILLED_ROCKET — Stark Industries Exercise

Multi-site enterprise exercise. Domain: `stark-industries.midgard.mrvl`. 5 global sites,
331 VMs, 12 VyOS routers, 41 OVS bridges (stk100–stk140).

---

## Configuration Files

| File | Purpose |
|------|---------|
| `scenario.yml` | Pipeline phase gates, domain, Proxmox defaults |
| `vms.yaml` | VM inventory + network topology |
| `exercise_template.json` | AD structure: sites, site links, OUs |
| `users.json` | AD user accounts and security groups |
| `gpo.json` | Group Policy Objects |
| `services.json` | DNS zones and service configuration |
| `VyOS/` | Per-router VyOS CLI config files (12 routers) |

---

---

## Configuration Summary

### Total Infrastructure
```
Total VMs:        331
Network Bridges:  41 (stk100-stk140)
VyOS Routers:     12
VIP Systems:      3
```

### VM ID Allocation
```
Proxmox Resource Grouping:
├── 1-999      : CDX Management
├── 1000-1999  : Blue Team (SOC)
├── 2000-2999  : Templates (Packer-built)
├── 3000-3999  : APT / Red Team resources
├── 4000-4999  : CDX Internet (grey space)
└── 5000-6999  : Defended/Target ← CHILLED_ROCKET HERE
    ├── 5000-5999 : Servers
    └── 6000-6999 : Workstations
```

### Network Segmentation
```
Site            Bridges      Systems
──────────────────────────────────────
HQ              stk100-110   104
Malibu          stk111-115   30
Dallas          stk116-124   62
Nagasaki        stk125-132   76
Amsterdam       stk133-140   71
```

### Operating Systems
```
Servers:
├── Windows Server 2025:  5 systems (10.4%)
├── Windows Server 2022: 15 systems (31.3%)
└── Windows Server 2019: 28 systems (58.3%)

Workstations:
├── Windows 11 Pro:       97 systems (32.9%)
├── Windows 10 Ent:      169 systems (57.3%)
├── Windows 8.1 Ent:      16 systems (5.4%)
└── Windows 7 Ent:        13 systems (4.4%)
```

---

## Quick Start Deployment

Network bridges (stk100–stk140) are created automatically by the Ansible pipeline
(`network_management.yml`). VM cloning is handled by Terraform via the `deploy_scenario`
role. Do not create bridges or clone VMs manually.

```bash
# Full pipeline deployment
ansible-playbook site.yml \
  -e "exercise=CHILLED_ROCKET" \
  -e "@secrets/credentials.yml" --ask-vault-pass
```

For staged rollout, run individual phase playbooks — see `playbooks/README.md`.

> **Note:** CHILLED_ROCKET is a large exercise (331 VMs, 5 sites). Pilot the HQ site
> only (`EXERCISES/10. CHILLED_ROCKET/vms.yaml` — filter to HQ VMs) before scaling
> to all 5 sites.

---

## VIP Systems

Three critical executive workstations are marked in the configuration:

| User | VM ID | Hostname | Network | MAC |
|------|-------|----------|---------|-----|
| **Tony Stark** (CEO) | 6200 | ML-DEV-W32805N | stk115 (Malibu Dev) | D4:AE:52:C4:2D:34 |
| **Pepper Potts** (COO) | 6001 | HQ-OPS-XAJI0Y6DPB | stk106 (HQ Ops) | 00:1F:29:65:D6:70 |
| **Happy Hogan** (COS) | 6022 | HQ-SUP-J2D54I3QK2 | stk103 (HQ Support) | 00:21:5A:CC:A8:8E |

---

## Site Distribution

### HQ (New York) - 104 systems
- **Network:** 66.218.180.0/22
- **Bridges:** stk100-stk110 (11 networks)
- **Servers:** 12 (DCs, file, DB, web, app)
- **Departments:** 10 (Operations, IT, HR, Legal, Engineering, QA, CAD)

### Malibu (California) - 30 systems
- **Network:** 4.150.216.0/22
- **Bridges:** stk111-stk115 (5 networks)
- **Servers:** 9 (including Server 2025 dev infrastructure)
- **Focus:** Tony Stark's development operations

### Dallas (Texas) - 62 systems
- **Network:** 50.222.72.0/22
- **Bridges:** stk116-stk124 (9 networks)
- **Servers:** 7 (DC, file, DB, NMS)
- **Departments:** 7 (Operations, Engineering, QA, CAD)

### Nagasaki (Japan) - 76 systems
- **Network:** 14.206.0.0/22
- **Bridges:** stk125-stk132 (8 networks)
- **Servers:** 8 (DC, file, DB, NMS, WSUS-APAC)
- **Departments:** 6 (Operations, Engineering, QA)

### Amsterdam (Netherlands) - 71 systems
- **Network:** 37.74.124.0/22
- **Bridges:** stk133-stk140 (8 networks)
- **Servers:** 12 (DC, file, DB, web, app, WSUS-EU)
- **Departments:** 6 (Operations, Engineering, QA)

---

## Template Mapping

Packer-built templates used by this exercise (QNAP master VMIDs):

| VMID | Template Key | Operating System | Usage |
|------|-------------|-----------------|-------|
| 2037 | `server_2025` | Windows Server 2025 | Malibu advanced servers |
| 2033 | `server_2022` | Windows Server 2022 | NMS, WSUS, web, app servers |
| 2031 | `server_2019` | Windows Server 2019 | DCs, file servers, DB servers |
| 2036 | `windows_11` | Windows 11 | Workstations |
| 2035 | `windows_10` | Windows 10 | Workstations |
| 2028 | `windows_8.1` | Windows 8.1 | Legacy workstations |
| 2025 | `windows_7` | Windows 7 | Legacy workstations |

---

## Security Architecture

### Network Segmentation
- Separate OVS bridges for core servers, DMZ, and departments
- Site-level network isolation via CDX-I uplinks
- Department-level traffic segmentation

### Zone Design
```
CDX-I Internet → SDP Router → Boundary/DMZ → Core Servers → Departments
```

### Monitoring
- VMs tagged `monitor: true` in `vms.yaml` receive SIEM endpoint agents (Phase 11)
- VIP systems (Tony Stark, Pepper Potts, Happy Hogan) marked for enhanced monitoring

---

## CDX-E Integration

Deployed via the Ansible pipeline defined in `site.yml`. Configuration files consumed by:

| File | Consumed by |
|------|-------------|
| `scenario.yml` | `read_exercise_config` role |
| `vms.yaml` | `read_exercise_config` role |
| `exercise_template.json` | `configure_active_directory` role (AD sites, OUs) |
| `users.json` | `configure_active_directory` role (users, groups) |
| `gpo.json` | `deploy_group_policy_objects` role |
| `VyOS/*.conf` | `configure_networking` role (pushed via SSH) |

---

## Configuration Version History

| Version | Date | Changes |
|---------|------|---------|
| **2.2** | 2025-11-24 | Added network bridge configuration (41 bridges) |
| **2.1** | 2025-11-24 | Changed Windows 11 to Professional edition |
| **2.0** | 2025-11-24 | Initial release with VM IDs and templates |

---

## Pre-Deployment Checklist

- [ ] All required Packer templates built (run `template_deployment.yml`)
- [ ] `scenario.yml` created from `EXERCISES/TEMPLATE/scenario.yml` scaffold
- [ ] `vms.yaml` populated (331 VMs — pilot HQ-only first before full 5-site deployment)
- [ ] VyOS config files present in `VyOS/` for all 12 routers
- [ ] Sufficient Proxmox storage for 331 linked-clone VMs
- [ ] DHCP scopes defined in `scenario.yml → scenario.services.dhcp.scopes`
- [ ] CDX-RELAY provisioned (`provision_relay.yml` run once)

---

## Resources

- **Exercise:** CHILLED_ROCKET (Stark Industries)
- **Domain:** stark-industries.midgard.mrvl
- **Total VMs:** 331 systems across 5 global sites
- **Pipeline docs:** `playbooks/README.md`, `roles/README.md`


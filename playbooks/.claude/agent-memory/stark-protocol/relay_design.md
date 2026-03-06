# SSH Configuration Relay — Design Queue Entry

**Status:** Design complete. Not yet implemented.
**Introduced:** Session 13 (2026-03-04)

---

## Purpose

A persistent relay VM that serves as the sole Ansible management path to exercise VMs that have no Layer0 management NIC. This is the enabling component for the target architecture where all exercise VMs are isolated from the management plane and reachable only through the CDX-I network.

---

## Architecture

### NIC Layout

| Interface | Bridge | Network | Purpose |
|-----------|--------|---------|---------|
| eth0 | Layer0 | Management VLAN | ACN → relay SSH ingress |
| eth1 | CDX-I (EQIX4) | 10.1.1.2/30 | Default route; reaches all CDX-I-routable exercise systems |
| eth2 | Dynamic | Varies per exercise | Proxmox API bridge swap; reaches NAT/firewall-isolated segments |

### Routing

- Default route via eth1 (CDX-I) — relay can reach all CDX-I-routable exercise VMs without eth2
- eth2 used for segments not routable via CDX-I (e.g., NAT-isolated Blue Team segments)

### Traffic Pattern

```
ACN → SSH → relay:eth0 (Layer0) → relay → SSH → target VM
                                         ↑
                               via eth1 (CDX-I) OR eth2 (isolated bridge)
```

### Windows VMs

WinRM-over-SSH is acceptable. WinRM traffic tunnels through the SSH ProxyJump chain — no separate WinRM network path required.

---

## Decisions Finalized

| Decision | Outcome |
|----------|---------|
| Form factor | Full VM (not LXC container) |
| Persistence | Persistent (always-on) |
| NIC count | 3 (eth0, eth1, eth2) |
| eth2 assignment | Dynamic via Proxmox API bridge swap |
| SSH key | Either dedicated or shared ACN keypair (deferred to implementation) |
| Windows protocol | WinRM-over-SSH |
| Long-term NIC strategy | All exercise VMs → NO Layer0 NIC; relay is sole path |

---

## Implementation Prerequisites

- Proxmox API bridge-swap automation (Ansible task or standalone script)
- SSH ProxyJump configuration in Ansible inventory or ansible.cfg
- WinRM-over-SSH configured on Windows exercise templates
- Relay VM built and registered in Proxmox (VMID TBD)

---

## Notes

- The relay is required BEFORE the Layer0 NIC migration can begin on exercise VMs
- EQIX4 is the CDX-I attachment point at 10.1.1.2/30
- The relay is NOT part of any exercise Terraform state — it is infrastructure, not exercise VMs

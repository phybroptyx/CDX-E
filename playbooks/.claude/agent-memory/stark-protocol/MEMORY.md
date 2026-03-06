# STARK Protocol — Agent Memory

## Session Continuity
- Last session: **Session 13** (2026-03-04)
- Next session number: **14**
- Branch: `ansible-optimized-v1.0`
- Last known commit tip: `12326eb` (unchanged through Session 13 — no commits made)

## Co-Author Tag
Always use: `Co-Authored-By: J.A.R.V.I.S. <jarvis@cdx.lab>`
Never use "Claude Sonnet 4.6" as co-author.

## CDX-E Architecture State (as of Session 13)
- Exercise: DC_303 (`dc303.cdx.lab`, Win2016, pool CDX_DEMO_DC303)
- Three Terraform states: `terraform/`, `terraform_red_team/`, `terraform_blue_team/`
- Secrets path: `../secrets/credentials.yml` (relative from playbooks/ — never use `{{ playbook_dir }}/`)
- Red team VMs: `APTs/<apt>/vms.yaml` | Blue team VMs: `SOC_LAYOUTS/<layout>/vms.yaml`
- VyOS mgmt IP: discovered at runtime via Proxmox guest agent API
- VyOS config: `EXERCISES/<name>/VyOS/<vm-name>.conf` pushed via `vbash -l -s`

## SSH Configuration Relay (Design Queue — NOT IMPLEMENTED)
- 3-NIC persistent VM: eth0=Layer0, eth1=CDX-I/EQIX4 (10.1.1.2/30), eth2=dynamic
- Pattern: ACN → SSH → relay (eth0) → SSH → target (eth1 CDX-I or eth2 bridge)
- eth2 bridge changes via Proxmox API
- WinRM-over-SSH acceptable for Windows targets
- Target arch: ALL exercise VMs will have NO Layer0 NIC; relay is sole Ansible path
- See: `stark-protocol/relay_design.md` for full spec

## Documentation Created (Session 13, uncommitted)
- `playbooks/README.md` — 22 playbooks, phase flags, standalone use, variables
- `roles/README.md` — 34 roles in 10 functional categories
- `CDX-E-Workflow.md` — 3 Mermaid diagrams (full pipeline, phase gates, deploy/destroy)

## Open Backlog (carry forward)
- OI-01: Task #27 — commit Packer build configs for commando_vm (2039), flare_vm (2049)
- OI-02: Sync Development/Projects/CDX-E → docker.cdx.lab/CDX-E; commit Sessions 12-13 changes
- OI-03: git pull on Ansible controller (/home/ansible/Ansible/test/cdx-e/)
- OI-04: DC_303 first live pipeline run (full validation)
- OI-05: SSH Configuration Relay VM — build per design queue spec
- OI-06: pool_id bug in main.tf.j2 (CDX_DEMO_DC303 pool ignored, deferred)
- OI-07/08/09: Stub roles not implemented (deploy_vulnerability, check_network_paths, MPNET)

## Packer / Template VMIDs
- commando_vm: VMID 2039 (built)
- flare_vm: VMID 2049 (built)
- threat_pursuit_vm: REMOVED (incomplete upstream)
- VMID 2050: unallocated
- VyOS template: VMID 2017

## Key Paths
- Working tree: `E:/Git/Development/Projects/CDX-E/`
- Commit target: `E:/Git/docker.cdx.lab/CDX-E/`
- STARK artifacts: `E:/Documents/`
- Ansible controller: `/home/ansible/Ansible/test/cdx-e/`

## Detailed Notes
- See `relay_design.md` for SSH Configuration Relay full design queue entry

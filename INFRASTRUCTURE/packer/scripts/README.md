# Packer Scripts

Helper scripts used by Packer provisioners during template builds.

## Directory Layout

```
scripts/
├── common/          # Shared scripts (run on build host via shell-local)
│   └── strip-nics.sh
├── linux/           # Linux in-VM provisioners
│   ├── install-qemu-guest-agent.sh
│   └── cleanup.sh
└── windows/         # Windows in-VM provisioners
    ├── configure-base.ps1
    └── sysprep.ps1
```

---

## `common/strip-nics.sh`

**Purpose:** Remove all `net*` network interfaces from a Proxmox build VM
via the Proxmox API before Packer converts the VM to a template.

**Why this exists:** Every Packer build attaches the VM to `Layer0` (the
management bridge) so the installer can reach the preseed server and the
internet during setup. That management NIC must not exist in the finished
template — Terraform owns the full NIC configuration when it clones exercise
VMs. Without this step, every cloned VM would inherit a stale `net0` pointing
at `Layer0`, which exercise VMs must never have.

**When it runs:** As a `shell-local` provisioner (executes on the Packer
build host, not inside the VM), after all in-VM provisioners complete and
immediately before Packer shuts the VM down and converts it to a template.

**Interface — environment variables (injected by Packer):**

| Variable | Description |
|---|---|
| `PROXMOX_API_URL` | Full API base URL, e.g. `https://cdx-pve-01:8006/api2/json` |
| `PROXMOX_API_TOKEN_ID` | Token ID, e.g. `ansible@pam!ansible` |
| `PROXMOX_API_TOKEN_SECRET` | Token secret (UUID) |
| `PROXMOX_NODE` | Proxmox node name, e.g. `cdx-pve-01` |
| `TEMPLATE_VMID` | Numeric VMID of the build VM |

All variables are already present in `common.pkrvars.hcl` and every
`*.pkr.hcl` template — no additional configuration is required.

**Exit codes:**

| Code | Meaning |
|---|---|
| `0` | Success — NICs removed, or no NICs found (idempotent) |
| `1` | API query or delete failed — Packer build will fail with a visible error |

**Dependencies:** `curl`, `jq` — both available on the ACN Ansible controller
(Debian 13 base) used as the Packer build host.

**Proxmox-clone templates** (`commando-vm.pkr.hcl`, `flare-vm.pkr.hcl`) use
`var.vm_id` instead of `var.template_vm_id` — the `TEMPLATE_VMID` env var in
those templates is set accordingly.

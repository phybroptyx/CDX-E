# CDX-E Secrets

This directory is a **template**. It shows the required structure for sensitive configuration data.

## Setup

```bash
cp -r secrets.example/ secrets/
```

Edit `secrets/credentials.yml` with real values. The `secrets/` directory is gitignored.

## What goes in `secrets/`

| File / Directory | Purpose |
|------------------|---------|
| `credentials.yml` | API tokens, passwords for Proxmox, AD deployment, and VM initial credentials |
| `ssh_keys/` | Controller SSH keypairs, auto-generated per exercise deployment |

## SSH Key Lifecycle

Each `action=deploy` run generates a fresh Ed25519 keypair unique to that exercise:

```
secrets/ssh_keys/
├── id_cdx_obsidian_dagger       # private key
└── id_cdx_obsidian_dagger.pub   # public key
```

**Deploy flow:**
1. Generate keypair → `secrets/ssh_keys/id_cdx_<exercise_name>`
2. Clone and boot VMs
3. Discover management IPs via QEMU guest agent
4. Bootstrap: SSH/WinRM into VMs using initial password credentials, distribute public key
5. Configure: all subsequent operations use key-based authentication

**Configure flow (standalone):**
- Reuses the existing keypair from the last deploy — no regeneration

This ensures each exercise deployment has a unique trust chain between the controller and its VMs.

## Usage

### Ansible

Pass the secrets file as extra-vars:

```bash
ansible-playbook site.yml \
  -e "@secrets/credentials.yml" \
  -e "action=deploy exercise_yaml=../obsidian_dagger_vms.yaml"
```

Or encrypt with Ansible Vault for an additional layer:

```bash
ansible-vault encrypt secrets/credentials.yml
ansible-playbook site.yml \
  -e "@secrets/credentials.yml" --ask-vault-pass \
  -e "action=deploy exercise_yaml=../obsidian_dagger_vms.yaml"
```

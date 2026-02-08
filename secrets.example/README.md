# CDX-E Secrets

This directory is a **template**. It shows the required structure for sensitive configuration data.

## Setup

```bash
cp -r secrets.example/ secrets/
```

Edit `secrets/credentials.yml` with real values. The `secrets/` directory is gitignored.

## What goes in `secrets/`

| File | Purpose |
|------|---------|
| `credentials.yml` | API tokens, passwords for Proxmox and AD deployment |
| `ssh_keys/` | Private SSH keys for Proxmox node access (optional — use if not in `~/.ssh`) |

## Usage

### Ansible

Pass the secrets file as extra-vars:

```bash
ansible-playbook site.yml \
  -e "@secrets/credentials.yml" \
  -e "action=deploy exercise_yaml=../desert_citadel_vms.yaml"
```

Or encrypt with Ansible Vault for an additional layer:

```bash
ansible-vault encrypt secrets/credentials.yml
ansible-playbook site.yml \
  -e "@secrets/credentials.yml" --ask-vault-pass \
  -e "action=deploy exercise_yaml=../desert_citadel_vms.yaml"
```

### PowerShell

The PowerShell scripts (`deploy.ps1`, `ad_deploy.ps1`) collect credentials interactively at runtime via `Read-Host -AsSecureString`. Reference `secrets/credentials.yml` for the values to enter when prompted.

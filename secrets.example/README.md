# CDX-E Secrets Template

This directory is a **committed template** showing the required structure for sensitive
configuration data. Copy it to `secrets/` and populate with real values.

## Setup

```bash
cp -r secrets.example/ secrets/
```

Edit `secrets/credentials.yml` with real values. The `secrets/` directory is gitignored.

## What goes in `secrets/`

| File | Purpose |
|------|---------|
| `credentials.yml` | API tokens, passwords for Proxmox, AD deployment, and VM initial credentials |

## Usage

### Ansible

Pass the secrets file as extra-vars:

```bash
ansible-playbook site.yml \
  -e "exercise=MY_EXERCISE" \
  -e "@secrets/credentials.yml" --ask-vault-pass
```

Or for individual phase playbooks:

```bash
ansible-playbook playbooks/domain_management.yml \
  -e "exercise=MY_EXERCISE" \
  -e "@secrets/credentials.yml" --ask-vault-pass
```

Encrypt with Ansible Vault for an additional layer of protection:

```bash
ansible-vault encrypt secrets/credentials.yml
ansible-playbook site.yml \
  -e "exercise=MY_EXERCISE" \
  -e "@secrets/credentials.yml" --ask-vault-pass
```

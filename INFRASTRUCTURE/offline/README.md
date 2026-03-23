# Offline Staging

This directory documents and tracks all external dependencies required for air-gapped CDX deployments.

## Quick Start

1. On an Internet-connected machine, review `manifest.yml` for the complete dependency list
2. Download all binaries, providers, plugins, and ISOs
3. Transfer to the ACN and Proxmox storage
4. Configure Terraform's filesystem mirror (see `manifest.yml` for `terraformrc` config)
5. Place Packer plugins in the configured `PACKER_PLUGIN_PATH`
6. Verify ISOs are uploaded to Proxmox storage

## Verification

After staging, validate that required templates exist on Proxmox and that Packer plugins
and Terraform providers are available at their configured paths. The `environment_check.yml`
playbook (stub — not yet fully implemented) is intended for this purpose:

```bash
ansible-playbook playbooks/environment_check.yml \
  -e "exercise=MY_EXERCISE" -e "@secrets/credentials.yml"
```

Until `environment_check.yml` is implemented, verify manually:
- Confirm Packer plugins exist at `PACKER_PLUGIN_PATH`
- Confirm Terraform providers are present in the filesystem mirror (`.terraform.d/`)
- Confirm ISOs are uploaded to Proxmox storage (`pvesm list <storage>`)
- Run `playbooks/template_deployment.yml` with `--check` to validate template detection

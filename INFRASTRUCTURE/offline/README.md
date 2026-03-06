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

After staging, run the readiness check:
```bash
ansible-playbook playbooks/verify_offline_readiness.yml
```

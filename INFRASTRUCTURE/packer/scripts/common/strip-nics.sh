#!/usr/bin/env bash
# =============================================================================
# strip-nics.sh — Remove all network interfaces from a Proxmox build VM
# =============================================================================
# Called as a Packer shell-local provisioner (runs on the Packer build host)
# immediately before template conversion. Deletes every net* config key from
# the build VM via the Proxmox API so the resulting template has a clean NIC
# slate — Terraform populates all NICs when it clones exercise VMs.
#
# Required environment variables (injected by Packer shell-local env block):
#   PROXMOX_API_URL           https://cdx-pve-01:8006/api2/json
#   PROXMOX_API_TOKEN_ID      e.g. ansible@pam!ansible
#   PROXMOX_API_TOKEN_SECRET  token UUID
#   PROXMOX_NODE              e.g. cdx-pve-01
#   TEMPLATE_VMID             numeric VMID of the build VM
#
# Exit codes:
#   0  — success (NICs removed, or no NICs found)
#   1  — API error or missing required variable
# =============================================================================

set -euo pipefail

# ── Validate required environment variables ───────────────────────────────────
: "${PROXMOX_API_URL:?PROXMOX_API_URL is required}"
: "${PROXMOX_API_TOKEN_ID:?PROXMOX_API_TOKEN_ID is required}"
: "${PROXMOX_API_TOKEN_SECRET:?PROXMOX_API_TOKEN_SECRET is required}"
: "${PROXMOX_NODE:?PROXMOX_NODE is required}"
: "${TEMPLATE_VMID:?TEMPLATE_VMID is required}"

AUTH_HEADER="PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}"
CONFIG_URL="${PROXMOX_API_URL}/nodes/${PROXMOX_NODE}/qemu/${TEMPLATE_VMID}/config"

echo "[strip-nics] Querying Proxmox VM config: VMID ${TEMPLATE_VMID} on ${PROXMOX_NODE}"

# ── Query current VM config ───────────────────────────────────────────────────
response=$(curl -sf \
  --insecure \
  -H "Authorization: ${AUTH_HEADER}" \
  "${CONFIG_URL}") || {
    echo "[strip-nics] ERROR: Failed to query VM config (VMID ${TEMPLATE_VMID})" >&2
    echo "[strip-nics] URL: ${CONFIG_URL}" >&2
    exit 1
}

# ── Extract net* keys ─────────────────────────────────────────────────────────
nic_keys=$(printf '%s' "${response}" \
  | jq -r '.data | keys[] | select(startswith("net"))' \
  | tr '\n' ',' \
  | sed 's/,$//')

if [[ -z "${nic_keys}" ]]; then
  echo "[strip-nics] No network interfaces found on VMID ${TEMPLATE_VMID} — nothing to remove."
  exit 0
fi

echo "[strip-nics] Found interfaces: ${nic_keys}"
echo "[strip-nics] Removing all network interfaces from VMID ${TEMPLATE_VMID}..."

# ── Delete all net* keys ──────────────────────────────────────────────────────
curl -sf \
  --insecure \
  -X PUT \
  -H "Authorization: ${AUTH_HEADER}" \
  --data-urlencode "delete=${nic_keys}" \
  "${CONFIG_URL}" > /dev/null || {
    echo "[strip-nics] ERROR: Failed to delete NICs from VMID ${TEMPLATE_VMID}" >&2
    exit 1
}

echo "[strip-nics] Done. Network interfaces removed: ${nic_keys}"
exit 0

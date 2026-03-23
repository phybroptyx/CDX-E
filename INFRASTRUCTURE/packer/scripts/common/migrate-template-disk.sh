#!/usr/bin/env bash
# =============================================================================
# migrate-template-disk.sh — Move primary disk to target storage post-build
# =============================================================================
# Called as a Packer shell-local provisioner (runs on the Packer build host)
# after sysprep shuts down the VM. Moves scsi0 from the build storage pool to
# TARGET_STORAGE via the Proxmox move_disk API, then waits for the task to
# complete before Packer converts the VM to a template.
#
# Required environment variables (injected by Packer shell-local env block):
#   PROXMOX_API_URL           https://cdx-pve-01:8006/api2/json
#   PROXMOX_API_TOKEN_ID      e.g. ansible@pam!ansible
#   PROXMOX_API_TOKEN_SECRET  token UUID
#   PROXMOX_NODE              e.g. cdx-pve-01
#   TEMPLATE_VMID             numeric VMID of the build VM
#   TARGET_STORAGE            destination storage pool (e.g. QNAP)
#
# Exit codes:
#   0  — success (disk moved)
#   1  — API error, task failure, or missing required variable
# =============================================================================

set -euo pipefail

# ── Validate required environment variables ───────────────────────────────────
: "${PROXMOX_API_URL:?PROXMOX_API_URL is required}"
: "${PROXMOX_API_TOKEN_ID:?PROXMOX_API_TOKEN_ID is required}"
: "${PROXMOX_API_TOKEN_SECRET:?PROXMOX_API_TOKEN_SECRET is required}"
: "${PROXMOX_NODE:?PROXMOX_NODE is required}"
: "${TEMPLATE_VMID:?TEMPLATE_VMID is required}"
: "${TARGET_STORAGE:?TARGET_STORAGE is required}"

AUTH_HEADER="PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}"
BASE_URL="${PROXMOX_API_URL}/nodes/${PROXMOX_NODE}"

echo "[migrate-disk] Waiting for VM ${TEMPLATE_VMID} to stop (sysprep /shutdown runs async, max 300s)..."
for i in $(seq 1 60); do
  VM_STATUS=$(curl -sf \
    --insecure \
    -H "Authorization: ${AUTH_HEADER}" \
    "${BASE_URL}/qemu/${TEMPLATE_VMID}/status/current" | jq -r '.data.status')
  if [[ "${VM_STATUS}" == "stopped" ]]; then
    echo "[migrate-disk] VM stopped after ~$((i * 5))s."
    break
  fi
  echo "[migrate-disk]   [${i}/60] status: ${VM_STATUS} — waiting 5s..."
  sleep 5
done
if [[ "${VM_STATUS}" != "stopped" ]]; then
  echo "[migrate-disk] ERROR: VM ${TEMPLATE_VMID} did not stop within 300s" >&2
  exit 1
fi

echo "[migrate-disk] Moving scsi0 of VMID ${TEMPLATE_VMID} to ${TARGET_STORAGE}..."

# ── Initiate disk move ────────────────────────────────────────────────────────
TASK=$(curl -sf \
  --insecure \
  -X POST \
  -H "Authorization: ${AUTH_HEADER}" \
  -d "disk=scsi0&storage=${TARGET_STORAGE}&delete=1" \
  "${BASE_URL}/qemu/${TEMPLATE_VMID}/move_disk") || {
    echo "[migrate-disk] ERROR: Failed to initiate move_disk API call" >&2
    exit 1
}

UPID=$(printf '%s' "${TASK}" | jq -r '.data')
if [[ -z "${UPID}" || "${UPID}" == "null" ]]; then
  echo "[migrate-disk] ERROR: No task UPID returned from API" >&2
  exit 1
fi

# URL-encode the UPID (contains colons and slashes)
UPID_ENC=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${UPID}")
TASK_URL="${BASE_URL}/tasks/${UPID_ENC}/status"

echo "[migrate-disk] Task UPID: ${UPID}"
echo "[migrate-disk] Polling for completion (max 300s)..."

# ── Poll task status ──────────────────────────────────────────────────────────
for i in $(seq 1 60); do
  sleep 5
  STATUS_RESP=$(curl -sf \
    --insecure \
    -H "Authorization: ${AUTH_HEADER}" \
    "${TASK_URL}") || {
      echo "[migrate-disk] WARNING: Status poll failed (attempt ${i}) — retrying" >&2
      continue
  }

  STATUS=$(printf '%s' "${STATUS_RESP}" | jq -r '.data.status')
  echo "[migrate-disk]   [${i}/60] status: ${STATUS}"

  if [[ "${STATUS}" == "stopped" ]]; then
    EXITSTATUS=$(printf '%s' "${STATUS_RESP}" | jq -r '.data.exitstatus')
    if [[ "${EXITSTATUS}" == "OK" ]]; then
      echo "[migrate-disk] Disk migration complete. scsi0 now on ${TARGET_STORAGE}."
      exit 0
    else
      echo "[migrate-disk] ERROR: Task stopped with exitstatus: ${EXITSTATUS}" >&2
      exit 1
    fi
  fi
done

echo "[migrate-disk] ERROR: Timed out waiting for disk migration after 300s" >&2
exit 1

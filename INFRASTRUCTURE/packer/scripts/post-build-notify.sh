#!/bin/bash
# =============================================================================
# Post-Build Internet Dependency Notification
# =============================================================================
# Run this script after ALL Packer template builds have completed successfully.
# It verifies that all expected templates exist in Proxmox, then notifies the
# range administrator that Internet connectivity is no longer required.
#
# Usage:
#   ./post-build-notify.sh [proxmox_host] [api_token_id] [api_token_secret]
#
# If no arguments are provided, defaults are used from environment variables:
#   PROXMOX_HOST, PROXMOX_TOKEN_ID, PROXMOX_TOKEN_SECRET
# =============================================================================

set -e

PROXMOX_HOST="${1:-${PROXMOX_HOST:-cdx-pve-01}}"
TOKEN_ID="${2:-${PROXMOX_TOKEN_ID:-ansible@pam!ansible}}"
TOKEN_SECRET="${3:-${PROXMOX_TOKEN_SECRET}}"

# Expected template VMIDs (all 22 Packer-built templates)
EXPECTED_VMIDS=(
  2023  # VyOS
  2024  # Windows Server 2008 R2 Datacenter
  2025  # Windows 7 SP1
  2026  # Windows Server 2012 R2 Datacenter
  2027  # Windows Server 2012 R2 Datacenter (Server Core)
  2028  # Windows 8.1
  2029  # Windows Server 2016 Datacenter
  2030  # Windows Server 2016 Datacenter (Server Core)
  2031  # Windows Server 2019 Datacenter
  2032  # Windows Server 2019 Datacenter (Server Core)
  2033  # Windows Server 2022 Datacenter
  2034  # Windows Server 2022 Datacenter (Server Core)
  2035  # Windows 10 21H2
  2036  # Windows 11 21H2
  2037  # Windows Server 2025 Datacenter
  2038  # Windows Server 2025 Datacenter (Server Core)
  2039  # Kali Linux 2025.4
  2040  # Kali Linux (Purple) 2025.4
  2041  # Ubuntu 21.10
  2042  # Ubuntu Server 16.04
  2043  # CentOS 7 Server
  2044  # CentOS 7 GNOME Desktop
)

TOTAL=${#EXPECTED_VMIDS[@]}
FOUND=0
MISSING=()

echo "============================================================================="
echo " CDX Packer Template Build - Post-Build Verification"
echo "============================================================================="
echo ""
echo "Checking Proxmox host: ${PROXMOX_HOST}"
echo "Expected templates: ${TOTAL}"
echo ""

if [ -z "${TOKEN_SECRET}" ]; then
  echo "[WARN] No Proxmox API token secret provided."
  echo "       Skipping live template verification."
  echo "       To enable, set PROXMOX_TOKEN_SECRET or pass as argument 3."
  echo ""
  echo "============================================================================="
  echo " MANUAL VERIFICATION REQUIRED"
  echo "============================================================================="
  echo ""
  echo "Please verify the following ${TOTAL} template VMIDs exist in Proxmox:"
  for vmid in "${EXPECTED_VMIDS[@]}"; do
    echo "  - VMID ${vmid}"
  done
  echo ""
else
  API_URL="https://${PROXMOX_HOST}:8006/api2/json"
  AUTH_HEADER="Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}"

  for vmid in "${EXPECTED_VMIDS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k \
      -H "${AUTH_HEADER}" \
      "${API_URL}/cluster/resources?type=vm" 2>/dev/null || echo "000")

    if [ "${HTTP_CODE}" = "000" ]; then
      echo "[ERROR] Cannot reach Proxmox API at ${API_URL}"
      echo "        Falling back to manual verification."
      break
    fi

    # Check if VMID exists as a template
    RESULT=$(curl -s -k -H "${AUTH_HEADER}" \
      "${API_URL}/cluster/resources?type=vm" 2>/dev/null | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
for vm in data.get('data', []):
    if vm.get('vmid') == ${vmid} and vm.get('template', 0) == 1:
        print('FOUND')
        sys.exit(0)
print('MISSING')
" 2>/dev/null || echo "ERROR")

    if [ "${RESULT}" = "FOUND" ]; then
      FOUND=$((FOUND + 1))
      echo "  [OK]    VMID ${vmid}"
    else
      MISSING+=("${vmid}")
      echo "  [MISS]  VMID ${vmid}"
    fi
  done

  echo ""
  echo "Results: ${FOUND}/${TOTAL} templates found"
fi

echo ""
echo "============================================================================="

if [ ${#MISSING[@]} -eq 0 ] && [ ${FOUND} -eq ${TOTAL} ]; then
  echo ""
  echo "  ALL ${TOTAL} PACKER TEMPLATES VERIFIED SUCCESSFULLY"
  echo ""
  echo "  +----------------------------------------------------------+"
  echo "  |  INTERNET CONNECTIVITY IS NO LONGER REQUIRED             |"
  echo "  |                                                          |"
  echo "  |  All Packer template builds are complete. The range      |"
  echo "  |  can now operate in air-gapped mode. You may safely      |"
  echo "  |  disconnect the upstream Internet connection.             |"
  echo "  |                                                          |"
  echo "  |  Remaining deployment steps (Terraform clone, Ansible    |"
  echo "  |  post-config) use only local Proxmox resources and       |"
  echo "  |  do not require external network access.                 |"
  echo "  +----------------------------------------------------------+"
  echo ""
elif [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "  WARNING: ${#MISSING[@]} TEMPLATE(S) MISSING"
  echo ""
  echo "  The following templates were not found as Proxmox templates:"
  for vmid in "${MISSING[@]}"; do
    echo "    - VMID ${vmid}"
  done
  echo ""
  echo "  INTERNET CONNECTIVITY IS STILL REQUIRED for missing builds."
  echo "  Re-run the Packer builds for missing templates, then re-run"
  echo "  this script to verify."
  echo ""
fi

echo "============================================================================="

#!/usr/bin/env bash
# =============================================================================
# build-vyos-template.sh — CDX-E VyOS 1.5 Packer Build Driver
# =============================================================================
#
# USAGE
#   Place this script in:
#     INFRASTRUCTURE/packer/build-vyos-template.sh
#   Run it directly from any working directory — it locates all paths
#   relative to its own real filesystem location:
#     /home/ansible/Ansible/test/cdx-e/INFRASTRUCTURE/packer/build-vyos-template.sh
#
# WHAT IT DOES
#   1. Validates that every required file and binary is present.
#   2. Extracts the Proxmox API token secret from secrets/credentials.yml
#      using Python3 + PyYAML (guaranteed on the Ansible controller node).
#   3. Exports PKR_VAR_proxmox_api_token_secret so the secret never appears
#      in the process argument list or script output.
#   4. Optionally runs `packer init` if the Proxmox plugin is not pre-staged.
#   5. Runs `packer build` for templates/vyos.pkr.hcl.
#   6. Reports elapsed wall-clock time and build result.
#
# PREREQUISITES
#   - Bash 4.4+ (shopt -s inherit_errexit)
#   - /usr/local/bin/packer >= 1.9.0
#   - Python3 + PyYAML (pip3 install pyyaml)
#   - secrets/credentials.yml populated with proxmox.api_token_secret
#   - VyOS ISO pre-staged on QNAP Proxmox storage
#
# EXIT CODES
#   0  Build succeeded
#   1  Preflight validation failure
#   2  Secret extraction failure
#   3  Packer init failure
#   4  Packer build failure
#
# SECURITY NOTES
#   - The Proxmox API token secret is never written to disk or passed as a
#     CLI argument. It is injected solely via PKR_VAR_proxmox_api_token_secret.
#   - A trap on EXIT unsets PKR_VAR_proxmox_api_token_secret regardless of
#     how the script terminates.
# =============================================================================

set -Eeuo pipefail
shopt -s inherit_errexit

# =============================================================================
# Colour and logging helpers
# =============================================================================

# Detect whether stdout is a terminal; fall back to no-colour in pipelines
if [[ -t 1 ]] && command -v tput &>/dev/null; then
  _CLR_RED="$(tput setaf 1)"
  _CLR_GRN="$(tput setaf 2)"
  _CLR_YLW="$(tput setaf 3)"
  _CLR_CYN="$(tput setaf 6)"
  _CLR_BLD="$(tput bold)"
  _CLR_RST="$(tput sgr0)"
else
  _CLR_RED=""
  _CLR_GRN=""
  _CLR_YLW=""
  _CLR_CYN=""
  _CLR_BLD=""
  _CLR_RST=""
fi

log_info()    { printf '%s[INFO]%s  %s\n'    "${_CLR_CYN}"  "${_CLR_RST}" "$*" >&2; }
log_ok()      { printf '%s[ OK ]%s  %s\n'    "${_CLR_GRN}"  "${_CLR_RST}" "$*" >&2; }
log_warn()    { printf '%s[WARN]%s  %s\n'    "${_CLR_YLW}"  "${_CLR_RST}" "$*" >&2; }
log_error()   { printf '%s[FAIL]%s  %s\n'    "${_CLR_RED}"  "${_CLR_RST}" "$*" >&2; }
log_header()  { printf '\n%s%s=== %s ===%s\n\n' "${_CLR_BLD}" "${_CLR_CYN}" "$*" "${_CLR_RST}" >&2; }

# =============================================================================
# Constants — all paths defined once here
# =============================================================================

# Resolve the real directory of this script regardless of symlinks or cwd
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR

# Packer binary
readonly PACKER_BINARY="/usr/local/bin/packer"

# Packer plugin cache — checked to skip `packer init` when already staged
readonly PACKER_PLUGIN_PATH="/opt/packer/plugins"

# Template and variable directories (relative to this script's location)
readonly TEMPLATES_DIR="${SCRIPT_DIR}/templates"
readonly VARS_DIR="${SCRIPT_DIR}/vars"

# Secrets file (lowercase 'secrets' directory, project root)
# Project root is two levels up from INFRASTRUCTURE/packer/
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
readonly SECRETS_FILE="${PROJECT_ROOT}/secrets/credentials.yml"

# Packer template and var-file names
readonly TEMPLATE_FILE="vyos.pkr.hcl"
readonly COMMON_VARS_FILE="common.pkrvars.hcl"
readonly VYOS_VARS_FILE="vyos.pkrvars.hcl"

# Proxmox API token identity (non-secret; safe on the command line)
readonly PROXMOX_TOKEN_ID="ansible@pam!ansible"

# Proxmox plugin binary prefix (used to detect pre-staged plugin)
readonly PROXMOX_PLUGIN_GLOB="packer-plugin-proxmox*"

# =============================================================================
# Timing — record start time for elapsed wall-clock reporting
# =============================================================================
readonly _BUILD_START="${SECONDS}"

# =============================================================================
# Cleanup trap — unset the secret env-var on any exit path
# =============================================================================
_cleanup() {
  local exit_code="$?"
  unset PKR_VAR_proxmox_api_token_secret 2>/dev/null || true

  local elapsed=$(( SECONDS - _BUILD_START ))
  local minutes=$(( elapsed / 60 ))
  local seconds=$(( elapsed % 60 ))

  printf '\n' >&2
  if (( exit_code == 0 )); then
    log_ok "${_CLR_BLD}Build succeeded in ${minutes}m ${seconds}s.${_CLR_RST}"
  else
    log_error "${_CLR_BLD}Script exited with code ${exit_code} after ${minutes}m ${seconds}s.${_CLR_RST}"
  fi
}
trap '_cleanup' EXIT

# Trap SIGINT / SIGTERM — propagate cleanly through the EXIT trap above
trap 'log_warn "Interrupted by signal."; exit 130' INT TERM

# =============================================================================
# Header banner
# =============================================================================
printf '\n%s%s' "${_CLR_BLD}" "${_CLR_CYN}" >&2
printf '############################################################\n' >&2
printf '#  CDX-E Packer Build — VyOS 1.5 Rolling Base Template    #\n' >&2
printf '#  Template : %-44s #\n' "${TEMPLATE_FILE}" >&2
printf '#  Proxmox  : %-44s #\n' "${PROXMOX_TOKEN_ID}" >&2
printf '############################################################\n' >&2
printf '%s\n' "${_CLR_RST}" >&2

# =============================================================================
# Phase 1 — Preflight validation
# =============================================================================
log_header "Phase 1 — Preflight Checks"

_preflight_fail() {
  # $1 = item that failed, $2 = remediation instruction
  log_error "MISSING: ${1}"
  log_error "FIX:     ${2}"
  exit 1
}

# 1a. Packer binary
log_info "Checking Packer binary: ${PACKER_BINARY}"
if [[ ! -x "${PACKER_BINARY}" ]]; then
  _preflight_fail \
    "${PACKER_BINARY}" \
    "Install Packer: curl -fsSL https://releases.hashicorp.com/packer/ and place binary at ${PACKER_BINARY}"
fi
log_ok "Packer binary found: $("${PACKER_BINARY}" version 2>&1 | head -1)"

# 1b. Template file
log_info "Checking template: ${TEMPLATES_DIR}/${TEMPLATE_FILE}"
if [[ ! -f "${TEMPLATES_DIR}/${TEMPLATE_FILE}" ]]; then
  _preflight_fail \
    "${TEMPLATES_DIR}/${TEMPLATE_FILE}" \
    "Ensure the VyOS Packer template is present at the path above. Check out the CDX-E repo."
fi
log_ok "Template file found."

# 1c. Common var-file
log_info "Checking var-file: ${VARS_DIR}/${COMMON_VARS_FILE}"
if [[ ! -f "${VARS_DIR}/${COMMON_VARS_FILE}" ]]; then
  _preflight_fail \
    "${VARS_DIR}/${COMMON_VARS_FILE}" \
    "Ensure ${COMMON_VARS_FILE} exists in ${VARS_DIR}/. Check out the CDX-E repo."
fi
log_ok "Common var-file found."

# 1d. VyOS var-file
log_info "Checking var-file: ${VARS_DIR}/${VYOS_VARS_FILE}"
if [[ ! -f "${VARS_DIR}/${VYOS_VARS_FILE}" ]]; then
  _preflight_fail \
    "${VARS_DIR}/${VYOS_VARS_FILE}" \
    "Ensure ${VYOS_VARS_FILE} exists in ${VARS_DIR}/. Check out the CDX-E repo."
fi
log_ok "VyOS var-file found."

# 1e. Secrets file
log_info "Checking secrets: ${SECRETS_FILE}"
if [[ ! -f "${SECRETS_FILE}" ]]; then
  _preflight_fail \
    "${SECRETS_FILE}" \
    "Copy secrets.example/ to secrets/ and populate credentials.yml: cp -r secrets.example/ secrets/"
fi
if [[ ! -r "${SECRETS_FILE}" ]]; then
  _preflight_fail \
    "${SECRETS_FILE} (not readable)" \
    "Fix permissions: chmod 600 ${SECRETS_FILE} (run as the ansible user or with sudo)"
fi
log_ok "Secrets file found and readable."

# 1f. Python3 available (required for secret extraction)
log_info "Checking Python3 availability."
if ! command -v python3 &>/dev/null; then
  _preflight_fail \
    "python3 binary" \
    "Install Python3: apt-get install python3 (or equivalent for your distribution)"
fi
log_ok "Python3 found: $(python3 --version 2>&1)"

# 1g. PyYAML available
log_info "Checking PyYAML availability."
if ! python3 -c "import yaml" 2>/dev/null; then
  _preflight_fail \
    "Python3 PyYAML module" \
    "Install PyYAML: pip3 install pyyaml  -or-  apt-get install python3-yaml"
fi
log_ok "PyYAML is available."

# =============================================================================
# Phase 2 — Extract Proxmox API token secret from credentials.yml
# =============================================================================
log_header "Phase 2 — Extracting Proxmox API Token Secret"

log_info "Reading proxmox.api_token_secret from secrets/credentials.yml (via PyYAML)."

# Python3 reads the YAML and prints ONLY the secret value on stdout.
# All other output (errors) goes to stderr so the secret is never mixed
# with diagnostic messages. The Python process exits non-zero on any failure.
_raw_secret="$(python3 - "${SECRETS_FILE}" <<'PYEOF'
import sys
import yaml

secrets_path = sys.argv[1]

try:
    with open(secrets_path, "r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
except (OSError, IOError) as exc:
    print(f"ERROR: Cannot open secrets file: {exc}", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as exc:
    print(f"ERROR: YAML parse error in {secrets_path}: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print("ERROR: credentials.yml top-level structure is not a mapping.", file=sys.stderr)
    sys.exit(1)

proxmox_block = data.get("proxmox")
if not isinstance(proxmox_block, dict):
    print("ERROR: 'proxmox' key is missing or not a mapping in credentials.yml.", file=sys.stderr)
    sys.exit(1)

secret = proxmox_block.get("api_token_secret")
if secret is None:
    print("ERROR: 'proxmox.api_token_secret' key is missing from credentials.yml.", file=sys.stderr)
    sys.exit(1)

secret_str = str(secret).strip()
if not secret_str:
    print("ERROR: 'proxmox.api_token_secret' is present but empty.", file=sys.stderr)
    sys.exit(1)

# Print the secret and nothing else to stdout
print(secret_str, end="")
PYEOF
)" || {
  log_error "Failed to extract proxmox.api_token_secret from ${SECRETS_FILE}."
  log_error "Verify the file exists, is valid YAML, and contains:"
  log_error "  proxmox:"
  log_error "    api_token_secret: \"<UUID>\""
  exit 2
}

# Validate the extracted value is non-empty (belt-and-suspenders)
if [[ -z "${_raw_secret}" ]]; then
  log_error "Extracted token secret is empty — credentials.yml may be using a placeholder value."
  log_error "Open ${SECRETS_FILE} and replace REPLACE_WITH_ACTUAL_TOKEN with the real Proxmox token UUID."
  exit 2
fi

# Check for the placeholder string from secrets.example
if [[ "${_raw_secret}" == *"REPLACE_WITH"* ]]; then
  log_error "credentials.yml still contains a placeholder value for api_token_secret."
  log_error "Open ${SECRETS_FILE} and replace REPLACE_WITH_ACTUAL_TOKEN with the real Proxmox token UUID."
  exit 2
fi

# Export via environment variable — secret NEVER appears in argv or script output
export PKR_VAR_proxmox_api_token_secret="${_raw_secret}"
unset _raw_secret

log_ok "Proxmox API token secret extracted and exported as PKR_VAR_proxmox_api_token_secret."
log_warn "Secret is held only in memory. It will be unset on script exit."

# =============================================================================
# Phase 3 — Packer plugin check / init
# =============================================================================
log_header "Phase 3 — Packer Plugin Availability"

export PACKER_PLUGIN_PATH

log_info "Checking for pre-staged Proxmox plugin under: ${PACKER_PLUGIN_PATH}"

_plugin_found=0
if [[ -d "${PACKER_PLUGIN_PATH}" ]]; then
  # Use a glob expansion in an array — safe even when no files match
  _plugin_matches=()
  while IFS= read -r -d '' _p; do
    _plugin_matches+=("${_p}")
  done < <(find "${PACKER_PLUGIN_PATH}" -maxdepth 3 -name "${PROXMOX_PLUGIN_GLOB}" -print0 2>/dev/null)

  if (( ${#_plugin_matches[@]} > 0 )); then
    log_ok "Pre-staged Proxmox plugin found: ${_plugin_matches[0]}"
    _plugin_found=1
  fi
fi

if (( _plugin_found == 0 )); then
  log_warn "Proxmox plugin not found at ${PACKER_PLUGIN_PATH}."
  log_info "Running: packer init ${TEMPLATE_FILE}  (from ${TEMPLATES_DIR})"
  (
    cd -- "${TEMPLATES_DIR}"
    "${PACKER_BINARY}" init "${TEMPLATE_FILE}"
  ) || {
    log_error "packer init failed."
    log_error "Check internet connectivity from this node, or pre-stage the plugin at:"
    log_error "  ${PACKER_PLUGIN_PATH}"
    log_error "Plugin source: github.com/hashicorp/proxmox"
    exit 3
  }
  log_ok "packer init completed — Proxmox plugin is now installed."
else
  log_info "Skipping packer init — plugin already staged."
fi

# =============================================================================
# Phase 4 — Packer build
# =============================================================================
log_header "Phase 4 — Packer Build"

log_info "Working directory: ${TEMPLATES_DIR}"
log_info "Template         : ${TEMPLATE_FILE}"
log_info "Common vars      : ../vars/${COMMON_VARS_FILE}"
log_info "VyOS vars        : ../vars/${VYOS_VARS_FILE}"
log_info "Token ID         : ${PROXMOX_TOKEN_ID}"
log_info "Token secret     : [redacted — set in PKR_VAR_proxmox_api_token_secret]"
log_info "Plugin path      : ${PACKER_PLUGIN_PATH}"
printf '\n' >&2

# Build is executed in a subshell that changes directory to TEMPLATES_DIR.
# -var-file paths use ../ prefix as documented in the template header comment.
# The secret is passed solely via the exported env-var; it does NOT appear
# in the argument list visible to `ps aux`.
(
  cd -- "${TEMPLATES_DIR}"
  "${PACKER_BINARY}" build \
    -var-file="../vars/${COMMON_VARS_FILE}" \
    -var-file="../vars/${VYOS_VARS_FILE}" \
    -var "proxmox_api_token_id=${PROXMOX_TOKEN_ID}" \
    "${TEMPLATE_FILE}"
) || {
  _build_exit=$?
  log_error "packer build exited with code ${_build_exit}."
  log_error "Troubleshooting guidance:"
  log_error "  1. Check Proxmox API credentials: verify the token in ${SECRETS_FILE}"
  log_error "     and confirm the token has PVEVMAdmin + Datastore.AllocateSpace privileges."
  log_error "  2. Verify the VyOS ISO is staged on the QNAP storage pool under the iso/ directory."
  log_error "     iso_file value is set in ${VARS_DIR}/${VYOS_VARS_FILE}."
  log_error "  3. Check Proxmox node connectivity: ping cdx-pve-01 from this host."
  log_error "  4. Review packer output above for the exact error from the Proxmox provider."
  log_error "  5. For boot-command timing issues, open ${TEMPLATES_DIR}/${TEMPLATE_FILE}"
  log_error "     and increase the <wait> durations in the boot_command block."
  exit 4
}

# Success path — the EXIT trap will print elapsed time and exit 0
log_ok "${_CLR_BLD}VyOS Packer template build completed successfully.${_CLR_RST}"
log_ok "The cdx-vyos-base template is now registered on Proxmox."
log_info "Next step: run the deploy_packer_template Ansible role or proceed with"
log_info "           qm clone operations to provision VyOS router VMs from this template."

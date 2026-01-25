<#
.SYNOPSIS
    Deploy-ProxmoxVM.ps1 - Deploy multiple Proxmox VMs from YAML specification via SSH

.DESCRIPTION
    Reads a YAML specification file containing one or more VM definitions and
    executes Proxmox qm commands via SSH to clone templates, configure resources,
    add network interfaces, and optionally start the VMs.
    
    Supports filtering to deploy specific VMs by ID or name.
    
    Part of the CDX-E Framework for Operation OBSIDIAN DAGGER.

.PARAMETER YamlPath
    Path to the YAML specification file containing VM configurations.

.PARAMETER VmFilter
    Optional filter to deploy specific VMs. Can be:
    - VM ID (e.g., 5001)
    - VM name (e.g., "test-2016")
    - Comma-separated list (e.g., "5001,5002" or "test-2016,Test-2025")
    - "all" to deploy all VMs (default)

.PARAMETER Confirm
    If specified, bypasses the confirmation prompt and proceeds immediately.

.PARAMETER DryRun
    If specified, displays the commands that would be executed without running them.

.PARAMETER NoStart
    If specified, overrides start_after_clone and leaves all VMs stopped.

.NOTES
    Script:     Deploy-ProxmoxVM.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    2.0
    Created:    2025-01-22
    Updated:    2025-01-23
    
    Version History:
    1.0  2025-01-22  Initial release - Single VM deployment from YAML
    1.1  2025-01-22  Fixed ASCII encoding, linked clone logic, SSH quoting
    1.2  2025-01-22  Multi-NIC support with optional MAC addresses
    2.0  2025-01-23  Multi-VM support, -VmFilter, -Confirm parameter
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module (Install-Module powershell-yaml)
        - SSH key authentication configured to Proxmox node
#>

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "2.0"
$Script:Name = "Deploy-ProxmoxVM"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2025-01-23"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$YamlPath,
    
    [Parameter(Mandatory = $false)]
    [string]$VmFilter = "all",
    
    [Parameter(Mandatory = $false)]
    [switch]$Confirm,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoStart
)

# NOTE: This is a summary version showing the key structural changes in 2.0
# The full implementation includes all helper functions and deployment logic
# Key changes from 1.2:
# - YAML now uses virtual_machines array instead of single vm_specification
# - Added -VmFilter parameter for selective deployment
# - Added -Confirm parameter to bypass prompts
# - Added -NoStart parameter
# - Iterates through VMs with Deploy-SingleVM function
# - Results summary at completion

Write-Host "Deploy-ProxmoxVM v$Script:Version - Multi-VM Support"
Write-Host "This version introduced:"
Write-Host "  - virtual_machines array in YAML"
Write-Host "  - -VmFilter parameter (ID, name, comma-list, or 'all')"
Write-Host "  - -Confirm parameter for auto-approval"
Write-Host "  - -NoStart parameter"
Write-Host "  - Deployment results summary"

<#
.SYNOPSIS
    Invoke-CDX-E.ps1 - Comprehensive Proxmox VM lifecycle management for CDX-E exercises

.DESCRIPTION
    Manages the complete lifecycle of Proxmox VMs defined in a YAML specification file.
    Supports deployment, destruction, start/stop operations, and status reporting.
    
    All operations can target individual VMs, multiple VMs, or all exercise VMs.
    
    Part of the CDX-E Framework.

.PARAMETER Action
    The operation to perform. Valid options:
    - Deploy   : Clone templates and configure new VMs
    - Destroy  : Stop and permanently remove VMs
    - Start    : Start stopped VMs
    - Stop     : Stop running VMs
    - Status   : Report current state of VMs

.PARAMETER YamlPath
    Path to the YAML specification file containing VM configurations.

.PARAMETER VmFilter
    Optional filter to target specific VMs.

.PARAMETER Confirm
    If specified, bypasses the confirmation prompt.

.PARAMETER DryRun
    If specified, displays commands without executing.

.PARAMETER NoStart
    For Deploy action only: leaves VMs stopped.

.NOTES
    Script:     Invoke-CDX-E.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    2.1
    Created:    2025-01-22
    Updated:    2025-01-23
    
    Version History:
    1.0  2025-01-22  Initial release (Deploy-ProxmoxVM.ps1) - Single VM deployment
    1.1  2025-01-22  Fixed ASCII encoding, linked clone logic, SSH quoting
    1.2  2025-01-22  Multi-NIC support with optional MAC addresses
    2.0  2025-01-23  Multi-VM support, -VmFilter, -Confirm parameter
    2.1  2025-01-23  Multi-action refactor (-Action: Deploy, Destroy, Start, Stop, Status)
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module
        - SSH key authentication configured to Proxmox node
#>

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "2.1"
$Script:Name = "Invoke-CDX-E"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2025-01-23"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Deploy", "Destroy", "Start", "Stop", "Status")]
    [string]$Action,
    
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

# NOTE: This is a summary version showing the key structural changes in 2.1
# Key changes from 2.0:
# - Renamed from Deploy-ProxmoxVM.ps1 to Invoke-CDX-E.ps1
# - Added -Action parameter with ValidateSet
# - Implemented action functions:
#   - Invoke-DeployAction
#   - Invoke-DestroyAction (qm stop + qm destroy --purge)
#   - Invoke-StartAction
#   - Invoke-StopAction
#   - Invoke-StatusAction (formatted table output)
# - Color-coded output per action type
# - Switch statement for action dispatch

Write-Host "Invoke-CDX-E v$Script:Version - Multi-Action Lifecycle Management"
Write-Host "This version introduced:"
Write-Host "  - Renamed to Invoke-CDX-E.ps1"
Write-Host "  - -Action parameter: Deploy, Destroy, Start, Stop, Status"
Write-Host "  - Destroy action: qm stop + qm destroy --purge"
Write-Host "  - Status action: formatted table with VM states"
Write-Host "  - Color-coded output per action type"

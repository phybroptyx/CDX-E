<#
.SYNOPSIS
    Invoke-CDX-E.ps1 - Comprehensive Proxmox VM lifecycle management for CDX-E exercises

.DESCRIPTION
    Manages the complete lifecycle of Proxmox VMs defined in a YAML specification file.
    Supports deployment, destruction, start/stop operations, and status reporting.
    
    All operations can target individual VMs, multiple VMs, or all exercise VMs.
    
    Supports cloud-init configuration for static IP addressing on deployment.
    
    Part of the CDX-E Framework.

.PARAMETER Action
    The operation to perform. Valid options:
    - Deploy   : Clone templates and configure new VMs (including cloud-init)
    - Destroy  : Stop and permanently remove VMs
    - Start    : Start stopped VMs
    - Stop     : Stop running VMs
    - Status   : Report current state of VMs

.NOTES
    Script:     Invoke-CDX-E.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    2.2
    Created:    2025-01-22
    Updated:    2025-01-23
    
    Version History:
    1.0  2025-01-22  Initial release (Deploy-ProxmoxVM.ps1) - Single VM deployment
    1.1  2025-01-22  Fixed ASCII encoding, linked clone logic, SSH quoting
    1.2  2025-01-22  Multi-NIC support with optional MAC addresses
    2.0  2025-01-23  Multi-VM support, -VmFilter, -Confirm parameter
    2.1  2025-01-23  Multi-action refactor (-Action: Deploy, Destroy, Start, Stop, Status)
    2.2  2025-01-23  Cloud-init integration for static IP configuration
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module
        - SSH key authentication configured to Proxmox node
        - Cloud-init enabled templates with ide2 cloud-init drive
#>

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "2.2"
$Script:Name = "Invoke-CDX-E"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2025-01-23"

# NOTE: This is a summary version showing the key structural changes in 2.2
# Key changes from 2.1:
# - Added cloud_init section to YAML:
#   cloud_init:
#     ipconfig1: "ip=x.x.x.x/24,gw=y.y.y.y"
#     nameserver: "z.z.z.z"
# - Deploy action now sets cloud-init parameters via qm set --ipconfig1 --nameserver
# - Status display includes IP addresses from cloud_init config
# - Show-VMList displays IP/DNS information
# - NOTE: This version had a bug - ipconfig was not being applied properly

Write-Host "Invoke-CDX-E v$Script:Version - Cloud-Init Integration"
Write-Host "This version introduced:"
Write-Host "  - cloud_init section in YAML (ipconfig1, nameserver)"
Write-Host "  - Deploy sets --ipconfig1 and --nameserver via qm set"
Write-Host "  - Status display includes IP addresses"
Write-Host "  - NOTE: Had bug - required v2.3 fix for cloudinit update"

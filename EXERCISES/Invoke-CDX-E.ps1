<#
.SYNOPSIS
    Invoke-CDX-E.ps1 - Comprehensive Proxmox VM lifecycle management for CDX-E exercises

.DESCRIPTION
    Manages the complete lifecycle of Proxmox VMs defined in a YAML specification file.
    Supports deployment, destruction, start/stop operations, and status reporting.
    
    All operations can target individual VMs, multiple VMs, or all exercise VMs.
    
    Supports cloud-init configuration for static IP addressing on deployment.
    Auto-generates VM descriptions from structured YAML fields.
    
    Part of the CDX-E Framework.

.NOTES
    Script:     Invoke-CDX-E.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    2.3
    Created:    2025-01-22
    Updated:    2025-01-23
    
    Version History:
    1.0  2025-01-22  Initial release (Deploy-ProxmoxVM.ps1) - Single VM deployment
    1.1  2025-01-22  Fixed ASCII encoding, linked clone logic, SSH quoting
    1.2  2025-01-22  Multi-NIC support with optional MAC addresses
    2.0  2025-01-23  Multi-VM support, -VmFilter, -Confirm parameter
    2.1  2025-01-23  Multi-action refactor (-Action: Deploy, Destroy, Start, Stop, Status)
    2.2  2025-01-23  Cloud-init integration for static IP configuration
    2.3  2025-01-23  Cloud-init fix (qm cloudinit update), auto-generated descriptions
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module
        - SSH key authentication configured to Proxmox node
        - Cloud-init enabled templates with ide2 cloud-init drive
#>

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "2.3"
$Script:Name = "Invoke-CDX-E"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2025-01-23"

# NOTE: This is a summary version showing the key structural changes in 2.3
# Key changes from 2.2:
# - FIXED cloud-init: Added "qm cloudinit update $vmid" after setting ipconfig
# - Restructured YAML cloud_init section to use discrete fields:
#   cloud_init:
#     ip: "57.92.89.71"
#     cidr: 24
#     gateway: "57.92.89.1"
#     nameserver: "127.0.0.1"
# - Added structured fields for auto-description: role, site, organization
# - Added Build-VMDescription function
# - Description format: "Hostname | Role | Organization | Site | IP/CIDR | OS"
# - Proper quoting of ipconfig value: --ipconfig1 'ip=x/24,gw=y'

Write-Host "Invoke-CDX-E v$Script:Version - Cloud-Init Fix + Auto Descriptions"
Write-Host "This version introduced:"
Write-Host "  - FIXED: Added 'qm cloudinit update' command"
Write-Host "  - Restructured cloud_init: ip, cidr, gateway, nameserver fields"
Write-Host "  - Added role, site, organization fields to YAML"
Write-Host "  - Build-VMDescription function"
Write-Host "  - Description format: Hostname | Role | Org | Site | IP | OS"
Write-Host "  - Proper single-quote escaping for ipconfig"

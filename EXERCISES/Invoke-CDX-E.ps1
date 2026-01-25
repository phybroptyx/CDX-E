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

.PARAMETER Action
    The operation to perform. Valid options:
    - Deploy   : Clone templates and configure new VMs (including cloud-init)
    - Destroy  : Stop and permanently remove VMs
    - Start    : Start stopped VMs
    - Stop     : Stop running VMs
    - Status   : Report current state of VMs

.PARAMETER YamlPath
    Path to the YAML specification file containing VM configurations.

.PARAMETER VmFilter
    Optional filter to target specific VMs. Can be:
    - VM ID (e.g., 5101)
    - VM name (e.g., "MDP-DC-01")
    - Comma-separated list (e.g., "5101,5102" or "MDP-DC-01,MDP-FS-01")
    - "all" to target all VMs (default)

.PARAMETER Confirm
    If specified, bypasses the confirmation prompt and proceeds immediately.

.PARAMETER DryRun
    If specified, displays the commands that would be executed without running them.

.PARAMETER NoStart
    For Deploy action only: leaves VMs in stopped state after creation.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Deploy -YamlPath ".\obsidian_dagger_vms.yaml"
    Deploys all VMs defined in the YAML file with confirmation prompt.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Deploy -YamlPath ".\obsidian_dagger_vms.yaml" -Confirm
    Deploys all VMs without confirmation prompt.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Destroy -YamlPath ".\obsidian_dagger_vms.yaml" -VmFilter 5102 -Confirm
    Destroys only VM ID 5102.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Stop -YamlPath ".\obsidian_dagger_vms.yaml" -VmFilter "5101,5103"
    Stops VMs 5101 and 5103.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Start -YamlPath ".\obsidian_dagger_vms.yaml"
    Starts all exercise VMs.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Status -YamlPath ".\obsidian_dagger_vms.yaml"
    Reports the current state of all exercise VMs.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Destroy -YamlPath ".\obsidian_dagger_vms.yaml" -DryRun
    Shows destruction commands without executing them.

.NOTES
    Script:     Invoke-CDX-E.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    2.4
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
    2.4  2025-01-23  Markdown-formatted VM descriptions
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module (Install-Module powershell-yaml)
        - SSH key authentication configured to Proxmox node
        - Cloud-init enabled templates with ide2 cloud-init drive
#>

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "2.4"
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

# =============================================================================
# Module Check
# =============================================================================
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "[!] Required module 'powershell-yaml' not found." -ForegroundColor Yellow
    Write-Host "[*] Installing powershell-yaml module..." -ForegroundColor Cyan
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module powershell-yaml -ErrorAction Stop
        Write-Host "[+] Module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install powershell-yaml module: $_"
        exit 1
    }
}
else {
    Import-Module powershell-yaml -ErrorAction Stop
}

# =============================================================================
# Common Functions
# =============================================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{
        "Info"    = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
    }
    $prefixes = @{
        "Info"    = "[*]"
        "Success" = "[+]"
        "Warning" = "[!]"
        "Error"   = "[-]"
    }
    
    Write-Host "$($prefixes[$Level]) [$timestamp] $Message" -ForegroundColor $colors[$Level]
}

function Invoke-SSHCommand {
    param(
        [string]$TargetHost,
        [string]$User,
        [string]$Command,
        [switch]$DryRun,
        [switch]$Silent
    )
    
    $sshCommand = "ssh -o StrictHostKeyChecking=accept-new $User@$TargetHost `"$Command`""
    
    if ($DryRun) {
        if (-not $Silent) {
            Write-Log "DRY RUN: $sshCommand" -Level Info
        }
        return @{ Success = $true; Output = "DRY RUN - Command not executed" }
    }
    
    if (-not $Silent) {
        Write-Log "Executing: $Command" -Level Info
    }
    
    try {
        $output = Invoke-Expression $sshCommand 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            return @{ Success = $true; Output = $output }
        }
        else {
            return @{ Success = $false; Output = $output; ExitCode = $exitCode }
        }
    }
    catch {
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}

function Build-NicConfigString {
    param(
        [object]$NicConfig
    )
    
    $configParts = @($NicConfig.model)
    
    if ($NicConfig.mac) {
        $configParts[0] = "$($NicConfig.model)=$($NicConfig.mac)"
    }
    
    $configParts += "bridge=$($NicConfig.bridge)"
    
    $firewallValue = if ($NicConfig.firewall) { 1 } else { 0 }
    $configParts += "firewall=$firewallValue"
    
    if ($NicConfig.tag) {
        $configParts += "tag=$($NicConfig.tag)"
    }
    
    return ($configParts -join ",")
}

function Build-VMDescription {
    param(
        [object]$VM
    )
    
    # Auto-generate description from structured fields in Markdown format
    
    $hostname = $VM.name
    $role = if ($VM.role) { $VM.role } else { "Unknown Role" }
    $site = if ($VM.site) { $VM.site } else { "Unknown Site" }
    $org = if ($VM.organization) { $VM.organization } else { "Unknown Organization" }
    $os = if ($VM.template.os) { $VM.template.os } else { "Unknown OS" }
    
    # Build IP string from cloud_init if available
    $ipString = "DHCP"
    if ($VM.cloud_init -and $VM.cloud_init.ip) {
        $ip = $VM.cloud_init.ip
        $cidr = if ($VM.cloud_init.cidr) { $VM.cloud_init.cidr } else { "24" }
        $ipString = "$ip/$cidr"
    }
    
    # Build Markdown description
    $desc = @"
# $hostname
## $os
## $role
## $org, $site
### $ipString
"@
    
    return $desc
}

function Get-FilteredVMs {
    param(
        [array]$AllVMs,
        [string]$Filter
    )
    
    if ($Filter -eq "all") {
        return $AllVMs
    }
    
    $filterList = $Filter -split "," | ForEach-Object { $_.Trim() }
    $filtered = $AllVMs | Where-Object {
        $_.vmid -in $filterList -or $_.name -in $filterList
    }
    
    return $filtered
}

function Show-VMList {
    param(
        [array]$VMs,
        [string]$Title
    )
    
    Write-Host ""
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  $($Title.PadRight(65))|" -ForegroundColor DarkGray
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
    
    foreach ($vm in $VMs) {
        $role = if ($vm.role) { $vm.role } else { "N/A" }
        $site = if ($vm.site) { $vm.site } else { "N/A" }
        
        Write-Host "|  VM $($vm.vmid): $($vm.name)" -ForegroundColor White
        Write-Host "|    Role: $role | Site: $site" -ForegroundColor DarkGray
        Write-Host "|    Template: $($vm.template.id) ($($vm.template.os))" -ForegroundColor DarkGray
        Write-Host "|    Node: $($vm.proxmox.node) | Pool: $($vm.proxmox.pool)" -ForegroundColor DarkGray
        
        # Display cloud-init IP if configured
        if ($vm.cloud_init -and $vm.cloud_init.ip) {
            $cidr = if ($vm.cloud_init.cidr) { $vm.cloud_init.cidr } else { "24" }
            Write-Host "|    IP (net1): $($vm.cloud_init.ip)/$cidr | GW: $($vm.cloud_init.gateway) | DNS: $($vm.cloud_init.nameserver)" -ForegroundColor DarkGray
        }
        
        Write-Host "|" -ForegroundColor DarkGray
    }
    
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
}

function Request-Confirmation {
    param(
        [string]$Action,
        [int]$Count,
        [switch]$AutoConfirm,
        [switch]$DryRun
    )
    
    if ($DryRun) {
        return $true
    }
    
    if ($AutoConfirm) {
        Write-Log "Auto-confirm enabled - skipping confirmation prompt." -Level Info
        return $true
    }
    
    Write-Host ""
    $prompt = "Proceed with $Action of $Count VM(s)? (Y/N)"
    $response = Read-Host $prompt
    
    if ($response -match "^[Yy]") {
        return $true
    }
    
    Write-Log "$Action cancelled by user." -Level Warning
    return $false
}

# =============================================================================
# Action: Deploy
# =============================================================================
function Invoke-DeployAction {
    param(
        [array]$VMs,
        [object]$SSH,
        [switch]$DryRun,
        [switch]$NoStart
    )
    
    $results = @()
    
    foreach ($vm in $VMs) {
        Write-Host ""
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  Deploying: $($vm.name) (VM $($vm.vmid))" -ForegroundColor Cyan
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Cyan
        
        $success = $true
        $vmid = $vm.vmid
        $sshHost = $SSH.host
        $sshUser = $SSH.user
        
        # Step 1: Clone
        Write-Log "Cloning template $($vm.template.id) to VM $vmid..." -Level Info
        
        if ($vm.clone.type -eq "full") {
            $cloneCmd = "qm clone $($vm.template.id) $vmid --name $($vm.name) --pool $($vm.proxmox.pool) --target $($vm.proxmox.node) --storage $($vm.clone.target_storage) --full"
        }
        else {
            $cloneCmd = "qm clone $($vm.template.id) $vmid --name $($vm.name) --pool $($vm.proxmox.pool) --target $($vm.proxmox.node)"
        }
        
        $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $cloneCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Clone failed: $($result.Output)" -Level Error
            $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "Clone" }
            continue
        }
        Write-Log "Clone successful." -Level Success
        
        if (-not $DryRun) { Start-Sleep -Seconds 8 }
        
        # Step 2: Configure Resources and Auto-Generate Description
        Write-Log "Configuring VM resources..." -Level Info
        
        $autoDescription = Build-VMDescription -VM $vm
        $escapedDescription = $autoDescription -replace "'", "'\''"
        $tags = $vm.proxmox.tags -join ";"
        $configCmd = "qm set $vmid --memory $($vm.resources.memory_mb) --cores $($vm.resources.cores) --sockets $($vm.resources.sockets) --description '$escapedDescription' --tags $tags"
        
        $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $configCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Resource configuration failed: $($result.Output)" -Level Error
            $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "Configure" }
            continue
        }
        Write-Log "Resources configured." -Level Success
        Write-Log "Description: $autoDescription" -Level Info
        
        # Step 3: Add NICs
        if ($vm.network.additional_nics -and $vm.network.additional_nics.Count -gt 0) {
            Write-Log "Adding $($vm.network.additional_nics.Count) network interface(s)..." -Level Info
            
            foreach ($nic in $vm.network.additional_nics) {
                $nicConfig = Build-NicConfigString -NicConfig $nic
                $nicCmd = "qm set $vmid --net$($nic.nic_id) $nicConfig"
                
                $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $nicCmd -DryRun:$DryRun
                
                if (-not $result.Success -and -not $DryRun) {
                    Write-Log "NIC configuration failed: $($result.Output)" -Level Error
                    $success = $false
                    break
                }
                Write-Log "net$($nic.nic_id) added: $nicConfig" -Level Success
            }
            
            if (-not $success) {
                $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "NIC" }
                continue
            }
        }
        
        # Step 4: Configure cloud-init (if specified)
        if ($vm.cloud_init -and $vm.cloud_init.ip) {
            Write-Log "Configuring cloud-init for net1..." -Level Info
            
            $ip = $vm.cloud_init.ip
            $cidr = if ($vm.cloud_init.cidr) { $vm.cloud_init.cidr } else { 24 }
            $gw = $vm.cloud_init.gateway
            $dns = $vm.cloud_init.nameserver
            
            # Build ipconfig1 string for net1
            $ipconfigValue = "ip=$ip/$cidr,gw=$gw"
            
            # Build cloud-init command with proper quoting
            $cloudInitCmd = "qm set $vmid --ipconfig1 '$ipconfigValue' --nameserver $dns"
            
            $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $cloudInitCmd -DryRun:$DryRun
            
            if (-not $result.Success -and -not $DryRun) {
                Write-Log "Cloud-init configuration failed: $($result.Output)" -Level Error
                $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "CloudInit" }
                continue
            }
            Write-Log "Cloud-init configured: $ip/$cidr gw=$gw dns=$dns" -Level Success
            
            # Step 4b: Regenerate cloud-init image
            Write-Log "Regenerating cloud-init image..." -Level Info
            $regenCmd = "qm cloudinit update $vmid"
            $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $regenCmd -DryRun:$DryRun
            
            if (-not $result.Success -and -not $DryRun) {
                Write-Log "Cloud-init regeneration warning: $($result.Output)" -Level Warning
                # Don't fail on this - some Proxmox versions auto-regenerate
            }
            else {
                Write-Log "Cloud-init image regenerated." -Level Success
            }
        }
        
        # Step 5: Start VM
        $shouldStart = $vm.clone.start_after_clone -and (-not $NoStart)
        
        if ($shouldStart) {
            Write-Log "Starting VM..." -Level Info
            $startCmd = "qm start $vmid"
            $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $startCmd -DryRun:$DryRun
            
            if (-not $result.Success -and -not $DryRun) {
                Write-Log "VM start failed: $($result.Output)" -Level Error
                $results += @{ vmid = $vmid; name = $vm.name; status = "PARTIAL"; stage = "Start" }
                continue
            }
            Write-Log "VM started." -Level Success
        }
        else {
            Write-Log "VM left in stopped state." -Level Info
        }
        
        $results += @{ vmid = $vmid; name = $vm.name; status = "SUCCESS"; stage = "Complete" }
    }
    
    return $results
}

# =============================================================================
# Action: Destroy
# =============================================================================
function Invoke-DestroyAction {
    param(
        [array]$VMs,
        [object]$SSH,
        [switch]$DryRun
    )
    
    $results = @()
    $sshHost = $SSH.host
    $sshUser = $SSH.user
    
    foreach ($vm in $VMs) {
        Write-Host ""
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Red
        Write-Host "  Destroying: $($vm.name) (VM $($vm.vmid))" -ForegroundColor Red
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Red
        
        $vmid = $vm.vmid
        
        # Step 1: Stop VM (ignore errors if already stopped)
        Write-Log "Stopping VM $vmid..." -Level Info
        $stopCmd = "qm stop $vmid --skiplock 1"
        $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $stopCmd -DryRun:$DryRun
        
        if ($result.Success -or $DryRun) {
            Write-Log "VM stopped (or was already stopped)." -Level Success
        }
        
        if (-not $DryRun) { Start-Sleep -Seconds 3 }
        
        # Step 2: Destroy VM
        Write-Log "Destroying VM $vmid..." -Level Info
        $destroyCmd = "qm destroy $vmid --purge 1 --skiplock 1"
        $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $destroyCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Destroy failed: $($result.Output)" -Level Error
            $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED" }
            continue
        }
        
        Write-Log "VM $vmid destroyed." -Level Success
        $results += @{ vmid = $vmid; name = $vm.name; status = "DESTROYED" }
    }
    
    return $results
}

# =============================================================================
# Action: Start
# =============================================================================
function Invoke-StartAction {
    param(
        [array]$VMs,
        [object]$SSH,
        [switch]$DryRun
    )
    
    $results = @()
    $sshHost = $SSH.host
    $sshUser = $SSH.user
    
    foreach ($vm in $VMs) {
        $vmid = $vm.vmid
        Write-Log "Starting VM $vmid ($($vm.name))..." -Level Info
        
        $startCmd = "qm start $vmid"
        $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $startCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            # Check if already running
            if ($result.Output -match "already running") {
                Write-Log "VM $vmid is already running." -Level Warning
                $results += @{ vmid = $vmid; name = $vm.name; status = "ALREADY RUNNING" }
            }
            else {
                Write-Log "Start failed: $($result.Output)" -Level Error
                $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED" }
            }
            continue
        }
        
        Write-Log "VM $vmid started." -Level Success
        $results += @{ vmid = $vmid; name = $vm.name; status = "STARTED" }
    }
    
    return $results
}

# =============================================================================
# Action: Stop
# =============================================================================
function Invoke-StopAction {
    param(
        [array]$VMs,
        [object]$SSH,
        [switch]$DryRun
    )
    
    $results = @()
    $sshHost = $SSH.host
    $sshUser = $SSH.user
    
    foreach ($vm in $VMs) {
        $vmid = $vm.vmid
        Write-Log "Stopping VM $vmid ($($vm.name))..." -Level Info
        
        $stopCmd = "qm stop $vmid"
        $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $stopCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            # Check if already stopped
            if ($result.Output -match "not running") {
                Write-Log "VM $vmid is already stopped." -Level Warning
                $results += @{ vmid = $vmid; name = $vm.name; status = "ALREADY STOPPED" }
            }
            else {
                Write-Log "Stop failed: $($result.Output)" -Level Error
                $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED" }
            }
            continue
        }
        
        Write-Log "VM $vmid stopped." -Level Success
        $results += @{ vmid = $vmid; name = $vm.name; status = "STOPPED" }
    }
    
    return $results
}

# =============================================================================
# Action: Status
# =============================================================================
function Invoke-StatusAction {
    param(
        [array]$VMs,
        [object]$SSH,
        [switch]$DryRun
    )
    
    $results = @()
    $sshHost = $SSH.host
    $sshUser = $SSH.user
    
    Write-Host ""
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  VM STATUS REPORT                                                            |" -ForegroundColor DarkGray
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  VMID   | NAME         | STATUS      | IP ADDRESS       | NODE              |" -ForegroundColor DarkGray
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    
    foreach ($vm in $VMs) {
        $vmid = $vm.vmid
        
        # Extract IP from cloud_init config for display
        $ipAddress = "DHCP"
        if ($vm.cloud_init -and $vm.cloud_init.ip) {
            $ipAddress = $vm.cloud_init.ip
        }
        
        if ($DryRun) {
            $status = "DRY RUN"
            $statusColor = "Yellow"
        }
        else {
            $statusCmd = "qm status $vmid"
            $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $statusCmd -DryRun:$false -Silent
            
            if ($result.Success) {
                if ($result.Output -match "running") {
                    $status = "RUNNING"
                    $statusColor = "Green"
                }
                elseif ($result.Output -match "stopped") {
                    $status = "STOPPED"
                    $statusColor = "Yellow"
                }
                else {
                    $status = "UNKNOWN"
                    $statusColor = "DarkGray"
                }
            }
            else {
                $status = "NOT FOUND"
                $statusColor = "Red"
            }
        }
        
        $vmidStr = "$vmid".PadRight(7)
        $nameStr = "$($vm.name)".PadRight(12)
        $statusStr = "$status".PadRight(11)
        $ipStr = "$ipAddress".PadRight(16)
        $nodeStr = "$($vm.proxmox.node)".PadRight(17)
        
        Write-Host "|  $vmidStr| $nameStr | " -NoNewline -ForegroundColor White
        Write-Host "$statusStr" -NoNewline -ForegroundColor $statusColor
        Write-Host "| $ipStr | $nodeStr|" -ForegroundColor White
        
        $results += @{ vmid = $vmid; name = $vm.name; status = $status; ip = $ipAddress }
    }
    
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    
    return $results
}

# =============================================================================
# Main Execution
# =============================================================================

# Header
$actionColors = @{
    "Deploy"  = "Green"
    "Destroy" = "Red"
    "Start"   = "Cyan"
    "Stop"    = "Yellow"
    "Status"  = "Magenta"
}

Write-Host ""
Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
Write-Host "  CDX-E Framework - VM Lifecycle Management" -ForegroundColor $actionColors[$Action]
Write-Host "  $Script:Name v$Script:Version" -ForegroundColor $actionColors[$Action]
Write-Host "  Action: $Action" -ForegroundColor $actionColors[$Action]
Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
Write-Host ""

# Load YAML
Write-Log "Loading YAML specification: $YamlPath" -Level Info

try {
    $yamlContent = Get-Content -Path $YamlPath -Raw
    $config = ConvertFrom-Yaml $yamlContent
    Write-Log "YAML specification loaded successfully." -Level Success
}
catch {
    Write-Log "Failed to parse YAML file: $_" -Level Error
    exit 1
}

$ssh = $config.ssh
$allVMs = $config.virtual_machines
$exerciseName = $config.exercise.name

Write-Log "Exercise: $exerciseName" -Level Info
Write-Log "Total VMs defined: $($allVMs.Count)" -Level Info

# Apply filter
$selectedVMs = Get-FilteredVMs -AllVMs $allVMs -Filter $VmFilter

if ($selectedVMs.Count -eq 0) {
    Write-Log "No VMs matched filter: $VmFilter" -Level Error
    Write-Log "Available VMs:" -Level Info
    foreach ($vm in $allVMs) {
        Write-Host "  - $($vm.vmid): $($vm.name)" -ForegroundColor White
    }
    exit 1
}

if ($VmFilter -ne "all") {
    Write-Log "Filter applied: $($selectedVMs.Count) VM(s) selected" -Level Info
}

# Show target VMs
Show-VMList -VMs $selectedVMs -Title "$Action Target VMs"

# DryRun notice
if ($DryRun) {
    Write-Host ""
    Write-Log "DRY RUN MODE - Commands will be displayed but not executed." -Level Warning
}

# Confirmation
$confirmed = Request-Confirmation -Action $Action -Count $selectedVMs.Count -AutoConfirm:$Confirm -DryRun:$DryRun

if (-not $confirmed) {
    exit 0
}

Write-Host ""

# Execute action
switch ($Action) {
    "Deploy" {
        $results = Invoke-DeployAction -VMs $selectedVMs -SSH $ssh -DryRun:$DryRun -NoStart:$NoStart
    }
    "Destroy" {
        $results = Invoke-DestroyAction -VMs $selectedVMs -SSH $ssh -DryRun:$DryRun
    }
    "Start" {
        $results = Invoke-StartAction -VMs $selectedVMs -SSH $ssh -DryRun:$DryRun
    }
    "Stop" {
        $results = Invoke-StopAction -VMs $selectedVMs -SSH $ssh -DryRun:$DryRun
    }
    "Status" {
        $results = Invoke-StatusAction -VMs $selectedVMs -SSH $ssh -DryRun:$DryRun
    }
}

# Summary (except for Status which already displays results)
if ($Action -ne "Status") {
    Write-Host ""
    Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
    Write-Host "  $Action COMPLETE" -ForegroundColor $actionColors[$Action]
    Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
    Write-Host ""
    
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  RESULTS SUMMARY                                                  |" -ForegroundColor DarkGray
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
    
    $successCount = 0
    $failCount = 0
    
    foreach ($r in $results) {
        $statusColor = switch -Wildcard ($r.status) {
            "SUCCESS"    { "Green" }
            "DESTROYED"  { "Green" }
            "STARTED"    { "Green" }
            "STOPPED"    { "Green" }
            "FAILED"     { "Red" }
            "PARTIAL"    { "Yellow" }
            "ALREADY*"   { "Yellow" }
            default      { "White" }
        }
        
        if ($r.status -match "SUCCESS|DESTROYED|STARTED|STOPPED") {
            $successCount++
        }
        elseif ($r.status -eq "FAILED") {
            $failCount++
        }
        
        Write-Host "|  VM $($r.vmid): $($r.name) - " -NoNewline -ForegroundColor White
        Write-Host "$($r.status)" -ForegroundColor $statusColor
    }
    
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  Total: $($results.Count) | Success: $successCount | Failed: $failCount" -ForegroundColor White
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
}

Write-Host ""

if (-not $DryRun -and $Action -eq "Deploy") {
    Write-Log "Access Proxmox at: https://$($ssh.host):8006" -Level Info
    Write-Host ""
}

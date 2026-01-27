<#
.SYNOPSIS
    Invoke-CDX-E.ps1 - Comprehensive Proxmox VM lifecycle management for CDX-E exercises

.DESCRIPTION
    Manages the complete lifecycle of Proxmox VMs defined in a YAML specification file.
    Supports deployment, destruction, start/stop operations, and status reporting.
    
    All operations can target individual VMs, multiple VMs, or all exercise VMs.
    
    Supports cloud-init configuration for static IP addressing on deployment.
    Auto-generates VM descriptions from structured YAML fields.
    
    Template Registry: Edit $Script:Templates and $Script:TemplateNode at the top
    of this script when template IDs change. Exercise YAMLs can reference templates
    by name (e.g., "server_2012r2") which resolves to the current ID.
    
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
    .\Invoke-CDX-E.ps1 -Action Deploy -YamlPath ".\desert_citadel_vms.yaml"
    Deploys all VMs defined in the YAML file with confirmation prompt.

.EXAMPLE
    .\Invoke-CDX-E.ps1 -Action Deploy -YamlPath ".\vms.yaml" -Confirm
    Deploys VMs without confirmation prompt.

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
    Version:    3.1
    Created:    2026-01-22
    Updated:    2026-01-25
    
    Version History:
    1.0  2026-01-22  Initial release (Deploy-ProxmoxVM.ps1) - Single VM deployment
    1.1  2026-01-22  Fixed ASCII encoding, linked clone logic, SSH quoting
    1.2  2026-01-22  Multi-NIC support with optional MAC addresses
    2.0  2026-01-23  Multi-VM support, -VmFilter, -Confirm parameter
    2.1  2026-01-23  Multi-action refactor (-Action: Deploy, Destroy, Start, Stop, Status)
    2.2  2026-01-23  Cloud-init integration for static IP configuration
    2.3  2026-01-23  Cloud-init fix (qm cloudinit update), auto-generated descriptions
    2.4  2026-01-23  Markdown-formatted VM descriptions
    2.5  2026-01-23  Mixed-node deployment support (template_node vs target node)
    3.0  2026-01-25  Embedded template registry (edit $Script:Templates in script)
    3.1  2026-01-25  Idempotency checks for Deploy/Destroy actions
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module (Install-Module powershell-yaml)
        - SSH key authentication configured to Proxmox node
        - Cloud-init enabled templates with ide2 cloud-init drive
#>

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
# Script Information
# =============================================================================
$Script:Version = "3.1"
$Script:Name = "Invoke-CDX-E"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2026-01-25"

# =============================================================================
# TEMPLATE REGISTRY - Edit this section when templates change
# =============================================================================
# When you recreate a template with a new ID, update the 'id' value here.
# All exercise YAMLs referencing the template name will use the new ID.
# =============================================================================

$Script:TemplateNode = "cdx-pve-01"  # Node where all templates reside

$Script:Templates = @{
    # Windows Server Templates
    "server_2025"   = @{ id = 2001; os = "Windows Server 2025" }
    "server_2022"   = @{ id = 2002; os = "Windows Server 2022" }
    "server_2019"   = @{ id = 2003; os = "Windows Server 2019" }
    "server_2016"   = @{ id = 2004; os = "Windows Server 2016" }
    "server_2012r2" = @{ id = 2006; os = "Windows Server 2012 R2" }
    "server_2008r2" = @{ id = 2008; os = "Windows Server 2008 R2" }
    
    # Windows Desktop Templates
    "windows_11"    = @{ id = 2009; os = "Windows 11" }
    "windows_10"    = @{ id = 2010; os = "Windows 10" }
    "windows_8.1"   = @{ id = 2011; os = "Windows 8.1" }
    "windows_7"     = @{ id = 2016; os = "Windows 7" }
    
    # Linux / Network Templates
    "kali_purple"   = @{ id = 2007; os = "Kali Purple 2025.3" }
    "vyos"          = @{ id = 2017; os = "VyOS 2025" }
}

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
# VM Existence Check Function
# =============================================================================
function Get-VMExistence {
    param(
        [int]$VMID,
        [string]$ExpectedName,
        [string]$TargetNode,
        [string]$SSHUser
    )
    
    # First check if VM exists by querying its status
    $statusCmd = "qm status $VMID"
    $statusResult = Invoke-SSHCommand -TargetHost $TargetNode -User $SSHUser -Command $statusCmd -DryRun:$false -Silent
    
    if (-not $statusResult.Success) {
        # VM does not exist
        return @{
            Exists = $false
            Name = $null
            NameMatches = $false
        }
    }
    
    # VM exists - get its name from config
    $configCmd = "qm config $VMID | grep '^name:' | cut -d' ' -f2"
    $configResult = Invoke-SSHCommand -TargetHost $TargetNode -User $SSHUser -Command $configCmd -DryRun:$false -Silent
    
    $actualName = $null
    if ($configResult.Success -and $configResult.Output) {
        $actualName = ($configResult.Output -join "").Trim()
    }
    
    return @{
        Exists = $true
        Name = $actualName
        NameMatches = ($actualName -eq $ExpectedName)
    }
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
    $sshUser = $SSH.user
    $templateNode = $SSH.template_node  # Node where templates reside
    
    foreach ($vm in $VMs) {
        Write-Host ""
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  Deploying: $($vm.name) (VM $($vm.vmid))" -ForegroundColor Cyan
        Write-Host "  Template Node: $templateNode -> Target Node: $($vm.proxmox.node)" -ForegroundColor DarkCyan
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Cyan
        
        $success = $true
        $vmid = $vm.vmid
        $targetNode = $vm.proxmox.node  # Node where VM will run
        
        # Idempotency Check: Does VM already exist?
        if (-not $DryRun) {
            $existCheck = Get-VMExistence -VMID $vmid -ExpectedName $vm.name -TargetNode $targetNode -SSHUser $sshUser
            
            if ($existCheck.Exists) {
                if ($existCheck.NameMatches) {
                    Write-Log "VM $vmid ($($vm.name)) already exists - skipping creation" -Level Warning
                    $results += @{ vmid = $vmid; name = $vm.name; status = "SKIPPED"; stage = "Already Exists" }
                    continue
                }
                else {
                    Write-Log "VM ID $vmid exists but has different name: '$($existCheck.Name)' (expected: '$($vm.name)')" -Level Error
                    Write-Log "Skipping to prevent accidental overwrite - resolve ID conflict manually" -Level Error
                    $results += @{ vmid = $vmid; name = $vm.name; status = "CONFLICT"; stage = "ID Mismatch" }
                    continue
                }
            }
        }
        
        # Step 1: Clone (execute on TEMPLATE node)
        Write-Log "Cloning template $($vm.template.id) to VM $vmid (via $templateNode)..." -Level Info
        
        if ($vm.clone.type -eq "full") {
            $cloneCmd = "qm clone $($vm.template.id) $vmid --name $($vm.name) --pool $($vm.proxmox.pool) --target $targetNode --storage $($vm.clone.target_storage) --full"
        }
        else {
            $cloneCmd = "qm clone $($vm.template.id) $vmid --name $($vm.name) --pool $($vm.proxmox.pool) --target $targetNode"
        }
        
        $result = Invoke-SSHCommand -TargetHost $templateNode -User $sshUser -Command $cloneCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Clone failed: $($result.Output)" -Level Error
            $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "Clone" }
            continue
        }
        Write-Log "Clone successful." -Level Success
        
        if (-not $DryRun) { Start-Sleep -Seconds 8 }
        
        # Step 2: Configure Resources (execute on TARGET node)
        Write-Log "Configuring VM resources (via $targetNode)..." -Level Info
        
        $autoDescription = Build-VMDescription -VM $vm
        $escapedDescription = $autoDescription -replace "'", "'\''"
        $tags = $vm.proxmox.tags -join ";"
        $configCmd = "qm set $vmid --memory $($vm.resources.memory_mb) --cores $($vm.resources.cores) --sockets $($vm.resources.sockets) --description '$escapedDescription' --tags $tags"
        
        $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $configCmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Resource configuration failed: $($result.Output)" -Level Error
            $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "Configure" }
            continue
        }
        Write-Log "Resources configured." -Level Success
        Write-Log "Description: $autoDescription" -Level Info
        
        # Step 3: Add NICs (execute on TARGET node)
        if ($vm.network.additional_nics -and $vm.network.additional_nics.Count -gt 0) {
            Write-Log "Adding $($vm.network.additional_nics.Count) network interface(s)..." -Level Info
            
            foreach ($nic in $vm.network.additional_nics) {
                $nicConfig = Build-NicConfigString -NicConfig $nic
                $nicCmd = "qm set $vmid --net$($nic.nic_id) $nicConfig"
                
                $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $nicCmd -DryRun:$DryRun
                
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
        
        # Step 4: Configure cloud-init (execute on TARGET node)
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
            
            $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $cloudInitCmd -DryRun:$DryRun
            
            if (-not $result.Success -and -not $DryRun) {
                Write-Log "Cloud-init configuration failed: $($result.Output)" -Level Error
                $results += @{ vmid = $vmid; name = $vm.name; status = "FAILED"; stage = "CloudInit" }
                continue
            }
            Write-Log "Cloud-init configured: $ip/$cidr gw=$gw dns=$dns" -Level Success
            
            # Step 4b: Regenerate cloud-init image
            Write-Log "Regenerating cloud-init image..." -Level Info
            $regenCmd = "qm cloudinit update $vmid"
            $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $regenCmd -DryRun:$DryRun
            
            if (-not $result.Success -and -not $DryRun) {
                Write-Log "Cloud-init regeneration warning: $($result.Output)" -Level Warning
                # Don't fail on this - some Proxmox versions auto-regenerate
            }
            else {
                Write-Log "Cloud-init image regenerated." -Level Success
            }
        }
        
        # Step 5: Start VM (execute on TARGET node)
        $shouldStart = $vm.clone.start_after_clone -and (-not $NoStart)
        
        if ($shouldStart) {
            Write-Log "Starting VM..." -Level Info
            $startCmd = "qm start $vmid"
            $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $startCmd -DryRun:$DryRun
            
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
    $sshUser = $SSH.user
    
    foreach ($vm in $VMs) {
        Write-Host ""
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Red
        Write-Host "  Destroying: $($vm.name) (VM $($vm.vmid)) on $($vm.proxmox.node)" -ForegroundColor Red
        Write-Host "-----------------------------------------------------------------------" -ForegroundColor Red
        
        $vmid = $vm.vmid
        $targetNode = $vm.proxmox.node  # Execute on VM's host node
        
        # Idempotency Check: Does VM exist?
        if (-not $DryRun) {
            $existCheck = Get-VMExistence -VMID $vmid -ExpectedName $vm.name -TargetNode $targetNode -SSHUser $sshUser
            
            if (-not $existCheck.Exists) {
                Write-Log "VM $vmid does not exist - skipping destruction" -Level Warning
                $results += @{ vmid = $vmid; name = $vm.name; status = "SKIPPED"; stage = "Not Found" }
                continue
            }
            
            if (-not $existCheck.NameMatches) {
                Write-Log "VM ID $vmid exists but has different name: '$($existCheck.Name)' (expected: '$($vm.name)')" -Level Error
                Write-Log "Skipping destruction for safety - verify correct VM before manual removal" -Level Error
                $results += @{ vmid = $vmid; name = $vm.name; status = "SKIPPED"; stage = "Name Mismatch" }
                continue
            }
        }
        
        # Step 1: Stop VM (ignore errors if already stopped)
        Write-Log "Stopping VM $vmid (via $targetNode)..." -Level Info
        $stopCmd = "qm stop $vmid --skiplock 1"
        $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $stopCmd -DryRun:$DryRun
        
        if ($result.Success -or $DryRun) {
            Write-Log "VM stopped (or was already stopped)." -Level Success
        }
        
        if (-not $DryRun) { Start-Sleep -Seconds 3 }
        
        # Step 2: Destroy VM
        Write-Log "Destroying VM $vmid..." -Level Info
        $destroyCmd = "qm destroy $vmid --purge 1 --skiplock 1"
        $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $destroyCmd -DryRun:$DryRun
        
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
    $sshUser = $SSH.user
    
    foreach ($vm in $VMs) {
        $vmid = $vm.vmid
        $targetNode = $vm.proxmox.node  # Execute on VM's host node
        Write-Log "Starting VM $vmid ($($vm.name)) on $targetNode..." -Level Info
        
        $startCmd = "qm start $vmid"
        $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $startCmd -DryRun:$DryRun
        
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
    $sshUser = $SSH.user
    
    foreach ($vm in $VMs) {
        $vmid = $vm.vmid
        $targetNode = $vm.proxmox.node  # Execute on VM's host node
        Write-Log "Stopping VM $vmid ($($vm.name)) on $targetNode..." -Level Info
        
        $stopCmd = "qm stop $vmid"
        $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $stopCmd -DryRun:$DryRun
        
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
    $sshUser = $SSH.user
    
    Write-Host ""
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  VM STATUS REPORT                                                            |" -ForegroundColor DarkGray
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "|  VMID   | NAME         | STATUS      | IP ADDRESS       | NODE              |" -ForegroundColor DarkGray
    Write-Host "+------------------------------------------------------------------------------+" -ForegroundColor DarkGray
    
    foreach ($vm in $VMs) {
        $vmid = $vm.vmid
        $targetNode = $vm.proxmox.node  # Query on VM's host node
        
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
            $result = Invoke-SSHCommand -TargetHost $targetNode -User $sshUser -Command $statusCmd -DryRun:$false -Silent
            
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

# =============================================================================
# =============================================================================
# Resolve Templates for Each VM
# =============================================================================
$ssh = $config.ssh
$allVMs = $config.virtual_machines
$exerciseName = $config.exercise.name

# Set template_node from script variable (overrides YAML if present)
if ($Script:TemplateNode) {
    $ssh.template_node = $Script:TemplateNode
}

# Process each VM to resolve template references
foreach ($vm in $allVMs) {
    # Check if template is a string (name reference) or object (direct config)
    if ($vm.template -is [string]) {
        # Template specified by name - resolve from embedded registry
        $templateName = $vm.template
        
        if ($Script:Templates.ContainsKey($templateName)) {
            $templateInfo = $Script:Templates[$templateName]
            
            # Create template object with resolved values
            $vm.template = @{
                id = $templateInfo.id
                os = $templateInfo.os
                name = $templateName
            }
            
            Write-Log "Resolved template '$templateName' -> ID $($templateInfo.id) ($($templateInfo.os))" -Level Info
        }
        else {
            Write-Log "Template '$templateName' not found in script registry!" -Level Error
            Write-Log "Available templates: $($Script:Templates.Keys -join ', ')" -Level Info
            exit 1
        }
    }
    elseif ($vm.template.id) {
        # Template specified directly with id/os - use as-is (backwards compatible)
        Write-Log "Using direct template ID $($vm.template.id) for $($vm.name)" -Level Info
    }
    else {
        Write-Log "VM $($vm.name): Invalid template specification (no id found)" -Level Error
        exit 1
    }
}

Write-Log "Template node: $($ssh.template_node)" -Level Info
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
    # Get unique target nodes from deployed VMs (handle hashtable structure)
    $targetNodes = $selectedVMs | ForEach-Object { $_.proxmox.node } | Select-Object -Unique
    Write-Log "Access Proxmox cluster:" -Level Info
    foreach ($node in $targetNodes) {
        Write-Host "       https://${node}:8006" -ForegroundColor Cyan
    }
    Write-Host ""
}
<#
.SYNOPSIS
    Deploy-ProxmoxVM.ps1 - Clone Proxmox VM from YAML specification via SSH

.DESCRIPTION
    Reads a YAML specification file and executes Proxmox qm commands via SSH
    to clone a template, configure resources, and optionally start the VM.
    
    Part of the CDX-E Framework for Operation OBSIDIAN DAGGER.

.PARAMETER YamlPath
    Path to the YAML specification file containing VM configuration.

.PARAMETER DryRun
    If specified, displays the commands that would be executed without running them.

.EXAMPLE
    .\Deploy-ProxmoxVM.ps1 -YamlPath ".\obsidian_dagger_test_vm.yaml"
    
.EXAMPLE
    .\Deploy-ProxmoxVM.ps1 -YamlPath ".\obsidian_dagger_test_vm.yaml" -DryRun

.NOTES
    Script:     Deploy-ProxmoxVM.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    1.1
    Created:    2025-01-22
    Updated:    2025-01-22
    
    Version History:
    1.0  2025-01-22  Initial release - Single VM deployment from YAML
    1.1  2025-01-22  Fixed ASCII encoding, linked clone logic, SSH quoting
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module (Install-Module powershell-yaml)
        - SSH key authentication configured to Proxmox node
#>

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "1.1"
$Script:Name = "Deploy-ProxmoxVM"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2025-01-22"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$YamlPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
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
# Functions
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
        [switch]$DryRun
    )
    
    $sshCommand = "ssh -o StrictHostKeyChecking=accept-new $User@$TargetHost `"$Command`""
    
    if ($DryRun) {
        Write-Log "DRY RUN: $sshCommand" -Level Info
        return @{ Success = $true; Output = "DRY RUN - Command not executed" }
    }
    
    Write-Log "Executing: $Command" -Level Info
    
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

# =============================================================================
# Main Execution
# =============================================================================

Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Magenta
Write-Host "  CDX-E Framework - Proxmox VM Deployment Script" -ForegroundColor Magenta
Write-Host "  $Script:Name v$Script:Version" -ForegroundColor Magenta
Write-Host "  Operation OBSIDIAN DAGGER" -ForegroundColor Magenta
Write-Host "=======================================================================" -ForegroundColor Magenta
Write-Host ""

# --- Load YAML Configuration ---
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

# --- Extract Configuration Values ---
$vm = $config.vm_specification
$ssh = $config.ssh

$templateId   = $vm.template.id
$newVmId      = $vm.vmid
$vmName       = $vm.name
$description  = $vm.description
$targetNode   = $vm.proxmox.node
$pool         = $vm.proxmox.pool
$tags         = $vm.proxmox.tags -join ";"
$memoryMB     = $vm.resources.memory_mb
$cores        = $vm.resources.cores
$sockets      = if ($vm.resources.sockets) { $vm.resources.sockets } else { 1 }
$targetStorage = $vm.clone.target_storage
$startAfter   = $vm.clone.start_after_clone
$cloneType    = $vm.clone.type

# Secondary NIC configuration
$net1Bridge   = $vm.network.net1.bridge
$net1Tag      = $vm.network.net1.tag
$net1Model    = $vm.network.net1.model
$net1Firewall = if ($vm.network.net1.firewall) { 1 } else { 0 }

$sshHost = $ssh.host
$sshUser = $ssh.user

# --- Display Configuration Summary ---
Write-Host ""
Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "|  DEPLOYMENT CONFIGURATION                                         |" -ForegroundColor DarkGray
Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "|  Template ID:      $templateId" -ForegroundColor White
Write-Host "|  New VM ID:        $newVmId" -ForegroundColor White
Write-Host "|  VM Name:          $vmName" -ForegroundColor White
Write-Host "|  Description:      $description" -ForegroundColor White
Write-Host "|  Target Node:      $targetNode" -ForegroundColor White
Write-Host "|  Storage:          $targetStorage" -ForegroundColor White
Write-Host "|  Pool:             $pool" -ForegroundColor White
Write-Host "|  Tags:             $tags" -ForegroundColor White
Write-Host "|  Memory:           $memoryMB MB" -ForegroundColor White
Write-Host "|  CPUs:             $cores cores x $sockets socket(s)" -ForegroundColor White
Write-Host "|  Secondary NIC:    $net1Model / $net1Bridge / VLAN $net1Tag" -ForegroundColor White
Write-Host "|  Start After:      $startAfter" -ForegroundColor White
Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Log "DRY RUN MODE - Commands will be displayed but not executed." -Level Warning
    Write-Host ""
}

# --- Confirm Deployment ---
if (-not $DryRun) {
    $confirmInput = Read-Host "Proceed with deployment? (Y/N)"
    if ($confirmInput -notmatch "^[Yy]") {
        Write-Log "Deployment cancelled by user." -Level Warning
        exit 0
    }
    Write-Host ""
}

# =============================================================================
# Step 1: Clone the Template
# =============================================================================
Write-Log "STEP 1: Cloning template $templateId to VM $newVmId ($cloneType clone)..." -Level Info

# Build the clone command - linked clones cannot specify storage, full clones can
if ($cloneType -eq "full") {
    $cloneCmd = "qm clone $templateId $newVmId --name $vmName --pool $pool --target $targetNode --storage $targetStorage --full"
}
else {
    # Linked clone - storage parameter not allowed, uses template storage
    $cloneCmd = "qm clone $templateId $newVmId --name $vmName --pool $pool --target $targetNode"
}

$result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $cloneCmd -DryRun:$DryRun

if (-not $result.Success -and -not $DryRun) {
    Write-Log "Clone operation failed: $($result.Output)" -Level Error
    exit 1
}
Write-Log "Clone command issued successfully." -Level Success

if (-not $DryRun) {
    Write-Log "Waiting for clone operation to complete..." -Level Info
    Start-Sleep -Seconds 10
}

# =============================================================================
# Step 2: Configure VM Resources
# =============================================================================
Write-Log "STEP 2: Configuring VM resources..." -Level Info

# Escape description for SSH passthrough using single quotes
$escapedDescription = $description -replace "'", "'\''"
$configCmd = "qm set $newVmId --memory $memoryMB --cores $cores --sockets $sockets --description '$escapedDescription' --tags $tags"

$result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $configCmd -DryRun:$DryRun

if (-not $result.Success -and -not $DryRun) {
    Write-Log "Resource configuration failed: $($result.Output)" -Level Error
    exit 1
}
Write-Log "VM resources configured successfully." -Level Success

# =============================================================================
# Step 3: Add Secondary NIC
# =============================================================================
Write-Log "STEP 3: Adding secondary NIC..." -Level Info

$net1Config = "$net1Model,bridge=$net1Bridge,firewall=$net1Firewall,tag=$net1Tag"
$nicCmd = "qm set $newVmId --net1 $net1Config"

$result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $nicCmd -DryRun:$DryRun

if (-not $result.Success -and -not $DryRun) {
    Write-Log "NIC configuration failed: $($result.Output)" -Level Error
    exit 1
}
Write-Log "Secondary NIC added: $net1Config" -Level Success

# =============================================================================
# Step 4: Start VM
# =============================================================================
if ($startAfter) {
    Write-Log "STEP 4: Starting VM $newVmId..." -Level Info
    
    $startCmd = "qm start $newVmId"
    $result = Invoke-SSHCommand -TargetHost $sshHost -User $sshUser -Command $startCmd -DryRun:$DryRun
    
    if (-not $result.Success -and -not $DryRun) {
        Write-Log "VM start failed: $($result.Output)" -Level Error
        exit 1
    }
    Write-Log "VM started successfully." -Level Success
}
else {
    Write-Log "STEP 4: Skipping VM start (start_after_clone = false)" -Level Info
}

# =============================================================================
# Deployment Complete
# =============================================================================
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Green
Write-Host ""

if (-not $DryRun) {
    Write-Log "VM $newVmId ($vmName) deployed to pool $pool" -Level Success
    Write-Log "Access via: https://${sshHost}:8006/#v1:0:=qemu%2F$newVmId" -Level Info
}
else {
    Write-Log "DRY RUN complete. Review commands above before executing." -Level Info
}

Write-Host ""

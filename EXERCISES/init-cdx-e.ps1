<#
.SYNOPSIS
    Init-CDX-E.ps1 - Exercise lifecycle orchestration for CDX-E Framework

.DESCRIPTION
    Orchestrates the complete setup and teardown of CDX-E exercises including:
    - Host network configuration across all Proxmox nodes
    - Resource pool creation/deletion
    - VM deployment/destruction via Invoke-CDX-E.ps1
    
    Setup Flow:
    1. Configure networking on all hosts (exercise.sh <exercise_name>)
    2. Create resource pool (EX_<EXERCISE_NAME>)
    3. Deploy VMs via Invoke-CDX-E.ps1
    
    Teardown Flow:
    1. Destroy VMs via Invoke-CDX-E.ps1 -Action Destroy
    2. Delete resource pool
    3. Revert networking on all hosts (exercise.sh revert)

.PARAMETER Action
    The operation to perform:
    - Deploy  : Full exercise setup (network, pool, VMs)
    - Destroy : Full exercise teardown (VMs, pool, network)

.PARAMETER YamlPath
    Path to the exercise YAML specification file.

.PARAMETER Confirm
    Bypasses confirmation prompts (passed to Invoke-CDX-E.ps1).

.PARAMETER NoStart
    Leaves VMs stopped after deployment (passed to Invoke-CDX-E.ps1).

.PARAMETER DryRun
    Shows commands without executing them.

.EXAMPLE
    .\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\desert_citadel_vms.yaml"
    Full exercise deployment with confirmation prompts.

.EXAMPLE
    .\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\desert_citadel_vms.yaml" -Confirm -NoStart
    Deploy exercise without prompts, leave VMs stopped.

.EXAMPLE
    .\Init-CDX-E.ps1 -Action Destroy -YamlPath ".\desert_citadel_vms.yaml" -Confirm
    Full exercise teardown without prompts.

.EXAMPLE
    .\Init-CDX-E.ps1 -Action Deploy -YamlPath ".\desert_citadel_vms.yaml" -DryRun
    Preview deployment commands without executing.

.NOTES
    Script:     Init-CDX-E.ps1
    Author:     CDX-E Framework / J.A.R.V.I.S.
    Version:    1.0
    Created:    2026-01-25
    
    Requires:   
        - PowerShell 5.1+ or PowerShell Core
        - powershell-yaml module
        - SSH key authentication to all Proxmox nodes
        - exercise.sh script on each Proxmox host
        - Invoke-CDX-E.ps1 in same directory
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Deploy", "Destroy")]
    [string]$Action,
    
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$YamlPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Confirm,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoStart,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# =============================================================================
# Script Information
# =============================================================================
$Script:Version = "1.0"
$Script:Name = "Init-CDX-E"
$Script:Author = "CDX-E Framework / J.A.R.V.I.S."
$Script:Updated = "2026-01-25"

# =============================================================================
# Configuration
# =============================================================================
$Script:ProxmoxHosts = @("cdx-pve-01", "cdx-pve-02", "cdx-pve-03")
$Script:SSHUser = "root"
$Script:ScriptDir = if ($PSCommandPath) { 
    Split-Path -Parent $PSCommandPath 
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $PWD.Path
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
# Functions
# =============================================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Header")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{
        "Info"    = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Header"  = "Magenta"
    }
    $prefixes = @{
        "Info"    = "[*]"
        "Success" = "[+]"
        "Warning" = "[!]"
        "Error"   = "[-]"
        "Header"  = "[#]"
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
    
    $sshCommand = "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 $User@$TargetHost `"$Command`""
    
    if ($DryRun) {
        Write-Log "DRY RUN [$TargetHost]: $Command" -Level Info
        return @{ Success = $true; Output = "DRY RUN - Command not executed" }
    }
    
    Write-Log "Executing on $TargetHost : $Command" -Level Info
    
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

function ConvertTo-TitleCase {
    param([string]$Text)
    
    # Convert DESERT_CITADEL to Desert Citadel
    $words = $Text.ToLower() -replace "_", " "
    return (Get-Culture).TextInfo.ToTitleCase($words)
}

function Get-ExerciseInfo {
    param([object]$Config)
    
    $exerciseName = $Config.exercise.name  # e.g., "DESERT_CITADEL"
    
    return @{
        Name        = $exerciseName
        NameLower   = $exerciseName.ToLower()  # desert_citadel (for exercise.sh)
        PoolName    = "EX_$exerciseName"       # EX_DESERT_CITADEL
        PoolComment = "Operation $(ConvertTo-TitleCase $exerciseName)"  # Operation Desert Citadel
        Description = $Config.exercise.description
    }
}

# =============================================================================
# Phase Functions
# =============================================================================
function Invoke-NetworkSetup {
    param(
        [string]$ExerciseName,
        [switch]$DryRun
    )
    
    Write-Log "PHASE 1: Configuring host networking for '$ExerciseName'" -Level Header
    Write-Host ""
    
    foreach ($node in $Script:ProxmoxHosts) {
        $cmd = "./exercise.sh $ExerciseName"
        $result = Invoke-SSHCommand -TargetHost $node -User $Script:SSHUser -Command $cmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Network setup failed on $node : $($result.Output)" -Level Error
            Write-Log "Aborting deployment." -Level Error
            return $false
        }
        
        Write-Log "Network configured on $node" -Level Success
    }
    
    Write-Host ""
    return $true
}

function Invoke-NetworkRevert {
    param(
        [switch]$DryRun
    )
    
    Write-Log "PHASE 3: Reverting host networking" -Level Header
    Write-Host ""
    
    $allSuccess = $true
    
    foreach ($node in $Script:ProxmoxHosts) {
        $cmd = "./exercise.sh revert"
        $result = Invoke-SSHCommand -TargetHost $node -User $Script:SSHUser -Command $cmd -DryRun:$DryRun
        
        if (-not $result.Success -and -not $DryRun) {
            Write-Log "Network revert failed on $node : $($result.Output)" -Level Warning
            $allSuccess = $false
        }
        else {
            Write-Log "Network reverted on $node" -Level Success
        }
    }
    
    Write-Host ""
    return $allSuccess
}

function Invoke-PoolCreate {
    param(
        [string]$PoolName,
        [string]$PoolComment,
        [switch]$DryRun
    )
    
    Write-Log "PHASE 2: Creating resource pool '$PoolName'" -Level Header
    Write-Host ""
    
    # Use first host to create pool (cluster-wide operation)
    $targetHost = $Script:ProxmoxHosts[0]
    
    # Escape the comment for shell
    $escapedComment = $PoolComment -replace "'", "'\''"
    $cmd = "pvesh create /pools --poolid $PoolName --comment '$escapedComment'"
    
    $result = Invoke-SSHCommand -TargetHost $targetHost -User $Script:SSHUser -Command $cmd -DryRun:$DryRun
    
    if (-not $result.Success -and -not $DryRun) {
        # Check if pool already exists
        if ($result.Output -match "already exists") {
            Write-Log "Pool '$PoolName' already exists - continuing" -Level Warning
            return $true
        }
        Write-Log "Pool creation failed: $($result.Output)" -Level Error
        return $false
    }
    
    Write-Log "Pool '$PoolName' created with comment: $PoolComment" -Level Success
    Write-Host ""
    return $true
}

function Invoke-PoolDelete {
    param(
        [string]$PoolName,
        [switch]$DryRun
    )
    
    Write-Log "PHASE 2: Deleting resource pool '$PoolName'" -Level Header
    Write-Host ""
    
    # Use first host to delete pool (cluster-wide operation)
    $targetHost = $Script:ProxmoxHosts[0]
    $cmd = "pvesh delete /pools/$PoolName"
    
    $result = Invoke-SSHCommand -TargetHost $targetHost -User $Script:SSHUser -Command $cmd -DryRun:$DryRun
    
    if (-not $result.Success -and -not $DryRun) {
        # Check if pool doesn't exist
        if ($result.Output -match "does not exist|no such pool") {
            Write-Log "Pool '$PoolName' does not exist - continuing" -Level Warning
            return $true
        }
        Write-Log "Pool deletion failed: $($result.Output)" -Level Error
        return $false
    }
    
    Write-Log "Pool '$PoolName' deleted" -Level Success
    Write-Host ""
    return $true
}

function Invoke-VMDeployment {
    param(
        [string]$YamlPath,
        [switch]$Confirm,
        [switch]$NoStart,
        [switch]$DryRun
    )
    
    Write-Log "PHASE 3: Deploying VMs" -Level Header
    Write-Host ""
    
    # Build Invoke-CDX-E.ps1 path
    $invokeScript = Join-Path $Script:ScriptDir "Invoke-CDX-E.ps1"
    
    if (-not (Test-Path $invokeScript)) {
        Write-Log "Invoke-CDX-E.ps1 not found at: $invokeScript" -Level Error
        return $false
    }
    
    # Build arguments hashtable for splatting
    $invokeParams = @{
        Action   = "Deploy"
        YamlPath = $YamlPath
    }
    
    if ($Confirm) { $invokeParams.Confirm = $true }
    if ($NoStart) { $invokeParams.NoStart = $true }
    if ($DryRun) { $invokeParams.DryRun = $true }
    
    Write-Log "Executing: Invoke-CDX-E.ps1 -Action Deploy -YamlPath $YamlPath" -Level Info
    Write-Host ""
    
    # Execute Invoke-CDX-E.ps1
    & $invokeScript @invokeParams
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -ne 0 -and -not $DryRun) {
        Write-Log "VM deployment failed with exit code: $exitCode" -Level Error
        return $false
    }
    
    return $true
}

function Invoke-VMDestruction {
    param(
        [string]$YamlPath,
        [switch]$Confirm,
        [switch]$DryRun
    )
    
    Write-Log "PHASE 1: Destroying VMs" -Level Header
    Write-Host ""
    
    # Build Invoke-CDX-E.ps1 path
    $invokeScript = Join-Path $Script:ScriptDir "Invoke-CDX-E.ps1"
    
    if (-not (Test-Path $invokeScript)) {
        Write-Log "Invoke-CDX-E.ps1 not found at: $invokeScript" -Level Error
        return $false
    }
    
    # Build arguments hashtable for splatting
    $invokeParams = @{
        Action   = "Destroy"
        YamlPath = $YamlPath
    }
    
    if ($Confirm) { $invokeParams.Confirm = $true }
    if ($DryRun) { $invokeParams.DryRun = $true }
    
    Write-Log "Executing: Invoke-CDX-E.ps1 -Action Destroy -YamlPath $YamlPath" -Level Info
    Write-Host ""
    
    # Execute Invoke-CDX-E.ps1
    & $invokeScript @invokeParams
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -ne 0 -and -not $DryRun) {
        Write-Log "VM destruction failed with exit code: $exitCode" -Level Warning
        # Continue with teardown even if VM destruction has issues
    }
    
    return $true
}

# =============================================================================
# Main Execution
# =============================================================================

# Action colors
$actionColors = @{
    "Deploy"  = "Green"
    "Destroy" = "Red"
}

Write-Host ""
Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
Write-Host "  CDX-E Framework - Exercise Lifecycle Management" -ForegroundColor $actionColors[$Action]
Write-Host "  $Script:Name v$Script:Version" -ForegroundColor $actionColors[$Action]
Write-Host "  Action: $Action" -ForegroundColor $actionColors[$Action]
Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
Write-Host ""

# Load YAML
Write-Log "Loading exercise specification: $YamlPath" -Level Info

try {
    $yamlContent = Get-Content -Path $YamlPath -Raw
    $config = ConvertFrom-Yaml $yamlContent
    Write-Log "YAML specification loaded successfully." -Level Success
}
catch {
    Write-Log "Failed to parse YAML file: $_" -Level Error
    exit 1
}

# Extract exercise info
$exercise = Get-ExerciseInfo -Config $config

Write-Host ""
Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "|  EXERCISE INFORMATION                                             |" -ForegroundColor DarkGray
Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "|  Name:        $($exercise.Name)" -ForegroundColor White
Write-Host "|  Pool:        $($exercise.PoolName)" -ForegroundColor White
Write-Host "|  Comment:     $($exercise.PoolComment)" -ForegroundColor White
Write-Host "|  Description: $($exercise.Description)" -ForegroundColor White
Write-Host "|  VM Count:    $($config.virtual_machines.Count)" -ForegroundColor White
Write-Host "+-------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Log "DRY RUN MODE - Commands will be displayed but not executed." -Level Warning
    Write-Host ""
}

# Confirmation
if (-not $Confirm -and -not $DryRun) {
    $actionVerb = if ($Action -eq "Deploy") { "deploy" } else { "tear down" }
    $prompt = "Proceed to $actionVerb exercise '$($exercise.Name)'? (Y/N)"
    $response = Read-Host $prompt
    
    if ($response -notmatch "^[Yy]") {
        Write-Log "Operation cancelled by user." -Level Warning
        exit 0
    }
    Write-Host ""
}

# Execute based on action
switch ($Action) {
    "Deploy" {
        # Phase 1: Network Setup
        $success = Invoke-NetworkSetup -ExerciseName $exercise.NameLower -DryRun:$DryRun
        if (-not $success) { exit 1 }
        
        # Phase 2: Pool Creation
        $success = Invoke-PoolCreate -PoolName $exercise.PoolName -PoolComment $exercise.PoolComment -DryRun:$DryRun
        if (-not $success) { exit 1 }
        
        # Phase 3: VM Deployment
        $success = Invoke-VMDeployment -YamlPath $YamlPath -Confirm:$Confirm -NoStart:$NoStart -DryRun:$DryRun
        if (-not $success) { exit 1 }
    }
    
    "Destroy" {
        # Phase 1: VM Destruction
        $success = Invoke-VMDestruction -YamlPath $YamlPath -Confirm:$Confirm -DryRun:$DryRun
        # Continue even if VM destruction has issues
        
        # Phase 2: Pool Deletion
        $success = Invoke-PoolDelete -PoolName $exercise.PoolName -DryRun:$DryRun
        # Continue even if pool deletion has issues
        
        # Phase 3: Network Revert
        $success = Invoke-NetworkRevert -DryRun:$DryRun
    }
}

# Final summary
Write-Host ""
Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
if ($Action -eq "Deploy") {
    Write-Host "  EXERCISE DEPLOYMENT COMPLETE" -ForegroundColor $actionColors[$Action]
}
else {
    Write-Host "  EXERCISE TEARDOWN COMPLETE" -ForegroundColor $actionColors[$Action]
}
Write-Host "  Exercise: $($exercise.Name)" -ForegroundColor $actionColors[$Action]
Write-Host "=======================================================================" -ForegroundColor $actionColors[$Action]
Write-Host ""
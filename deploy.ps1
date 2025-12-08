<#
.SYNOPSIS
    Master deployment orchestration for CHILLED_ROCKET exercise environment

.DESCRIPTION
    Orchestrates complete deployment of Stark Industries global enterprise from
    Management Workstation through all phases:
    - Phase 1: Forest Root DC deployment and forest creation
    - Phase 2: User account deployment (immediate post-forest)
    - Phase 3: Group Policy deployment with branding (immediate post-forest)
    - Phase 4: Site DC deployment and promotion
    - Phase 5: Member server deployment and domain join
    - Phase 6: DHCP scope deployment
    - Phase 7: Workstation deployment and domain join
    - Phase 8: Environment validation

    Key Features:
    - QEMU Guest Agent monitoring for VM availability detection
    - Automatic Windows Firewall ICMP enablement on deployed VMs
    - Dynamic resource allocation for STK-DC-01 during forest creation
    - Intelligent wait logic replacing static timeouts
    - Corporate branding deployment (logon screens, wallpapers)

.PARAMETER ProxmoxHost
    Proxmox cluster node IP (any node)

.PARAMETER ProxmoxPassword
    Password for Proxmox root@pam user

.PARAMETER ExercisePath
    Path to CHILLED_ROCKET exercise folder

.PARAMETER SkipPhases
    Array of phase numbers to skip (e.g., @(1,2) to skip phases 1 and 2)

.PARAMETER PauseAfterPhase
    Pause for user confirmation after each phase

.PARAMETER AgentTimeoutSeconds
    Maximum time to wait for QEMU guest agent response (default: 300)

.PARAMETER AgentPollIntervalSeconds
    Interval between guest agent polls (default: 10)

.EXAMPLE
    .\deploy.ps1 -ProxmoxPassword "P@ssw0rd"
    # Prompts for DSRM/Domain Admin/Local Admin passwords at startup

.EXAMPLE
    # Skip forest creation if already exists, start from Phase 4
    .\deploy.ps1 -SkipPhases @(1,2,3) -ProxmoxPassword "P@ssw0rd"

.NOTES
    Author: CDX-E Team
    Version: 2.1 - Branding Enhancement
    Requires: PowerShell 5.1+, Network access to Proxmox cluster
    Duration: ~8 hours for complete deployment
    
    Domain Configuration (Hardcoded):
    - FQDN: stark-industries.midgard.mrvl
    - NetBIOS: STARK
#>

[CmdletBinding()]
param(
    [string]$ProxmoxHost = "cdx-pve-01",
    
    [Parameter(Mandatory)]
    [string]$ProxmoxPassword,
    
    [string]$ExercisePath = ".\EXERCISES\CHILLED_ROCKET",
    
    [int[]]$SkipPhases = @(),
    
    [switch]$PauseAfterPhase,
    
    [switch]$WhatIf,
    
    [int]$AgentTimeoutSeconds = 300,
    
    [int]$AgentPollIntervalSeconds = 10
)

# ============================================================================
# CONSTANTS - DOMAIN CONFIGURATION (NO USER PROMPTS)
# ============================================================================

$script:DomainFQDN = "stark-industries.midgard.mrvl"
$script:DomainNetBIOS = "STARK"
$script:ForestRootDC = @{
    Name = "STK-DC-01"
    VMID = 5001
    IP = "66.218.180.40"
    Node = "cdx-pve-01"
    NormalMemory = 8192      # 8 GB normal operation
    BoostMemory = 16384      # 16 GB during forest creation
}

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Stop"
$script:DeploymentLog = @()
$script:StartTime = Get-Date
$script:ProxmoxTicket = $null
$script:ProxmoxCSRF = $null

# ============================================================================
# CREDENTIAL COLLECTION (UPFRONT)
# ============================================================================

Write-Host @"

   _____ _    _ _____ _      _      ______ _____  
  / ____| |  | |_   _| |    | |    |  ____|  __ \ 
 | |    | |__| | | | | |    | |    | |__  | |  | |
 | |    |  __  | | | | |    | |    |  __| | |  | |
 | |____| |  | |_| |_| |____| |____| |____| |__| |
  \_____|_|  |_|_____|______|______|______|_____/ 
                                                   
  _____   ____   _____ _  ________ _______ 
 |  __ \ / __ \ / ____| |/ /  ____|__   __|
 | |__) | |  | | |    | ' /| |__     | |   
 |  _  /| |  | | |    |  < |  __|    | |   
 | | \ \| |__| | |____| . \| |____   | |   
 |_|  \_\\____/ \_____|_|\_\______|  |_|   
                                            
    Stark Industries Global Enterprise Deployment
    Domain: $script:DomainFQDN
    NetBIOS: $script:DomainNetBIOS
    Exercise: CHILLED_ROCKET

"@ -ForegroundColor Cyan

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "   CREDENTIAL COLLECTION" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Please provide the following passwords for deployment:" -ForegroundColor White
Write-Host "  - These will be used for DSRM, Domain Administrator, and" -ForegroundColor DarkGray
Write-Host "    local cdxadmin accounts across all deployed systems." -ForegroundColor DarkGray
Write-Host ""

# Collect all passwords upfront
$script:DsrmSecurePassword = Read-Host "Enter DSRM (Directory Services Restore Mode) password" -AsSecureString
$script:DomainAdminSecurePassword = Read-Host "Enter Domain Administrator password" -AsSecureString
$script:LocalAdminSecurePassword = Read-Host "Enter Local Administrator (cdxadmin) password" -AsSecureString

# Convert to plain text for certain operations (stored securely in memory)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:DomainAdminSecurePassword)
$script:DomainAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:LocalAdminSecurePassword)
$script:LocalAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Build credential objects
$script:LocalAdminCred = New-Object System.Management.Automation.PSCredential (
    "Administrator",
    $script:LocalAdminSecurePassword
)

$script:CdxAdminCred = New-Object System.Management.Automation.PSCredential (
    "cdxadmin",
    $script:LocalAdminSecurePassword
)

$script:DomainAdminCred = New-Object System.Management.Automation.PSCredential (
    "$script:DomainNetBIOS\Administrator",
    $script:DomainAdminSecurePassword
)

Write-Host ""
Write-Host "[OK] Credentials collected and secured" -ForegroundColor Green
Write-Host ""

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-DeploymentLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $script:DeploymentLog += $logEntry
    
    switch ($Level) {
        "Info"    { Write-Host $Message -ForegroundColor Cyan }
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Error"   { Write-Host $Message -ForegroundColor Red }
    }
}

function Write-PhaseHeader {
    param(
        [Parameter(Mandatory)]
        [int]$PhaseNumber,
        
        [Parameter(Mandatory)]
        [string]$PhaseName,
        
        [string]$EstimatedDuration
    )
    
    Write-Host "`n" -NoNewline
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   PHASE $PhaseNumber: $PhaseName" -ForegroundColor Cyan
    if ($EstimatedDuration) {
        Write-Host "   Estimated Duration: $EstimatedDuration" -ForegroundColor DarkCyan
    }
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-PhaseSkipped {
    param([int]$PhaseNumber)
    
    if ($SkipPhases -contains $PhaseNumber) {
        Write-DeploymentLog "Phase $PhaseNumber skipped by user request" -Level Warning
        return $true
    }
    return $false
}

function Wait-UserConfirmation {
    param([string]$Message = "Press Enter to continue to next phase, or Ctrl+C to abort")
    
    if ($PauseAfterPhase) {
        Write-Host "`n$Message" -ForegroundColor Yellow
        Read-Host
    }
}

function Save-DeploymentLog {
    $logPath = Join-Path $ExercisePath "deployment_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $script:DeploymentLog | Out-File -FilePath $logPath -Encoding UTF8
    Write-DeploymentLog "Deployment log saved to: $logPath" -Level Info
}

# ============================================================================
# PROXMOX API FUNCTIONS
# ============================================================================

function Connect-ProxmoxAPI {
    param(
        [string]$Host = $ProxmoxHost,
        [string]$Password = $ProxmoxPassword
    )
    
    $authUrl = "https://${Host}:8006/api2/json/access/ticket"
    
    $body = @{
        username = "root@pam"
        password = $Password
    }
    
    try {
        $response = Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -SkipCertificateCheck
        $script:ProxmoxTicket = $response.data.ticket
        $script:ProxmoxCSRF = $response.data.CSRFPreventionToken
        
        Write-DeploymentLog "Proxmox API authentication successful" -Level Success
        return $true
    }
    catch {
        Write-DeploymentLog "Proxmox API authentication failed: $_" -Level Error
        return $false
    }
}

function Invoke-ProxmoxAPI {
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method = "GET",
        
        [hashtable]$Body = @{},
        
        [string]$Node = "cdx-pve-01"
    )
    
    if (-not $script:ProxmoxTicket) {
        throw "Not authenticated to Proxmox API. Call Connect-ProxmoxAPI first."
    }
    
    $url = "https://${ProxmoxHost}:8006/api2/json$Endpoint"
    
    $headers = @{
        "Cookie" = "PVEAuthCookie=$($script:ProxmoxTicket)"
        "CSRFPreventionToken" = $script:ProxmoxCSRF
    }
    
    try {
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers -SkipCertificateCheck
        }
        else {
            $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers -Body $Body -SkipCertificateCheck
        }
        return $response.data
    }
    catch {
        Write-Warning "Proxmox API call failed: $_"
        return $null
    }
}

function Wait-VMNetworkReady {
    param(
        [Parameter(Mandatory)]
        [int]$VMID,
        
        [Parameter(Mandatory)]
        [string]$ExpectedIP,
        
        [string]$Node = "cdx-pve-01",
        
        [int]$TimeoutSeconds = $AgentTimeoutSeconds,
        
        [int]$PollIntervalSeconds = $AgentPollIntervalSeconds
    )
    
    $startTime = Get-Date
    $timeout = New-TimeSpan -Seconds $TimeoutSeconds
    
    Write-Host "    Waiting for VM $VMID to report IP $ExpectedIP..." -ForegroundColor DarkGray
    
    while ((Get-Date) - $startTime -lt $timeout) {
        try {
            $agentInfo = Invoke-ProxmoxAPI -Endpoint "/nodes/$Node/qemu/$VMID/agent/network-get-interfaces" -Node $Node
            
            if ($agentInfo) {
                foreach ($iface in $agentInfo.result) {
                    if ($iface.'ip-addresses') {
                        foreach ($ip in $iface.'ip-addresses') {
                            if ($ip.'ip-address' -eq $ExpectedIP) {
                                Write-Host "    [OK] VM $VMID is ready at $ExpectedIP" -ForegroundColor Green
                                return @{ Success = $true; IP = $ExpectedIP }
                            }
                        }
                    }
                }
            }
        }
        catch {
            # Agent not ready yet, continue waiting
        }
        
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    
    Write-Host "    [TIMEOUT] VM $VMID did not become ready within $TimeoutSeconds seconds" -ForegroundColor Yellow
    return @{ Success = $false; IP = $null }
}

function Set-VMMemory {
    param(
        [Parameter(Mandatory)]
        [int]$VMID,
        
        [Parameter(Mandatory)]
        [int]$MemoryMB,
        
        [string]$Node = "cdx-pve-01"
    )
    
    $body = @{
        memory = $MemoryMB
    }
    
    Invoke-ProxmoxAPI -Endpoint "/nodes/$Node/qemu/$VMID/config" -Method PUT -Body $body -Node $Node
}

function Enable-VMIcmp {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerIP,
        
        [Parameter(Mandatory)]
        [PSCredential]$Credential
    )
    
    try {
        $session = New-PSSession -ComputerName $ComputerIP -Credential $Credential -ErrorAction Stop
        
        Invoke-Command -Session $session -ScriptBlock {
            # Enable ICMPv4 Echo Request (ping)
            $existingRule = Get-NetFirewallRule -DisplayName "Allow ICMPv4-In" -ErrorAction SilentlyContinue
            
            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName "Allow ICMPv4-In" `
                    -Protocol ICMPv4 `
                    -IcmpType 8 `
                    -Direction Inbound `
                    -Action Allow `
                    -Profile Any | Out-Null
            }
        }
        
        Remove-PSSession $session
        Write-Host "    [OK] ICMP enabled on $ComputerIP" -ForegroundColor Green
    }
    catch {
        Write-Host "    [WARN] Could not enable ICMP on $ComputerIP : $_" -ForegroundColor Yellow
    }
}

function Set-ExecutionPolicyUnrestricted {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerIP,
        
        [Parameter(Mandatory)]
        [PSCredential]$Credential
    )
    
    try {
        $session = New-PSSession -ComputerName $ComputerIP -Credential $Credential -ErrorAction Stop
        
        Invoke-Command -Session $session -ScriptBlock {
            Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force
        }
        
        Remove-PSSession $session
        Write-Host "    [OK] Execution policy set to Unrestricted on $ComputerIP" -ForegroundColor Green
    }
    catch {
        Write-Host "    [WARN] Could not set execution policy on $ComputerIP : $_" -ForegroundColor Yellow
    }
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "   PRE-FLIGHT CHECKS" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""

# Verify exercise path exists
if (-not (Test-Path $ExercisePath)) {
    Write-DeploymentLog "Exercise path not found: $ExercisePath" -Level Error
    exit 1
}

Write-DeploymentLog "Exercise path verified: $ExercisePath" -Level Success

# Connect to Proxmox API
if (-not (Connect-ProxmoxAPI)) {
    Write-DeploymentLog "Cannot proceed without Proxmox API connection" -Level Error
    exit 1
}

# Final confirmation
if (-not $WhatIf) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "   DEPLOYMENT CONFIRMATION" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Domain:    $script:DomainFQDN" -ForegroundColor White
    Write-Host "NetBIOS:   $script:DomainNetBIOS" -ForegroundColor White
    Write-Host "Exercise:  CHILLED_ROCKET" -ForegroundColor White
    Write-Host ""
    Write-Host "WARNING: This will deploy 343 VMs across 5 sites." -ForegroundColor Yellow
    Write-Host "         Estimated deployment time: 8 hours" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Type 'DEPLOY' to continue"
    
    if ($confirm -ne "DEPLOY") {
        Write-DeploymentLog "Deployment cancelled by user" -Level Warning
        exit 0
    }
}

# ============================================================================
# PHASE 1: FOREST ROOT DOMAIN CONTROLLER
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 1)) {
    Write-PhaseHeader -PhaseNumber 1 -PhaseName "Forest Root Domain Controller Deployment" -EstimatedDuration "45 minutes"
    
    # Step 1.1: Boost STK-DC-01 memory for forest creation
    Write-DeploymentLog "Step 1.1: Deploying STK-DC-01 VM with boosted resources..." -Level Info
    
    $dc01ConfigPath = Join-Path $ExercisePath "split_configs\stk-dc-01.json"
    
    if (-not (Test-Path $dc01ConfigPath)) {
        Write-DeploymentLog "Creating STK-DC-01 configuration file..." -Level Info
        
        # Create config with BOOSTED memory (16 GB)
        $dc01Config = @{
            computers = @(
                @{
                    name = $script:ForestRootDC.Name
                    vmid = $script:ForestRootDC.VMID
                    template = 2006
                    cpus = 4
                    memory = $script:ForestRootDC.BoostMemory  # 16 GB for forest creation
                    bridge = "stk100"
                    mac = "14:18:77:3C:A1:10"
                    ipAddress = "$($script:ForestRootDC.IP)/22"
                    gateway = "66.218.180.1"
                    dnsServer = $script:ForestRootDC.IP
                }
            )
        }
        
        $splitConfigDir = Join-Path $ExercisePath "split_configs"
        if (-not (Test-Path $splitConfigDir)) {
            New-Item -ItemType Directory -Path $splitConfigDir -Force | Out-Null
        }
        
        $dc01Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $dc01ConfigPath -Encoding UTF8
    }
    else {
        # Update existing config with boosted memory
        Write-DeploymentLog "Updating STK-DC-01 config with boosted memory (16 GB)..." -Level Info
        $existingConfig = Get-Content $dc01ConfigPath -Raw | ConvertFrom-Json
        $existingConfig.computers[0].memory = $script:ForestRootDC.BoostMemory
        $existingConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $dc01ConfigPath -Encoding UTF8
    }
    
    if (-not $WhatIf) {
        & .\Clone-ProxmoxVMs.ps1 -JsonPath $dc01ConfigPath -ProxmoxPassword $ProxmoxPassword
        
        if ($LASTEXITCODE -ne 0) {
            Write-DeploymentLog "Failed to deploy STK-DC-01" -Level Error
            Save-DeploymentLog
            exit 1
        }
    }
    
    Write-DeploymentLog "STK-DC-01 deployed with 16 GB RAM (boosted for forest creation)" -Level Success
    
    # Step 1.2: Wait for VM via QEMU Guest Agent
    Write-DeploymentLog "Step 1.2: Waiting for STK-DC-01 network availability via QEMU guest agent..." -Level Info
    
    if (-not $WhatIf) {
        $vmReady = Wait-VMNetworkReady -VMID $script:ForestRootDC.VMID `
                                       -ExpectedIP $script:ForestRootDC.IP `
                                       -Node $script:ForestRootDC.Node `
                                       -TimeoutSeconds 600  # 10 minutes for initial boot
        
        if (-not $vmReady.Success) {
            Write-DeploymentLog "STK-DC-01 did not become available within timeout" -Level Error
            Save-DeploymentLog
            exit 1
        }
        
        Write-DeploymentLog "STK-DC-01 is available at $($script:ForestRootDC.IP)" -Level Success
        
        # Enable ICMP on the deployed VM
        Enable-VMIcmp -ComputerIP $script:ForestRootDC.IP -Credential $script:CdxAdminCred
    }
    
    # Step 1.3: Set Execution Policy to Unrestricted
    Write-DeploymentLog "Step 1.3: Setting Execution Policy to Unrestricted on STK-DC-01..." -Level Info
    
    if (-not $WhatIf) {
        Set-ExecutionPolicyUnrestricted -ComputerIP $script:ForestRootDC.IP -Credential $script:CdxAdminCred
    }
    
    # Step 1.4: Transfer CDX-E repository with verification
    Write-DeploymentLog "Step 1.4: Transferring CDX-E repository to STK-DC-01..." -Level Info
    
    if (-not $WhatIf) {
        & .\Enhanced-Repository-Transfer.ps1 -Credential $script:CdxAdminCred -TargetComputer $script:ForestRootDC.IP
        
        if ($LASTEXITCODE -ne 0) {
            Write-DeploymentLog "Repository transfer failed or verification errors detected" -Level Error
            Save-DeploymentLog
            exit 1
        }
    }
    
    Write-DeploymentLog "Repository transferred and verified successfully" -Level Success
    
    # Step 1.5: Create AD Forest (hardcoded domain values)
    Write-DeploymentLog "Step 1.5: Creating Active Directory forest ($script:DomainFQDN)..." -Level Info
    
    if (-not $WhatIf) {
        try {
            $session = New-PSSession -ComputerName $script:ForestRootDC.IP -Credential $script:CdxAdminCred
            
            # Execute forest creation with hardcoded domain values and auto-reboot
            Invoke-Command -Session $session -ArgumentList @(
                $script:DsrmSecurePassword,
                $script:DomainAdminSecurePassword,
                $script:DomainFQDN,
                $script:DomainNetBIOS
            ) -ScriptBlock {
                param($DsrmPassword, $DomainAdminPassword, $DomainFQDN, $DomainNetBIOS)
                
                # Install AD DS role
                Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
                
                # Create forest with hardcoded values
                Install-ADDSForest `
                    -DomainName $DomainFQDN `
                    -DomainNetbiosName $DomainNetBIOS `
                    -SafeModeAdministratorPassword $DsrmPassword `
                    -InstallDns `
                    -Force
            }
            
            Remove-PSSession $session -ErrorAction SilentlyContinue
            
            # Wait for DC to reboot and come back online
            Write-DeploymentLog "Waiting for STK-DC-01 to reboot after forest creation..." -Level Info
            Start-Sleep -Seconds 60
            
            # Wait for DC to come back online
            $maxRetries = 30
            $retries = 0
            $forestReady = $false
            
            do {
                Start-Sleep -Seconds 20
                $retries++
                
                try {
                    $testSession = New-PSSession -ComputerName $script:ForestRootDC.IP -Credential $script:DomainAdminCred -ErrorAction Stop
                    
                    $adTest = Invoke-Command -Session $testSession -ScriptBlock {
                        try {
                            $domain = Get-ADDomain -ErrorAction Stop
                            return @{
                                Success = $true
                                DomainName = $domain.DNSRoot
                                NetBIOS = $domain.NetBIOSName
                            }
                        }
                        catch {
                            return @{ Success = $false }
                        }
                    }
                    
                    Remove-PSSession $testSession
                    
                    if ($adTest.Success) {
                        $forestReady = $true
                        Write-DeploymentLog "Active Directory forest created: $($adTest.DomainName) ($($adTest.NetBIOS))" -Level Success
                        break
                    }
                }
                catch {
                    Write-Host "    ... waiting for AD services (attempt $retries / $maxRetries)" -ForegroundColor DarkGray
                }
                
            } while ($retries -lt $maxRetries)
            
            if (-not $forestReady) {
                Write-DeploymentLog "Forest deployment timeout - manual verification required" -Level Error
                Save-DeploymentLog
                exit 1
            }
            
        }
        catch {
            Write-DeploymentLog "Forest creation failed: $_" -Level Error
            Save-DeploymentLog
            exit 1
        }
    }
    
    Write-DeploymentLog "Phase 1 complete: Forest Root DC operational" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 2: USER ACCOUNT DEPLOYMENT (IMMEDIATE POST-FOREST)
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 2)) {
    Write-PhaseHeader -PhaseNumber 2 -PhaseName "User Account Deployment" -EstimatedDuration "15 minutes"
    
    Write-DeploymentLog "Step 2.1: Creating user accounts and organizational structure..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        Invoke-Command -Session $session -ScriptBlock {
            cd C:\CDX-E
            .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
        }
        
        Remove-PSSession $session
        Write-DeploymentLog "User accounts and OU structure created successfully" -Level Success
    }
    
    Write-DeploymentLog "Phase 2 complete: Users deployed" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 3: GROUP POLICY DEPLOYMENT WITH BRANDING (IMMEDIATE POST-FOREST)
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 3)) {
    Write-PhaseHeader -PhaseNumber 3 -PhaseName "Group Policy Deployment with Branding" -EstimatedDuration "15 minutes"
    
    # =========================================================================
    # Step 3.1: Stage Branding Images to SYSVOL
    # =========================================================================
    
    Write-DeploymentLog "Step 3.1: Staging branding images to SYSVOL..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        $imageStageResult = Invoke-Command -Session $session -ArgumentList $script:DomainFQDN -ScriptBlock {
            param($DomainFQDN)
            
            # Define paths
            $sysvolBase = "$env:SystemRoot\SYSVOL\sysvol\$DomainFQDN"
            $netlogonPath = "$sysvolBase\scripts"
            $imagesTargetPath = "$netlogonPath\Images"
            $imageSourcePath = "C:\CDX-E\EXERCISES\CHILLED_ROCKET\Domain Files"
            
            # Required image files
            $requiredImages = @(
                "domain-splash-stark-industries.jpg",
                "domain-u-wall-stark-industries.jpg",
                "tony-stark-vip.jpg"
            )
            
            $results = @{
                Success = $true
                ImagesStaged = @()
                ImagesMissing = @()
                TargetPath = $imagesTargetPath
                Errors = @()
            }
            
            # Verify SYSVOL structure exists
            if (-not (Test-Path $netlogonPath)) {
                $results.Success = $false
                $results.Errors += "NETLOGON path not found: $netlogonPath"
                return $results
            }
            
            # Create Images folder if it doesn't exist
            if (-not (Test-Path $imagesTargetPath)) {
                try {
                    New-Item -Path $imagesTargetPath -ItemType Directory -Force | Out-Null
                    Write-Host "[Images] Created folder: $imagesTargetPath" -ForegroundColor Green
                }
                catch {
                    $results.Success = $false
                    $results.Errors += "Failed to create Images folder: $_"
                    return $results
                }
            }
            else {
                Write-Host "[Images] Target folder exists: $imagesTargetPath" -ForegroundColor DarkGray
            }
            
            # Verify source path exists
            if (-not (Test-Path $imageSourcePath)) {
                $results.Success = $false
                $results.Errors += "Source path not found: $imageSourcePath"
                return $results
            }
            
            # Copy each required image
            foreach ($imageName in $requiredImages) {
                $sourceFile = Join-Path $imageSourcePath $imageName
                $targetFile = Join-Path $imagesTargetPath $imageName
                
                if (Test-Path $sourceFile) {
                    try {
                        Copy-Item -Path $sourceFile -Destination $targetFile -Force
                        $fileSize = [math]::Round((Get-Item $targetFile).Length / 1KB, 2)
                        Write-Host "[Images] Staged: $imageName ($fileSize KB)" -ForegroundColor Green
                        $results.ImagesStaged += $imageName
                    }
                    catch {
                        Write-Host "[Images] Failed to copy: $imageName - $_" -ForegroundColor Red
                        $results.Errors += "Failed to copy $imageName : $_"
                    }
                }
                else {
                    Write-Host "[Images] Source not found: $imageName" -ForegroundColor Yellow
                    $results.ImagesMissing += $imageName
                }
            }
            
            # Verify all images were staged
            if ($results.ImagesMissing.Count -gt 0) {
                Write-Host "[Images] WARNING: $($results.ImagesMissing.Count) images missing from source" -ForegroundColor Yellow
            }
            
            # Set appropriate permissions on Images folder
            try {
                $acl = Get-Acl $imagesTargetPath
                # Ensure Domain Users can read the images
                $domainUsersRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "Domain Users",
                    "ReadAndExecute",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.AddAccessRule($domainUsersRule)
                Set-Acl -Path $imagesTargetPath -AclObject $acl
                Write-Host "[Images] Permissions configured for Domain Users (Read)" -ForegroundColor Green
            }
            catch {
                Write-Host "[Images] Warning: Could not set permissions - $_" -ForegroundColor Yellow
                $results.Errors += "Permission configuration warning: $_"
            }
            
            return $results
        }
        
        # Report image staging results
        if ($imageStageResult.Success) {
            Write-DeploymentLog "Branding images staged successfully to SYSVOL" -Level Success
            Write-DeploymentLog "  Staged: $($imageStageResult.ImagesStaged.Count) images" -Level Info
            Write-DeploymentLog "  Target: $($imageStageResult.TargetPath)" -Level Info
            
            if ($imageStageResult.ImagesMissing.Count -gt 0) {
                Write-DeploymentLog "  WARNING: Missing images: $($imageStageResult.ImagesMissing -join ', ')" -Level Warning
            }
        }
        else {
            Write-DeploymentLog "Failed to stage branding images" -Level Warning
            foreach ($err in $imageStageResult.Errors) {
                Write-DeploymentLog "  Error: $err" -Level Warning
            }
            # Continue with deployment - GPOs will be created but images won't display until fixed
        }
        
        Remove-PSSession $session -ErrorAction SilentlyContinue
    }
    
    # =========================================================================
    # Step 3.2: Deploy Group Policy Objects
    # =========================================================================
    
    Write-DeploymentLog "Step 3.2: Deploying Group Policy Objects..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        # Execute GPO deployment via ad_deploy.ps1
        # The enhanced Invoke-DeployGPOs function handles:
        # - GPO creation
        # - Registry policy configuration
        # - Security filtering
        # - OU linking
        # - Security group creation
        
        $gpoResult = Invoke-Command -Session $session -ScriptBlock {
            Set-Location C:\CDX-E
            
            Write-Host "`n=== Deploying Group Policy Objects ===" -ForegroundColor Cyan
            
            # Import required modules
            Import-Module GroupPolicy -ErrorAction SilentlyContinue
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
            
            # Load GPO configuration
            $gpoConfigPath = "C:\CDX-E\EXERCISES\CHILLED_ROCKET\gpo.json"
            
            if (-not (Test-Path $gpoConfigPath)) {
                Write-Host "[GPO] Configuration file not found: $gpoConfigPath" -ForegroundColor Red
                return @{ Success = $false; Error = "gpo.json not found" }
            }
            
            try {
                $gpoConfig = Get-Content $gpoConfigPath -Raw | ConvertFrom-Json
                
                Write-Host "[GPO] Loaded configuration with $($gpoConfig.gpos.Count) GPOs" -ForegroundColor Green
                
                # Call ad_deploy.ps1 which contains the enhanced Invoke-DeployGPOs function
                .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
                
                return @{ Success = $true }
            }
            catch {
                Write-Host "[GPO] Deployment error: $_" -ForegroundColor Red
                return @{ Success = $false; Error = $_.ToString() }
            }
        }
        
        if ($gpoResult.Success) {
            Write-DeploymentLog "Group Policy Objects deployed successfully" -Level Success
        }
        else {
            Write-DeploymentLog "GPO deployment encountered issues: $($gpoResult.Error)" -Level Warning
        }
        
        Remove-PSSession $session -ErrorAction SilentlyContinue
    }
    
    # =========================================================================
    # Step 3.3: Verify GPO Configuration (Summary)
    # =========================================================================
    
    Write-DeploymentLog "Step 3.3: Verifying GPO deployment..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        Invoke-Command -Session $session -ArgumentList $script:DomainFQDN -ScriptBlock {
            param($DomainFQDN)
            
            Import-Module GroupPolicy -ErrorAction SilentlyContinue
            
            Write-Host "`n=== GPO Deployment Summary ===" -ForegroundColor Cyan
            
            $gpos = Get-GPO -All | Select-Object DisplayName, GpoStatus, CreationTime
            
            Write-Host "`nGroup Policy Objects ($($gpos.Count) total):" -ForegroundColor Yellow
            foreach ($gpo in $gpos) {
                $status = if ($gpo.GpoStatus -eq "AllSettingsEnabled") { "[OK]" } else { "[!]" }
                Write-Host "  $status $($gpo.DisplayName)" -ForegroundColor $(if ($status -eq "[OK]") { "Green" } else { "Yellow" })
            }
            
            # List branding-specific GPOs
            $brandingGpos = $gpos | Where-Object { $_.DisplayName -like "SI *" }
            if ($brandingGpos) {
                Write-Host "`nStark Industries Branding GPOs:" -ForegroundColor Cyan
                foreach ($gpo in $brandingGpos) {
                    Write-Host "  - $($gpo.DisplayName)" -ForegroundColor Green
                }
            }
            
            # Verify image accessibility
            $imagePath = "\\$DomainFQDN\NETLOGON\Images"
            if (Test-Path $imagePath) {
                $images = Get-ChildItem $imagePath -Filter "*.jpg" -ErrorAction SilentlyContinue | Select-Object Name
                Write-Host "`nBranding Images in NETLOGON ($($images.Count) files):" -ForegroundColor Yellow
                foreach ($img in $images) {
                    Write-Host "  - $($img.Name)" -ForegroundColor Green
                }
            }
            else {
                Write-Host "`n[WARNING] NETLOGON Images path not accessible: $imagePath" -ForegroundColor Yellow
            }
        }
        
        Remove-PSSession $session -ErrorAction SilentlyContinue
        Write-DeploymentLog "GPO verification complete" -Level Success
    }
    
    # =========================================================================
    # Step 3.4: Revert STK-DC-01 Memory to Normal (8 GB)
    # =========================================================================
    
    Write-DeploymentLog "Step 3.4: Reverting STK-DC-01 memory to normal (8 GB)..." -Level Info
    
    if (-not $WhatIf) {
        Set-VMMemory -VMID $script:ForestRootDC.VMID `
                     -MemoryMB $script:ForestRootDC.NormalMemory `
                     -Node $script:ForestRootDC.Node
        
        Write-DeploymentLog "STK-DC-01 memory configuration reverted to 8 GB (effective after reboot)" -Level Info
    }
    
    # =========================================================================
    # Phase 3 Complete
    # =========================================================================
    
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "   Phase 3 Complete: Group Policy Deployment" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Branding GPOs Deployed:" -ForegroundColor White
    Write-Host "    - SI Domain Branding - Logon Screen (all systems)" -ForegroundColor Cyan
    Write-Host "    - SI Domain Branding - Workstation Wallpaper (all workstations)" -ForegroundColor Cyan
    Write-Host "    - SI VIP - Tony Stark Wallpaper (ML-DEV-W32805N only)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Images Staged:" -ForegroundColor White
    Write-Host "    - \\$script:DomainFQDN\NETLOGON\Images\" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Note: GPOs will apply automatically when systems join the domain" -ForegroundColor Yellow
    Write-Host "        and perform their initial Group Policy refresh." -ForegroundColor Yellow
    Write-Host ""
    
    Write-DeploymentLog "Phase 3 complete: GPOs and branding deployed" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 4: SITE DOMAIN CONTROLLERS
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 4)) {
    Write-PhaseHeader -PhaseNumber 4 -PhaseName "Site Domain Controller Deployment" -EstimatedDuration "90 minutes"
    
    # Step 4.1: Deploy site DC VMs
    Write-DeploymentLog "Step 4.1: Deploying site domain controller VMs..." -Level Info
    
    $siteDCsConfigPath = Join-Path $ExercisePath "split_configs\site-dcs-primary.json"
    
    # Site DC definitions
    $siteDCs = @(
        @{Name="STK-DC-02"; VMID=5002; IP="66.218.180.41"; Node="cdx-pve-01"; Template=2006; Bridge="stk100"; MAC="14:18:77:3C:A1:11"; Site="StarkTower-NYC"},
        @{Name="STK-DC-03"; VMID=5003; IP="50.222.74.10"; Node="cdx-pve-01"; Template=2008; Bridge="stk118"; MAC="94:57:A5:2B:C4:20"; Site="Dallas-Branch"},
        @{Name="STK-DC-04"; VMID=5004; IP="4.150.217.10"; Node="cdx-pve-01"; Template=2006; Bridge="stk112"; MAC="14:18:77:4A:B5:30"; Site="Malibu-Mansion"},
        @{Name="STK-DC-05"; VMID=5005; IP="14.206.2.10"; Node="cdx-pve-03"; Template=2004; Bridge="stk127"; MAC="90:1B:0E:4A:B6:80"; Site="Nagasaki-Facility"},
        @{Name="STK-DC-06"; VMID=5006; IP="37.74.126.10"; Node="cdx-pve-02"; Template=2004; Bridge="stk135"; MAC="14:18:77:5B:C7:90"; Site="Amsterdam-Hub"}
    )
    
    if (-not (Test-Path $siteDCsConfigPath)) {
        Write-DeploymentLog "Creating site DCs configuration file..." -Level Info
        
        $siteDCsConfig = @{
            computers = @(
                foreach ($dc in $siteDCs) {
                    @{
                        name = $dc.Name
                        vmid = $dc.VMID
                        template = $dc.Template
                        cpus = 4
                        memory = 8192
                        bridge = $dc.Bridge
                        mac = $dc.MAC
                        ipAddress = "$($dc.IP)/22"
                        gateway = ($dc.IP -replace '\.\d+$', '.1')
                        dnsServer = "$($script:ForestRootDC.IP),$($dc.IP)"
                    }
                }
            )
        }
        
        $siteDCsConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $siteDCsConfigPath -Encoding UTF8
    }
    
    if (-not $WhatIf) {
        & .\Clone-ProxmoxVMs.ps1 -JsonPath $siteDCsConfigPath -ProxmoxPassword $ProxmoxPassword
        
        if ($LASTEXITCODE -ne 0) {
            Write-DeploymentLog "Failed to deploy site DCs" -Level Error
            Save-DeploymentLog
            exit 1
        }
    }
    
    Write-DeploymentLog "Site DC VMs deployed successfully" -Level Success
    
    # Step 4.2: Wait for all site DCs via QEMU Guest Agent
    Write-DeploymentLog "Step 4.2: Waiting for site DCs to become available via QEMU guest agent..." -Level Info
    
    if (-not $WhatIf) {
        foreach ($dc in $siteDCs) {
            Write-DeploymentLog "  Waiting for $($dc.Name)..." -Level Info
            
            $vmReady = Wait-VMNetworkReady -VMID $dc.VMID `
                                           -ExpectedIP $dc.IP `
                                           -Node $dc.Node `
                                           -TimeoutSeconds $AgentTimeoutSeconds
            
            if ($vmReady.Success) {
                Enable-VMIcmp -ComputerIP $dc.IP -Credential $script:CdxAdminCred
            }
            else {
                Write-DeploymentLog "  $($dc.Name) did not become available - will retry during domain join" -Level Warning
            }
        }
    }
    
    # Step 4.3: Domain join site DCs
    Write-DeploymentLog "Step 4.3: Joining site DCs to domain..." -Level Info
    
    if (-not $WhatIf) {
        foreach ($dc in $siteDCs) {
            Write-DeploymentLog "  Domain-joining $($dc.Name)..." -Level Info
            
            try {
                $session = New-PSSession -ComputerName $dc.IP -Credential $script:CdxAdminCred -ErrorAction Stop
                
                Invoke-Command -Session $session -ArgumentList $dc.Name, $script:DomainAdminCred, $script:DomainFQDN -ScriptBlock {
                    param($NewName, $DomainCred, $DomainName)
                    
                    Add-Computer -DomainName $DomainName `
                                 -NewName $NewName `
                                 -Credential $DomainCred `
                                 -Restart -Force
                }
                
                Remove-PSSession $session
                Write-DeploymentLog "  $($dc.Name) joined and rebooting" -Level Success
            }
            catch {
                Write-DeploymentLog "  Failed to join $($dc.Name): $_" -Level Error
            }
        }
        
        # Wait for DCs to reboot and rejoin network
        Write-DeploymentLog "Waiting for DCs to reboot..." -Level Info
        
        foreach ($dc in $siteDCs) {
            Write-DeploymentLog "  Waiting for $($dc.Name) to come back online..." -Level Info
            
            $vmBack = Wait-VMNetworkReady -VMID $dc.VMID `
                                          -ExpectedIP $dc.IP `
                                          -Node $dc.Node `
                                          -TimeoutSeconds 600
            
            if (-not $vmBack.Success) {
                Write-DeploymentLog "  $($dc.Name) did not come back online - manual intervention may be required" -Level Warning
            }
        }
    }
    
    # Step 4.4: Promote site DCs to domain controllers
    Write-DeploymentLog "Step 4.4: Promoting site servers to domain controllers..." -Level Info
    
    if (-not $WhatIf) {
        foreach ($dc in $siteDCs) {
            Write-DeploymentLog "  Promoting $($dc.Name)..." -Level Info
            
            try {
                $session = New-PSSession -ComputerName $dc.IP -Credential $script:DomainAdminCred -ErrorAction Stop
                
                Invoke-Command -Session $session -ArgumentList $script:DomainFQDN, $script:DsrmSecurePassword, $dc.Site -ScriptBlock {
                    param($DomainName, $DsrmPassword, $SiteName)
                    
                    # Install AD DS role
                    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
                    
                    # Promote to domain controller
                    Install-ADDSDomainController `
                        -DomainName $DomainName `
                        -SiteName $SiteName `
                        -SafeModeAdministratorPassword $DsrmPassword `
                        -InstallDns `
                        -NoRebootOnCompletion:$false `
                        -Force
                }
                
                Remove-PSSession $session -ErrorAction SilentlyContinue
                Write-DeploymentLog "  $($dc.Name) promotion initiated - will reboot" -Level Success
                
                # Wait for DC to come back as domain controller
                Start-Sleep -Seconds 120
                
                $vmBack = Wait-VMNetworkReady -VMID $dc.VMID `
                                              -ExpectedIP $dc.IP `
                                              -Node $dc.Node `
                                              -TimeoutSeconds 600
                
                if ($vmBack.Success) {
                    # Verify DC promotion
                    try {
                        $verifySession = New-PSSession -ComputerName $dc.IP -Credential $script:DomainAdminCred -ErrorAction Stop
                        
                        $isDC = Invoke-Command -Session $verifySession -ScriptBlock {
                            (Get-ADDomainController -Identity $env:COMPUTERNAME -ErrorAction SilentlyContinue) -ne $null
                        }
                        
                        Remove-PSSession $verifySession
                        
                        if ($isDC) {
                            Write-DeploymentLog "  [VERIFIED] $($dc.Name) is operational as DC" -Level Success
                        }
                    }
                    catch {
                        Write-DeploymentLog "  Could not verify $($dc.Name) DC status" -Level Warning
                    }
                }
            }
            catch {
                Write-DeploymentLog "  Failed to promote $($dc.Name): $_" -Level Error
            }
        }
        
        # Verify replication
        Write-DeploymentLog "Validating AD Replication..." -Level Info
        
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        Invoke-Command -Session $session -ScriptBlock {
            repadmin /replsummary
        }
        Remove-PSSession $session
    }
    
    Write-DeploymentLog "Phase 4 complete: All domain controllers operational" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 5: MEMBER SERVERS
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 5)) {
    Write-PhaseHeader -PhaseNumber 5 -PhaseName "Member Server Deployment" -EstimatedDuration "45 minutes"
    
    Write-DeploymentLog "Step 5.1: Deploying member servers..." -Level Info
    
    $coreInfraConfigPath = Join-Path $ExercisePath "split_configs\core-infrastructure.json"
    
    if (Test-Path $coreInfraConfigPath) {
        if (-not $WhatIf) {
            & .\Clone-ProxmoxVMs.ps1 -JsonPath $coreInfraConfigPath -ProxmoxPassword $ProxmoxPassword
            
            if ($LASTEXITCODE -ne 0) {
                Write-DeploymentLog "Failed to deploy member servers" -Level Error
                Save-DeploymentLog
                exit 1
            }
        }
        
        Write-DeploymentLog "Member servers deployed successfully" -Level Success
        
        # Step 5.2: Wait for servers via QEMU Guest Agent
        Write-DeploymentLog "Step 5.2: Waiting for member servers to become available..." -Level Info
        
        if (-not $WhatIf) {
            $serverConfig = Get-Content $coreInfraConfigPath -Raw | ConvertFrom-Json
            
            foreach ($server in $serverConfig.computers) {
                Write-Host "    Checking $($server.name)..." -ForegroundColor DarkGray
                
                $serverIP = $server.ipAddress -replace '/\d+$', ''
                $serverNode = if ($server.proxmox) { $server.proxmox.node } else { "cdx-pve-01" }
                
                $vmReady = Wait-VMNetworkReady -VMID $server.vmid `
                                               -ExpectedIP $serverIP `
                                               -Node $serverNode `
                                               -TimeoutSeconds 180
                
                if ($vmReady.Success) {
                    Enable-VMIcmp -ComputerIP $serverIP -Credential $script:CdxAdminCred
                }
            }
        }
        
        # Step 5.3: Domain join servers
        Write-DeploymentLog "Step 5.3: Joining servers to domain..." -Level Info
        
        if (-not $WhatIf) {
            $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
            
            $hasScript = Invoke-Command -Session $session -ScriptBlock {
                Test-Path "C:\CDX-E\deployment_scripts\Server-Domain-Join.ps1"
            }
            
            if ($hasScript) {
                Invoke-Command -Session $session -ScriptBlock {
                    cd C:\CDX-E\deployment_scripts
                    .\Server-Domain-Join.ps1
                }
            } else {
                Write-DeploymentLog "Server-Domain-Join.ps1 not found - manual domain join required" -Level Warning
            }
            
            Remove-PSSession $session
        }
        
        Write-DeploymentLog "Phase 5 complete: Member servers operational" -Level Success
    } else {
        Write-DeploymentLog "Core infrastructure config not found - skipping member servers" -Level Warning
    }
    
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 6: DHCP DEPLOYMENT
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 6)) {
    Write-PhaseHeader -PhaseNumber 6 -PhaseName "DHCP Scope Deployment" -EstimatedDuration "20 minutes"
    
    Write-DeploymentLog "Step 6.1: Deploying DHCP scopes across all sites..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        $hasScript = Invoke-Command -Session $session -ScriptBlock {
            Test-Path "C:\CDX-E\deployment_scripts\Deploy-DHCP.ps1"
        }
        
        if ($hasScript) {
            Invoke-Command -Session $session -ScriptBlock {
                cd C:\CDX-E\deployment_scripts
                .\Deploy-DHCP.ps1
            }
            
            Write-DeploymentLog "DHCP scopes deployed successfully" -Level Success
        } else {
            Write-DeploymentLog "Deploy-DHCP.ps1 not found - manual DHCP configuration required" -Level Warning
        }
        
        Remove-PSSession $session
    }
    
    Write-DeploymentLog "Phase 6 complete: DHCP operational" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 7: WORKSTATION DEPLOYMENT
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 7)) {
    Write-PhaseHeader -PhaseNumber 7 -PhaseName "Workstation Deployment" -EstimatedDuration "3-4 hours"
    
    $workstationConfigs = @(
        @{File="workstations-nyc.json"; Site="NYC"},
        @{File="workstations-dal.json"; Site="Dallas"},
        @{File="workstations-mal.json"; Site="Malibu"},
        @{File="workstations-ngs.json"; Site="Nagasaki"},
        @{File="workstations-ams.json"; Site="Amsterdam"}
    )
    
    $stepNum = 1
    foreach ($config in $workstationConfigs) {
        Write-DeploymentLog "Step 7.$stepNum: Deploying $($config.Site) workstations..." -Level Info
        
        $configPath = Join-Path $ExercisePath "split_configs\$($config.File)"
        
        if (Test-Path $configPath) {
            if (-not $WhatIf) {
                & .\Clone-ProxmoxVMs.ps1 -JsonPath $configPath -ProxmoxPassword $ProxmoxPassword
                
                if ($LASTEXITCODE -ne 0) {
                    Write-DeploymentLog "Failed to deploy $($config.Site) workstations" -Level Warning
                } else {
                    Write-DeploymentLog "$($config.Site) workstations deployed" -Level Success
                    
                    # Wait for workstations and enable ICMP (batch)
                    $wsConfig = Get-Content $configPath -Raw | ConvertFrom-Json
                    $workstations = if ($wsConfig.workstations) { $wsConfig.workstations } else { $wsConfig.computers }
                    
                    Write-Host "    Waiting for workstations to come online..." -ForegroundColor DarkGray
                    
                    foreach ($ws in $workstations) {
                        $wsIP = $ws.ipAddress -replace '/\d+$', ''
                        $wsNode = if ($ws.proxmox) { $ws.proxmox.node } else { "cdx-pve-01" }
                        
                        $vmReady = Wait-VMNetworkReady -VMID $ws.vmid `
                                                       -ExpectedIP $wsIP `
                                                       -Node $wsNode `
                                                       -TimeoutSeconds 120
                        
                        if ($vmReady.Success) {
                            Enable-VMIcmp -ComputerIP $wsIP -Credential $script:CdxAdminCred
                        }
                    }
                }
                
                # Delay between sites to manage load
                Start-Sleep -Seconds 60
            }
        } else {
            Write-DeploymentLog "Config not found: $($config.File) - skipping" -Level Warning
        }
        
        $stepNum++
    }
    
    # Domain join workstations
    Write-DeploymentLog "Step 7.6: Joining workstations to domain..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        $hasScript = Invoke-Command -Session $session -ScriptBlock {
            Test-Path "C:\CDX-E\deployment_scripts\Workstation-Domain-Join.ps1"
        }
        
        if ($hasScript) {
            Invoke-Command -Session $session -ScriptBlock {
                cd C:\CDX-E\deployment_scripts
                .\Workstation-Domain-Join.ps1
            }
            
            Write-DeploymentLog "Workstation domain join completed" -Level Success
        } else {
            Write-DeploymentLog "Workstation-Domain-Join.ps1 not found" -Level Warning
        }
        
        Remove-PSSession $session
    }
    
    Write-DeploymentLog "Phase 7 complete: Workstations deployed" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 8: VALIDATION
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 8)) {
    Write-PhaseHeader -PhaseNumber 8 -PhaseName "Environment Validation" -EstimatedDuration "10 minutes"
    
    Write-DeploymentLog "Step 8.1: Running comprehensive health check..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "$($script:ForestRootDC.Name).$script:DomainFQDN" -Credential $script:DomainAdminCred
        
        $hasScript = Invoke-Command -Session $session -ScriptBlock {
            Test-Path "C:\CDX-E\deployment_scripts\Environment-Health-Check.ps1"
        }
        
        if ($hasScript) {
            Invoke-Command -Session $session -ScriptBlock {
                cd C:\CDX-E\deployment_scripts
                .\Environment-Health-Check.ps1
            }
        } else {
            # Basic validation
            Invoke-Command -Session $session -ArgumentList $script:DomainFQDN -ScriptBlock {
                param($DomainName)
                
                Write-Host "`n[AD Domain]" -ForegroundColor Yellow
                Get-ADDomain | Select-Object Name, Forest, DomainMode
                
                Write-Host "`n[Domain Controllers]" -ForegroundColor Yellow
                Get-ADDomainController -Filter * | Select-Object Name, Site, IPv4Address
                
                Write-Host "`n[AD Replication]" -ForegroundColor Yellow
                repadmin /replsummary
                
                Write-Host "`n[Computer Count]" -ForegroundColor Yellow
                $servers = (Get-ADComputer -Filter * -SearchBase "OU=Servers,*" -ErrorAction SilentlyContinue).Count
                $workstations = (Get-ADComputer -Filter * -SearchBase "OU=Workstations,*" -ErrorAction SilentlyContinue).Count
                $total = (Get-ADComputer -Filter *).Count
                Write-Host "Servers: $servers"
                Write-Host "Workstations: $workstations"
                Write-Host "Total: $total"
                
                Write-Host "`n[User Count]" -ForegroundColor Yellow
                $users = (Get-ADUser -Filter * | Where-Object { $_.Name -notmatch "krbtgt|Guest|Administrator" }).Count
                Write-Host "User accounts: $users"
                
                Write-Host "`n[Group Policy Objects]" -ForegroundColor Yellow
                Get-GPO -All | Select-Object DisplayName, GpoStatus
                
                Write-Host "`n[Branding Images]" -ForegroundColor Yellow
                $imagePath = "\\$DomainName\NETLOGON\Images"
                if (Test-Path $imagePath) {
                    Get-ChildItem $imagePath | Select-Object Name, Length
                } else {
                    Write-Host "Images not found at $imagePath" -ForegroundColor Yellow
                }
            }
        }
        
        Remove-PSSession $session
    }
    
    Write-DeploymentLog "Phase 8 complete: Validation finished" -Level Success
}

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================

$script:EndTime = Get-Date
$duration = $script:EndTime - $script:StartTime

Write-Host "`n"
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Domain: $script:DomainFQDN" -ForegroundColor White
Write-Host "NetBIOS: $script:DomainNetBIOS" -ForegroundColor White
Write-Host "Exercise: CHILLED_ROCKET" -ForegroundColor White
Write-Host "Start Time: $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "End Time: $($script:EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor White
Write-Host ""
Write-Host "Branding Status:" -ForegroundColor Cyan
Write-Host "  - Logon/Lock Screen: domain-splash-stark-industries.jpg" -ForegroundColor White
Write-Host "  - Default Wallpaper: domain-u-wall-stark-industries.jpg" -ForegroundColor White
Write-Host "  - Tony Stark VIP: tony-stark-vip.jpg (ML-DEV-W32805N)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Create VM snapshots for rollback capability" -ForegroundColor White
Write-Host "  2. Configure backup jobs for domain controllers" -ForegroundColor White
Write-Host "  3. Document administrative credentials securely" -ForegroundColor White
Write-Host "  4. Review deployment log for any warnings" -ForegroundColor White
Write-Host "  5. Begin training exercises" -ForegroundColor White
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green

Save-DeploymentLog

# Clear sensitive data from memory
$script:DomainAdminPassword = $null
$script:LocalAdminPassword = $null
[System.GC]::Collect()

Write-Host "`nDeployment orchestration complete!" -ForegroundColor Green

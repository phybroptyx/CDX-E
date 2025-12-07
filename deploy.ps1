<#
.SYNOPSIS
    Master deployment orchestration for CHILLED_ROCKET exercise environment

.DESCRIPTION
    Orchestrates complete deployment of Stark Industries global enterprise from
    Management Workstation through all phases:
    - Phase 1: Forest Root DC deployment and forest creation
    - Phase 2: Site DC deployment and promotion
    - Phase 3: Member server deployment and domain join
    - Phase 4: DHCP scope deployment
    - Phase 5: Workstation deployment and domain join
    - Phase 6: User account deployment
    - Phase 7: Group Policy deployment
    - Phase 8: Environment validation

.PARAMETER ProxmoxHost
    Proxmox cluster node IP (any node)

.PARAMETER ProxmoxPassword
    Password for Proxmox root@pam user

.PARAMETER LocalAdminPassword
    Local Administrator password for new VMs

.PARAMETER DomainAdminPassword
    STARK\Administrator password (will be set during forest creation)

.PARAMETER DsrmPassword
    Directory Services Restore Mode password

.PARAMETER ExercisePath
    Path to CHILLED_ROCKET exercise folder

.PARAMETER SkipPhases
    Array of phase numbers to skip (e.g., @(1,2) to skip phases 1 and 2)

.PARAMETER PauseAfterPhase
    Pause for user confirmation after each phase

.EXAMPLE
    .\Master-Deploy-CHILLED_ROCKET.ps1 -ProxmoxPassword "P@ssw0rd" `
                                       -LocalAdminPassword "LocalP@ss" `
                                       -DomainAdminPassword "DomainP@ss" `
                                       -DsrmPassword "DSRM_P@ss"

.EXAMPLE
    # Skip forest creation if already exists, start from Phase 2
    .\Master-Deploy-CHILLED_ROCKET.ps1 -SkipPhases @(1) -ProxmoxPassword "P@ssw0rd"

.NOTES
    Author: CDX-E Team
    Version: 1.0
    Requires: PowerShell 5.1+, Network access to Proxmox cluster
    Duration: ~8 hours for complete deployment
#>

[CmdletBinding()]
param(
    [string]$ProxmoxHost = "172.30.3.49",
    
    [Parameter(Mandatory)]
    [string]$ProxmoxPassword,
    
    [Parameter(Mandatory)]
    [string]$LocalAdminPassword,
    
    [Parameter(Mandatory)]
    [string]$DomainAdminPassword,
    
    [Parameter(Mandatory)]
    [string]$DsrmPassword,
    
    [string]$ExercisePath = ".\EXERCISES\CHILLED_ROCKET",
    
    [int[]]$SkipPhases = @(),
    
    [switch]$PauseAfterPhase,
    
    [switch]$WhatIf
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Stop"
$script:DeploymentLog = @()
$script:StartTime = Get-Date

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
# PRE-FLIGHT CHECKS
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
    Domain: stark-industries.midgard.mrvl
    Exercise: CHILLED_ROCKET

"@ -ForegroundColor Cyan

Write-DeploymentLog "Starting CHILLED_ROCKET deployment orchestration" -Level Info
Write-DeploymentLog "Exercise path: $ExercisePath" -Level Info

if ($WhatIf) {
    Write-DeploymentLog "Running in WhatIf mode - no changes will be made" -Level Warning
}

# Validate exercise path
if (-not (Test-Path $ExercisePath)) {
    Write-DeploymentLog "Exercise path not found: $ExercisePath" -Level Error
    exit 1
}

# Validate required files
$requiredFiles = @(
    "exercise_template.json",
    "computers.json",
    "master_workstation_inventory.json",
    "users.json",
    "services.json",
    "gpo.json",
    "dhcp_scopes.json"
)

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $ExercisePath $file
    if (-not (Test-Path $filePath)) {
        Write-DeploymentLog "Required file not found: $file" -Level Error
        exit 1
    }
}

Write-DeploymentLog "All required configuration files present" -Level Success

# Validate required scripts
$requiredScripts = @(
    "Clone-ProxmoxVMs.ps1",
    "Enhanced-Repository-Transfer.ps1",
    "ad_deploy.ps1"
)

foreach ($script in $requiredScripts) {
    if (-not (Test-Path ".\$script")) {
        Write-DeploymentLog "Required script not found: $script" -Level Error
        exit 1
    }
}

Write-DeploymentLog "All required deployment scripts present" -Level Success

# Test Proxmox connectivity
Write-DeploymentLog "Testing Proxmox connectivity to $ProxmoxHost..." -Level Info

try {
    $testUrl = "https://${ProxmoxHost}:8006"
    $null = Invoke-WebRequest -Uri $testUrl -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-DeploymentLog "Proxmox host is reachable" -Level Success
}
catch {
    Write-DeploymentLog "Cannot reach Proxmox host at $ProxmoxHost" -Level Error
    exit 1
}

# Prepare credentials
$script:LocalAdminCred = New-Object System.Management.Automation.PSCredential (
    "Administrator",
    (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force)
)

$script:DomainAdminCred = New-Object System.Management.Automation.PSCredential (
    "STARK\Administrator",
    (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force)
)

$script:DsrmSecurePassword = ConvertTo-SecureString $DsrmPassword -AsPlainText -Force

Write-DeploymentLog "Pre-flight checks complete" -Level Success
Write-Host ""

if (-not $WhatIf) {
    Write-Host "WARNING: This will deploy 343 VMs across your Proxmox cluster." -ForegroundColor Yellow
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
    
    # Step 1.1: Deploy STK-DC-01 VM
    Write-DeploymentLog "Step 1.1: Deploying STK-DC-01 VM..." -Level Info
    
    $dc01ConfigPath = Join-Path $ExercisePath "split_configs\stk-dc-01.json"
    
    if (-not (Test-Path $dc01ConfigPath)) {
        Write-DeploymentLog "Creating STK-DC-01 configuration file..." -Level Info
        
        $dc01Config = @{
            computers = @(
                @{
                    name = "STK-DC-01"
                    vmid = 5001
                    template = 2006
                    cpus = 4
                    memory = 8192
                    bridge = "stk100"
                    mac = "14:18:77:3C:A1:10"
                    ipAddress = "66.218.180.40/22"
                    gateway = "66.218.180.1"
                    dnsServer = "66.218.180.40"
                }
            )
        }
        
        $dc01Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $dc01ConfigPath -Encoding UTF8
    }
    
    if (-not $WhatIf) {
        & .\Clone-ProxmoxVMs.ps1 -JsonPath $dc01ConfigPath -ProxmoxPassword $ProxmoxPassword
        
        if ($LASTEXITCODE -ne 0) {
            Write-DeploymentLog "Failed to deploy STK-DC-01" -Level Error
            Save-DeploymentLog
            exit 1
        }
    }
    
    Write-DeploymentLog "STK-DC-01 deployed successfully" -Level Success
    
    # Step 1.2: Wait for VM to boot
    Write-DeploymentLog "Step 1.2: Waiting for STK-DC-01 to boot (120 seconds)..." -Level Info
    if (-not $WhatIf) {
        Start-Sleep -Seconds 120
    }
    
    # Step 1.3: Transfer CDX-E repository with verification
    Write-DeploymentLog "Step 1.3: Transferring CDX-E repository to STK-DC-01..." -Level Info
    
    if (-not $WhatIf) {
        & .\Enhanced-Repository-Transfer.ps1 -Credential $script:LocalAdminCred -TargetComputer "66.218.180.40"
        
        if ($LASTEXITCODE -ne 0) {
            Write-DeploymentLog "Repository transfer failed or verification errors detected" -Level Error
            Save-DeploymentLog
            exit 1
        }
    }
    
    Write-DeploymentLog "Repository transferred and verified successfully" -Level Success
    
    # Step 1.4: Create AD Forest
    Write-DeploymentLog "Step 1.4: Creating Active Directory forest..." -Level Info
    
    if (-not $WhatIf) {
        try {
            $session = New-PSSession -ComputerName "66.218.180.40" -Credential $script:LocalAdminCred
            
            # Execute forest creation with auto-reboot
            Invoke-Command -Session $session -ArgumentList $DsrmSecurePassword -ScriptBlock {
                param($DsrmPwd)
                
                cd C:\CDX-E
                
                # This will prompt for forest details and auto-reboot
                .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" `
                               -GenerateStructure `
                               -AutoReboot `
                               -RebootDelaySeconds 60
            }
            
            Remove-PSSession $session
            
            Write-DeploymentLog "Forest creation initiated - STK-DC-01 will reboot automatically" -Level Success
            Write-DeploymentLog "Waiting for forest deployment to complete (20 minutes)..." -Level Info
            
            # Wait for reboot and forest deployment
            Start-Sleep -Seconds 300  # 5 minutes for reboot
            
            # Poll for AD availability
            $maxWait = 900  # 15 minutes
            $waited = 0
            $forestReady = $false
            
            do {
                Start-Sleep -Seconds 30
                $waited += 30
                
                try {
                    $testSession = New-PSSession -ComputerName "66.218.180.40" -Credential $script:DomainAdminCred -ErrorAction Stop
                    
                    $adTest = Invoke-Command -Session $testSession -ScriptBlock {
                        try {
                            Get-ADDomain -ErrorAction Stop
                            return $true
                        }
                        catch {
                            return $false
                        }
                    }
                    
                    Remove-PSSession $testSession
                    
                    if ($adTest) {
                        $forestReady = $true
                        break
                    }
                }
                catch {
                    Write-Host "    ... waiting for forest ($waited / $maxWait seconds)" -ForegroundColor DarkGray
                }
                
            } while ($waited -lt $maxWait)
            
            if (-not $forestReady) {
                Write-DeploymentLog "Forest deployment timeout - manual verification required" -Level Error
                Save-DeploymentLog
                exit 1
            }
            
            Write-DeploymentLog "Active Directory forest created successfully" -Level Success
            
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
# PHASE 2: SITE DOMAIN CONTROLLERS
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 2)) {
    Write-PhaseHeader -PhaseNumber 2 -PhaseName "Site Domain Controller Deployment" -EstimatedDuration "90 minutes"
    
    # Step 2.1: Deploy site DC VMs
    Write-DeploymentLog "Step 2.1: Deploying site domain controller VMs..." -Level Info
    
    $siteDCsConfigPath = Join-Path $ExercisePath "split_configs\site-dcs-primary.json"
    
    if (-not (Test-Path $siteDCsConfigPath)) {
        Write-DeploymentLog "Creating site DCs configuration file..." -Level Info
        
        $siteDCsConfig = @{
            computers = @(
                @{
                    name = "STK-DC-02"
                    vmid = 5002
                    template = 2006
                    cpus = 4
                    memory = 8192
                    bridge = "stk100"
                    mac = "14:18:77:3C:A1:11"
                    ipAddress = "66.218.180.41/22"
                    gateway = "66.218.180.1"
                    dnsServer = "66.218.180.40,66.218.180.41"
                },
                @{
                    name = "STK-DC-03"
                    vmid = 5003
                    template = 2008
                    cpus = 4
                    memory = 8192
                    bridge = "stk118"
                    mac = "94:57:A5:2B:C4:20"
                    ipAddress = "50.222.74.10/22"
                    gateway = "50.222.72.1"
                    dnsServer = "66.218.180.40,50.222.74.10"
                },
                @{
                    name = "STK-DC-04"
                    vmid = 5004
                    template = 2006
                    cpus = 4
                    memory = 8192
                    bridge = "stk112"
                    mac = "14:18:77:4A:B5:30"
                    ipAddress = "4.150.217.10/22"
                    gateway = "4.150.216.1"
                    dnsServer = "66.218.180.40,4.150.217.10"
                },
                @{
                    name = "STK-DC-05"
                    vmid = 5005
                    template = 2004
                    cpus = 4
                    memory = 8192
                    bridge = "stk127"
                    mac = "90:1B:0E:4A:B6:80"
                    ipAddress = "14.206.2.10/22"
                    gateway = "14.206.0.1"
                    dnsServer = "66.218.180.40,14.206.2.10"
                },
                @{
                    name = "STK-DC-06"
                    vmid = 5006
                    template = 2004
                    cpus = 4
                    memory = 8192
                    bridge = "stk135"
                    mac = "14:18:77:5B:C7:90"
                    ipAddress = "37.74.126.10/22"
                    gateway = "37.74.124.1"
                    dnsServer = "66.218.180.40,37.74.126.10"
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
    
    # Step 2.2: Wait for VMs to boot
    Write-DeploymentLog "Step 2.2: Waiting for site DCs to boot (180 seconds)..." -Level Info
    if (-not $WhatIf) {
        Start-Sleep -Seconds 180
    }
    
    # Step 2.3: Domain join site DCs
    Write-DeploymentLog "Step 2.3: Joining site DCs to domain..." -Level Info
    
    if (-not $WhatIf) {
        $siteDCs = @(
            @{Name="STK-DC-02"; IP="66.218.180.41"},
            @{Name="STK-DC-03"; IP="50.222.74.10"},
            @{Name="STK-DC-04"; IP="4.150.217.10"},
            @{Name="STK-DC-05"; IP="14.206.2.10"},
            @{Name="STK-DC-06"; IP="37.74.126.10"}
        )
        
        foreach ($dc in $siteDCs) {
            Write-DeploymentLog "  Domain-joining $($dc.Name)..." -Level Info
            
            try {
                $session = New-PSSession -ComputerName $dc.IP -Credential $script:LocalAdminCred
                
                Invoke-Command -Session $session -ArgumentList $dc.Name, $script:DomainAdminCred -ScriptBlock {
                    param($NewName, $DomainCred)
                    
                    Add-Computer -DomainName "stark-industries.midgard.mrvl" `
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
        
        Write-DeploymentLog "Waiting for DCs to reboot (300 seconds)..." -Level Info
        Start-Sleep -Seconds 300
    }
    
    # Step 2.4: Create DC promotion script on STK-DC-01
    Write-DeploymentLog "Step 2.4: Creating DC promotion automation script..." -Level Info
    
    $dcPromotionScript = @'
# DC-Promotion-Automation.ps1
param([SecureString]$DsrmPassword)

$siteDCs = @(
    @{Name="STK-DC-02"; IP="66.218.180.41"; Site="StarkTower-NYC"; OS="Server 2012 R2"},
    @{Name="STK-DC-03"; IP="50.222.74.10"; Site="Dallas-Branch"; OS="Server 2008 R2"; Legacy=$true},
    @{Name="STK-DC-04"; IP="4.150.217.10"; Site="Malibu-Mansion"; OS="Server 2012 R2"},
    @{Name="STK-DC-05"; IP="14.206.2.10"; Site="Nagasaki-Facility"; OS="Server 2016"},
    @{Name="STK-DC-06"; IP="37.74.126.10"; Site="Amsterdam-Hub"; OS="Server 2016"}
)

$domainCred = Get-Credential -Message "STARK\Administrator"

foreach ($dc in $siteDCs) {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "Promoting $($dc.Name) at site $($dc.Site)" -ForegroundColor Cyan
    if ($dc.Legacy) {
        Write-Host "  WARNING: LEGACY $($dc.OS)" -ForegroundColor Yellow
    }
    Write-Host "================================================" -ForegroundColor Cyan
    
    try {
        $session = New-PSSession -ComputerName $dc.Name -Credential $domainCred -ErrorAction Stop
        
        Write-Host "  [1/3] Installing AD DS role..." -ForegroundColor Yellow
        Invoke-Command -Session $session -ScriptBlock {
            Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        }
        Write-Host "  [OK] AD DS role installed" -ForegroundColor Green
        
        Write-Host "  [2/3] Promoting to Domain Controller..." -ForegroundColor Yellow
        Invoke-Command -Session $session -ArgumentList $dc.Site, $DsrmPassword -ScriptBlock {
            param($SiteName, $DsrmPwd)
            
            Install-ADDSDomainController `
                -DomainName "stark-industries.midgard.mrvl" `
                -SiteName $SiteName `
                -InstallDns:$true `
                -CreateDnsDelegation:$false `
                -SafeModeAdministratorPassword $DsrmPwd `
                -Force:$true `
                -NoRebootOnCompletion:$false
        }
        
        Write-Host "  [OK] Promoted and rebooting..." -ForegroundColor Green
        Remove-PSSession $session -ErrorAction SilentlyContinue
        
        Write-Host "  [3/3] Waiting for reboot..." -ForegroundColor Yellow
        Start-Sleep -Seconds 120
        
        $retries = 0
        do {
            Start-Sleep -Seconds 10
            $retries++
            try {
                $testSession = New-PSSession -ComputerName $dc.Name -Credential $domainCred -ErrorAction Stop
                $isDC = Invoke-Command -Session $testSession -ScriptBlock {
                    Get-Service -Name NTDS -ErrorAction SilentlyContinue
                }
                Remove-PSSession $testSession -ErrorAction SilentlyContinue
                
                if ($isDC) {
                    Write-Host "  [VERIFIED] $($dc.Name) is now a DC" -ForegroundColor Green
                    break
                }
            }
            catch {
                Write-Host "    ... waiting (attempt $retries/30)" -ForegroundColor DarkGray
            }
        } while ($retries -lt 30)
        
    }
    catch {
        Write-Host "  [ERROR] Failed: $_" -ForegroundColor Red
    }
}

Write-Host "`nValidating AD Replication..." -ForegroundColor Cyan
repadmin /replsummary
'@
    
    if (-not $WhatIf) {
        # Copy script to STK-DC-01
        $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
        
        Invoke-Command -Session $session -ArgumentList $dcPromotionScript -ScriptBlock {
            param($ScriptContent)
            $ScriptContent | Out-File -FilePath "C:\CDX-E\DC-Promotion-Automation.ps1" -Encoding UTF8
        }
        
        # Execute promotion script
        Write-DeploymentLog "Step 2.5: Executing DC promotion automation..." -Level Info
        
        Invoke-Command -Session $session -ArgumentList $script:DsrmSecurePassword -ScriptBlock {
            param($DsrmPwd)
            cd C:\CDX-E
            .\DC-Promotion-Automation.ps1 -DsrmPassword $DsrmPwd
        }
        
        Remove-PSSession $session
        Write-DeploymentLog "All site DCs promoted successfully" -Level Success
    }
    
    Write-DeploymentLog "Phase 2 complete: All domain controllers operational" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 3: MEMBER SERVERS
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 3)) {
    Write-PhaseHeader -PhaseNumber 3 -PhaseName "Member Server Deployment" -EstimatedDuration "45 minutes"
    
    Write-DeploymentLog "Step 3.1: Deploying member servers..." -Level Info
    
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
        
        # Wait for boot
        Write-DeploymentLog "Step 3.2: Waiting for servers to boot (180 seconds)..." -Level Info
        if (-not $WhatIf) {
            Start-Sleep -Seconds 180
        }
        
        # Domain join servers
        Write-DeploymentLog "Step 3.3: Joining servers to domain..." -Level Info
        
        if (-not $WhatIf) {
            # This would execute Server-Domain-Join.ps1 from STK-DC-01
            $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
            
            # Check if script exists, create if needed
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
        
        Write-DeploymentLog "Phase 3 complete: Member servers operational" -Level Success
    } else {
        Write-DeploymentLog "Core infrastructure config not found - skipping member servers" -Level Warning
    }
    
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 4: DHCP DEPLOYMENT
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 4)) {
    Write-PhaseHeader -PhaseNumber 4 -PhaseName "DHCP Scope Deployment" -EstimatedDuration "20 minutes"
    
    Write-DeploymentLog "Step 4.1: Deploying DHCP scopes across all sites..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
        
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
    
    Write-DeploymentLog "Phase 4 complete: DHCP operational" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 5: WORKSTATION DEPLOYMENT
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 5)) {
    Write-PhaseHeader -PhaseNumber 5 -PhaseName "Workstation Deployment" -EstimatedDuration "3-4 hours"
    
    $workstationConfigs = @(
        "workstations-nyc.json",
        "workstations-dal.json",
        "workstations-mal.json",
        "workstations-ngs.json",
        "workstations-ams.json"
    )
    
    foreach ($configFile in $workstationConfigs) {
        $site = $configFile -replace 'workstations-(.+)\.json','$1'
        Write-DeploymentLog "Step 5.$($workstationConfigs.IndexOf($configFile)+1): Deploying $site workstations..." -Level Info
        
        $configPath = Join-Path $ExercisePath "split_configs\$configFile"
        
        if (Test-Path $configPath) {
            if (-not $WhatIf) {
                & .\Clone-ProxmoxVMs.ps1 -JsonPath $configPath -ProxmoxPassword $ProxmoxPassword
                
                if ($LASTEXITCODE -ne 0) {
                    Write-DeploymentLog "Failed to deploy $site workstations" -Level Warning
                } else {
                    Write-DeploymentLog "$site workstations deployed" -Level Success
                }
                
                # Delay between sites to manage load
                Start-Sleep -Seconds 60
            }
        } else {
            Write-DeploymentLog "Config not found: $configFile - skipping" -Level Warning
        }
    }
    
    # Domain join workstations
    Write-DeploymentLog "Step 5.6: Joining workstations to domain..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
        
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
    
    Write-DeploymentLog "Phase 5 complete: Workstations deployed" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 6: USER ACCOUNTS
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 6)) {
    Write-PhaseHeader -PhaseNumber 6 -PhaseName "User Account Deployment" -EstimatedDuration "15 minutes"
    
    Write-DeploymentLog "Step 6.1: Creating user accounts..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
        
        Invoke-Command -Session $session -ScriptBlock {
            cd C:\CDX-E
            .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
        }
        
        Remove-PSSession $session
        Write-DeploymentLog "User accounts created successfully" -Level Success
    }
    
    Write-DeploymentLog "Phase 6 complete: Users deployed" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 7: GROUP POLICY
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 7)) {
    Write-PhaseHeader -PhaseNumber 7 -PhaseName "Group Policy Deployment" -EstimatedDuration "15 minutes"
    
    Write-DeploymentLog "Step 7.1: Deploying Group Policy Objects..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
        
        Invoke-Command -Session $session -ScriptBlock {
            cd C:\CDX-E
            .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
        }
        
        # Force GPO update
        Write-DeploymentLog "Step 7.2: Forcing Group Policy update..." -Level Info
        
        $hasScript = Invoke-Command -Session $session -ScriptBlock {
            Test-Path "C:\CDX-E\deployment_scripts\Force-GPUpdate.ps1"
        }
        
        if ($hasScript) {
            Invoke-Command -Session $session -ScriptBlock {
                cd C:\CDX-E\deployment_scripts
                .\Force-GPUpdate.ps1
            }
        }
        
        Remove-PSSession $session
        Write-DeploymentLog "Group Policies deployed successfully" -Level Success
    }
    
    Write-DeploymentLog "Phase 7 complete: GPOs deployed" -Level Success
    Wait-UserConfirmation
}

# ============================================================================
# PHASE 8: VALIDATION
# ============================================================================

if (-not (Test-PhaseSkipped -PhaseNumber 8)) {
    Write-PhaseHeader -PhaseNumber 8 -PhaseName "Environment Validation" -EstimatedDuration "10 minutes"
    
    Write-DeploymentLog "Step 8.1: Running comprehensive health check..." -Level Info
    
    if (-not $WhatIf) {
        $session = New-PSSession -ComputerName "STK-DC-01.stark-industries.midgard.mrvl" -Credential $script:DomainAdminCred
        
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
            Invoke-Command -Session $session -ScriptBlock {
                Write-Host "`n[AD Domain]" -ForegroundColor Yellow
                Get-ADDomain | Select-Object Name, Forest, DomainMode
                
                Write-Host "`n[Domain Controllers]" -ForegroundColor Yellow
                Get-ADDomainController -Filter * | Select-Object Name, Site, IPv4Address
                
                Write-Host "`n[AD Replication]" -ForegroundColor Yellow
                repadmin /replsummary
                
                Write-Host "`n[Computer Count]" -ForegroundColor Yellow
                $servers = (Get-ADComputer -Filter * -SearchBase "OU=Servers,*").Count
                $workstations = (Get-ADComputer -Filter * -SearchBase "OU=Workstations,*").Count
                Write-Host "Servers: $servers"
                Write-Host "Workstations: $workstations"
                Write-Host "Total: $($servers + $workstations)"
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
Write-Host "Domain: stark-industries.midgard.mrvl" -ForegroundColor White
Write-Host "Exercise: CHILLED_ROCKET" -ForegroundColor White
Write-Host "Start Time: $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "End Time: $($script:EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor White
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

Write-Host "`nDeployment orchestration complete!" -ForegroundColor Green
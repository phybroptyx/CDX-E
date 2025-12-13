<#
.SYNOPSIS
    Master Active Directory deployment script for lab "exercises".

.DESCRIPTION
    - If an AD domain already exists:
        * Autodetects domain info (or uses overrides).
        * Deploys Sites, OUs, Groups, DNS, GPOs, Computers, Users from JSON.
    - If no AD domain exists:
        * Prompts for domain details.
        * Installs AD DS role if needed.
        * Creates a new AD forest on this server.
        * Automatically reboots and continues deployment (with -AutoReboot flag).

.NOTES
    - Run as a local admin (pre-forest) or Domain Admin (post-forest).
    - Designed for Windows Server 2012 R2 and later.
    
.VERSION
    2.2 - Automatic Reboot Enhancement + Syntax Fixes
    - Fixed unused $task variable assignment (line 182)
    - Renamed Ensure-ActiveDirectoryDomain -> Initialize-ActiveDirectoryDomain
    - Renamed Build-HardwareInfoJSON -> New-HardwareInfoJSON
    - Added -AutoReboot switch parameter
    - Added -RebootDelaySeconds parameter (default: 30)
    - Added Invoke-GracefulReboot function with countdown
    - Added remote session detection
    - Added scheduled task creation for post-reboot auto-deployment
    - Maintains full backward compatibility (manual reboot still default)
    
    2.1 - Hardware Info Enhancement
    - Modified Invoke-DeployComputers to store hardware metadata
    - Added New-HardwareInfoJSON helper function (formerly Build-HardwareInfoJSON)
    - Added Get-HardwareInfo helper function
    - Hardware data stored in "info" attribute as JSON
#>

[CmdletBinding()]
param(
    # Root folder where exercise configs live
    [string]$ExercisesRoot = ".\EXERCISES",

    # Name of the specific exercise (e.g., CHILLED_ROCKET)
    [string]$ExerciseName,

    # Optional: override full config path directly
    [string]$ConfigPath,

    # Optional: override domain info; otherwise auto-detected or prompted
    [string]$DomainFQDN,
    [string]$DomainDN,

    # Optional: regenerate structure.json for the exercise before deployment
    [switch]$GenerateStructure,

    # Pass through to AD/DNS/GPO cmdlets
    [switch]$WhatIf,
    
    # NEW v2.2: Enable automatic reboot after forest creation
    [switch]$AutoReboot,
    
    # NEW v2.2: Countdown delay before automatic reboot (seconds)
    [int]$RebootDelaySeconds = 30
)

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "           Active Directory Deployment Engine        " -ForegroundColor Cyan
Write-Host "          Hardware Info + Auto-Reboot v2.2           " -ForegroundColor Cyan
Write-Host "=====================================================`n" -ForegroundColor Cyan

# ===========================================================================
# NEW v2.2: Graceful Reboot Function with Remote Session Detection
# ===========================================================================

function Invoke-GracefulReboot {
    <#
    .SYNOPSIS
        Performs graceful system reboot with countdown and optional scheduled task creation.
    
    .DESCRIPTION
        - Detects if running in PowerShell remoting session
        - Creates scheduled task for post-reboot auto-deployment if remote
        - Provides countdown with cancel option
        - Handles both local and remote execution contexts
    
    .PARAMETER DelaySeconds
        Number of seconds to countdown before reboot (default: 30)
    
    .PARAMETER ExerciseName
        Exercise name to pass to post-reboot deployment
    
    .PARAMETER ConfigPath
        Configuration path for post-reboot deployment
    
    .PARAMETER ScriptPath
        Full path to this script for scheduled task
    #>
    
    param(
        [int]$DelaySeconds = 30,
        [string]$ExerciseName,
        [string]$ConfigPath,
        [string]$ScriptPath
    )
    
    Write-Host "`n=====================================================" -ForegroundColor Yellow
    Write-Host "           AUTOMATIC REBOOT INITIATED                " -ForegroundColor Yellow
    Write-Host "=====================================================" -ForegroundColor Yellow
    
    # Detect if running in remote PowerShell session
    $isRemote = $null -ne $PSSenderInfo
    
    if ($isRemote) {
        Write-Host "`n[AutoReboot] Remote PowerShell session detected" -ForegroundColor Cyan
        Write-Host "[AutoReboot] Creating scheduled task for post-reboot deployment..." -ForegroundColor Yellow
        
        try {
            # Build PowerShell command for scheduled task
            $psCommand = @"
-ExecutionPolicy Bypass -NoProfile -File "$ScriptPath" -ExerciseName "$ExerciseName"
"@
            
            # Create scheduled task action
            $taskAction = New-ScheduledTaskAction `
                -Execute "PowerShell.exe" `
                -Argument $psCommand
            
            # Trigger: Run at system startup
            $taskTrigger = New-ScheduledTaskTrigger -AtStartup
            
            # Principal: Run as SYSTEM with highest privileges
            $taskPrincipal = New-ScheduledTaskPrincipal `
                -UserId "NT AUTHORITY\SYSTEM" `
                -LogonType ServiceAccount `
                -RunLevel Highest
            
            # Settings: Allow task to run even if on battery, etc.
            $taskSettings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -ExecutionTimeLimit (New-TimeSpan -Hours 2)
            
            # Register the scheduled task (FIXED: removed unused $task variable)
            Register-ScheduledTask `
                -TaskName "CDX-PostReboot-Deployment" `
                -Action $taskAction `
                -Trigger $taskTrigger `
                -Principal $taskPrincipal `
                -Settings $taskSettings `
                -Description "Auto-run CDX-E AD deployment after forest creation reboot" `
                -Force | Out-Null
            
            Write-Host "[AutoReboot] [OK] Scheduled task created successfully" -ForegroundColor Green
            Write-Host "              Task Name: CDX-PostReboot-Deployment" -ForegroundColor Gray
            Write-Host "              Will execute: $ScriptPath" -ForegroundColor Gray
            Write-Host "              With exercise: $ExerciseName" -ForegroundColor Gray
            Write-Host "`n[AutoReboot] Post-reboot deployment will continue automatically!" -ForegroundColor Green
            
        }
        catch {
            Write-Warning "[AutoReboot] Failed to create scheduled task: $_"
            Write-Host "[AutoReboot] You will need to manually rerun the script after reboot" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n[AutoReboot] Local console session detected" -ForegroundColor Cyan
        Write-Host "[AutoReboot] After reboot, manually rerun:" -ForegroundColor Yellow
        Write-Host "            .\ad_deploy.ps1 -ExerciseName '$ExerciseName'" -ForegroundColor Gray
    }
    
    # Countdown with cancel option
    Write-Host "`n[AutoReboot] System will RESTART in $DelaySeconds seconds..." -ForegroundColor Yellow
    Write-Host "[AutoReboot] Press Ctrl+C NOW to cancel automatic reboot" -ForegroundColor Cyan
    Write-Host "" -NoNewline
    
    for ($i = $DelaySeconds; $i -gt 0; $i--) {
        # Display countdown on same line
        Write-Host "`r[AutoReboot] Restarting in $i seconds...  " -NoNewline -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    Write-Host "`r[AutoReboot] Restarting NOW...                                     " -ForegroundColor Red
    Write-Host ""
    
    # Initiate restart
    Write-Host "[AutoReboot] Executing system restart..." -ForegroundColor Red
    Write-Host "=====================================================" -ForegroundColor Red
    
    Start-Sleep -Seconds 2
    Restart-Computer -Force
}

# ===========================================================================
# Resolve config path based on exercise layout
# ===========================================================================

if (-not $ConfigPath) {
    if (-not $ExerciseName) {
        $ExerciseName = Read-Host "Enter exercise name (e.g., CHILLED_ROCKET)"
    }
    $ConfigPath = Join-Path -Path $ExercisesRoot -ChildPath $ExerciseName
}

# Ensure exercise folder exists if we are generating structure
if ($GenerateStructure) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[Config] Creating exercise folder: $ConfigPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
    }

    # Locate generate_structure.ps1 in the same folder as this script
    $scriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
    $generatorPath = Join-Path $scriptDir "generate_structure.ps1"

    if (-not (Test-Path $generatorPath)) {
        throw "Structure generator not found: $generatorPath"
    }

    Write-Host "[Config] Regenerating structure.json via generate_structure.ps1..." -ForegroundColor Yellow
    & $generatorPath -ExercisesRoot $ExercisesRoot -ExerciseName $ExerciseName -ErrorAction Stop
}

if (-not (Test-Path $ConfigPath)) {
    throw "Config path not found: $ConfigPath"
}

Write-Host "Exercises Root : $ExercisesRoot"
Write-Host "Exercise Name  : $ExerciseName"
Write-Host "Config Path    : $ConfigPath"

# NEW v2.2: Display Auto-Reboot status
if ($AutoReboot) {
    Write-Host "Auto-Reboot    : ENABLED (${RebootDelaySeconds}s countdown)" -ForegroundColor Green
} else {
    Write-Host "Auto-Reboot    : DISABLED (manual reboot required)" -ForegroundColor Gray
}

Write-Host ""

# Make sure structure.json exists before we try to load it
$structurePath = Join-Path $ConfigPath "structure.json"
if (-not (Test-Path $structurePath)) {
    throw "structure.json not found at expected path: $structurePath. Run with -GenerateStructure to create it."
}

# ===========================================================================
# Test basic prerequisites
# ===========================================================================

function Test-Prerequisites {
    Write-Host "[Prereq] Checking environment..." -ForegroundColor Cyan

    # Check OS
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $caption = $os.Caption
        if ($caption -notmatch "Server") {
            Write-Warning "This script is designed for Windows Server. Detected OS: $caption.
AD DS deployment typically runs on Windows Server."
        }
    } catch {}

    # Required modules (some may be added later once roles are installed)
    $requiredModules = @("ActiveDirectory", "ADDSDeployment", "DnsServer", "GroupPolicy")

    foreach ($mod in $requiredModules) {
        $found = Get-Module -ListAvailable -Name $mod
        if (-not $found) {
            Write-Warning "Module not currently available: $mod (may be installed later if needed)."
        }
        else {
            Write-Host "[OK] Module available: $mod" -ForegroundColor DarkGreen
        }
    }

    Write-Host "[Prereq] Check complete.`n" -ForegroundColor Cyan
}

Test-Prerequisites

# Try to import AD module (may fail pre-forest; that's ok)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue | Out-Null

# ===========================================================================
# Helper: Load JSON config from the exercise folder
# ===========================================================================

function Get-JsonConfig {
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $fullPath = Join-Path -Path $ConfigPath -ChildPath $FileName
    if (-not (Test-Path $fullPath)) {
        throw "Config file not found: $fullPath"
    }

    Get-Content $fullPath -Raw | ConvertFrom-Json
}

# ===========================================================================
# Initialize domain: either detect or create a new forest
# (RENAMED from Ensure-ActiveDirectoryDomain to use approved verb)
# ===========================================================================

function Initialize-ActiveDirectoryDomain {
    param(
        [string]$DomainFQDNParam,
        [string]$DomainDNParam
    )

    Write-Host "[Domain] Checking for existing Active Directory domain..." -ForegroundColor Cyan

    # Try to detect an existing domain
    try {
        $adDomain = Get-ADDomain -ErrorAction Stop
        Write-Host "[Domain] Existing AD domain detected: $($adDomain.DNSRoot)" -ForegroundColor Green

        if (-not $DomainFQDNParam) { $DomainFQDNParam = $adDomain.DNSRoot }
        if (-not $DomainDNParam)   { $DomainDNParam   = $adDomain.DistinguishedName }

        Write-Host "=== MODE: POST-FOREST CONFIGURATION / EXERCISE DEPLOYMENT ===`n" -ForegroundColor Magenta

        return @{
            DomainFQDN = $DomainFQDNParam
            DomainDN   = $DomainDNParam
            CreatedNew = $false
        }
    }
    catch {
        Write-Warning "[Domain] No existing domain detected or unable to contact one."
    }

    # At this point, no domain is detected.
    Write-Host "`nNo Active Directory domain detected." -ForegroundColor Yellow
    $choice = Read-Host "Do you want to create a NEW AD forest on this server? (Y/N)"

    if ($choice -notin @("Y","y","Yes","YES")) {
        throw "Aborting: No domain found and user chose not to create a new forest."
    }

    if (-not $DomainFQDNParam) {
        $DomainFQDNParam = Read-Host "Enter domain FQDN (e.g., stark.local)"
    }

    $netbiosName = Read-Host "Enter domain NetBIOS name (e.g., STARK)"
    $dsrmPassword = Read-Host "Enter a DSRM (Safe Mode) password" -AsSecureString

    Write-Host "`n[Forest] Installing AD DS role if needed..." -ForegroundColor Cyan
    try {
        $feature = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction Stop
        if (-not $feature.Installed) {
            Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
            Write-Host "[Forest] AD DS role installed." -ForegroundColor Green
        } else {
            Write-Host "[Forest] AD DS role already installed." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Warning "[Forest] Could not check or install AD DS role: $_"
    }

    Write-Host "[Forest] Creating new forest: $DomainFQDNParam..." -ForegroundColor Yellow

    if (-not $DomainDNParam) {
        $parts = $DomainFQDNParam -split '\.'
        $dcString = ($parts | ForEach-Object { "DC=$_" }) -join ','
        $DomainDNParam = $dcString
    }

    if ($WhatIf) {
        Write-Host "[WhatIf] Would create forest: $DomainFQDNParam with DN: $DomainDNParam" -ForegroundColor Yellow
    } else {
        Import-Module ADDSDeployment -ErrorAction Stop

        Install-ADDSForest `
            -DomainName $DomainFQDNParam `
            -DomainNetbiosName $netbiosName `
            -SafeModeAdministratorPassword $dsrmPassword `
            -InstallDns:$true `
            -Force:$true `
            -NoRebootOnCompletion:$true

        Write-Host "`n[Domain] [OK] New forest created successfully!" -ForegroundColor Green
    }

    # NEW v2.2: Handle reboot based on -AutoReboot flag
    if ($AutoReboot) {
        # Get full path to this script for scheduled task
        $scriptFullPath = $MyInvocation.MyCommand.Path
        
        Invoke-GracefulReboot `
            -DelaySeconds $RebootDelaySeconds `
            -ExerciseName $ExerciseName `
            -ConfigPath $ConfigPath `
            -ScriptPath $scriptFullPath
        
        # If we reach here, user cancelled reboot
        Write-Host "`n[AutoReboot] Reboot cancelled by user" -ForegroundColor Yellow
        Write-Host "[Info] You MUST reboot this server before continuing." -ForegroundColor Yellow
        Write-Host "After reboot, rerun this script to apply the exercise configuration." -ForegroundColor Yellow
        
    } else {
        # Manual reboot (original behavior)
        Write-Host "`n[Domain] You MUST reboot this server before continuing." -ForegroundColor Yellow
        Write-Host "After reboot, rerun this script to apply the exercise configuration." -ForegroundColor Yellow
    }

    return @{
        DomainFQDN = $DomainFQDNParam
        DomainDN   = $DomainDNParam
        CreatedNew = $true
    }
}

# --- Domain handling ---
$domainInfo = Initialize-ActiveDirectoryDomain -DomainFQDNParam $DomainFQDN -DomainDNParam $DomainDN
$DomainFQDN = $domainInfo.DomainFQDN
$DomainDN   = $domainInfo.DomainDN

Write-Host "`nUsing domain: FQDN = $DomainFQDN; DN = $DomainDN`n" -ForegroundColor Cyan

# If we just created a new forest in this run (and not in -WhatIf), stop here.
if ($domainInfo.CreatedNew -and -not $WhatIf) {
    Write-Host "`n[Domain] Forest creation completed." -ForegroundColor Green
    
    if ($AutoReboot) {
        Write-Host "[AutoReboot] System will restart automatically" -ForegroundColor Yellow
        Write-Host "[AutoReboot] Deployment will continue post-reboot (if scheduled task created)" -ForegroundColor Yellow
    } else {
        Write-Host "[Info] Please reboot this server, then rerun ad_deploy.ps1 for '$ExerciseName' to continue with Sites/OUs/etc." -ForegroundColor Yellow
    }
    
    return
}

# =============================================================================
# NEW v2.2: Cleanup scheduled task if we're in post-reboot run
# =============================================================================

try {
    $scheduledTask = Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -ErrorAction SilentlyContinue
    
    if ($scheduledTask) {
        Write-Host "[AutoReboot] Detected post-reboot scheduled task" -ForegroundColor Cyan
        Write-Host "[AutoReboot] Removing task (no longer needed)..." -ForegroundColor Yellow
        
        Unregister-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -Confirm:$false
        
        Write-Host "[AutoReboot] [OK] Scheduled task removed" -ForegroundColor Green
        Write-Host "[AutoReboot] Continuing with exercise deployment...`n" -ForegroundColor Green
    }
}
catch {
    # Ignore errors - task may not exist
}

# =============================================================================
# NEW v2.1: Hardware Info Helper Functions
# =============================================================================

function New-HardwareInfoJSON {
    <#
    .SYNOPSIS
        Creates JSON string for hardware info storage in AD computer's info attribute.
        (RENAMED from Build-HardwareInfoJSON to use approved verb)
    
    .DESCRIPTION
        Takes manufacturer, model, and service_tag fields and creates
        a compact JSON string for storage in the AD "info" attribute.
        Returns empty string if no hardware data provided.
    #>
    param(
        [string]$Manufacturer,
        [string]$Model,
        [string]$ServiceTag
    )
    
    # Only build JSON if at least one field has data
    if ([string]::IsNullOrWhiteSpace($Manufacturer) -and 
        [string]::IsNullOrWhiteSpace($Model) -and 
        [string]::IsNullOrWhiteSpace($ServiceTag)) {
        return ""
    }
    
    # Build ordered hashtable
    $hardwareData = [ordered]@{}
    
    if (-not [string]::IsNullOrWhiteSpace($Manufacturer)) {
        $hardwareData["manufacturer"] = $Manufacturer.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $hardwareData["model"] = $Model.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($ServiceTag)) {
        $hardwareData["serviceTag"] = $ServiceTag.Trim()
    }
    
    # Convert to compact JSON
    $json = $hardwareData | ConvertTo-Json -Compress -Depth 2
    
    return $json
}

function Get-HardwareInfo {
    <#
    .SYNOPSIS
        Extracts hardware info from AD computer object's info attribute.
    
    .DESCRIPTION
        Parses the JSON stored in the "info" attribute and returns
        a custom object with manufacturer, model, and serviceTag properties.
        Returns $null if no hardware info present or JSON invalid.
    #>
    param(
        [Parameter(Mandatory)]
        [Microsoft.ActiveDirectory.Management.ADComputer]$Computer
    )
    
    if ([string]::IsNullOrWhiteSpace($Computer.info)) {
        return $null
    }
    
    try {
        $hardwareData = $Computer.info | ConvertFrom-Json
        return $hardwareData
    }
    catch {
        Write-Warning "[Hardware] Failed to parse hardware info for $($Computer.Name): $_"
        return $null
    }
}

# =============================================================================
# Deployment functions
# =============================================================================

function Invoke-DeploySitesAndOUs {
    param(
        [Parameter(Mandatory)]
        $StructureConfig,

        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    Write-Host "`n[1] Deploying AD Sites, Subnets, and Site Links..." -ForegroundColor Cyan

    # --- Sites ---
    # Special handling: Rename "Default-First-Site-Name" to the first site in our list
    $firstSite = $StructureConfig.sites[0]
    
    try {
        $defaultSite = Get-ADReplicationSite -Identity "Default-First-Site-Name" -ErrorAction Stop
        
        # Rename default site to our first site
        if ($WhatIf) {
            Write-Host "[WhatIf][Site] Would rename: Default-First-Site-Name -> $($firstSite.name)" -ForegroundColor Yellow
        } else {
            Rename-ADObject -Identity $defaultSite.DistinguishedName -NewName $firstSite.name -WhatIf:$false
            
            # Update description
            Set-ADReplicationSite -Identity $firstSite.name -Description $firstSite.description -WhatIf:$false
            
            Write-Host "[Site] Renamed: Default-First-Site-Name -> $($firstSite.name)" -ForegroundColor Green
        }
    }
    catch {
        # Default site doesn't exist or already renamed - check if first site exists
        try {
            $existing = Get-ADReplicationSite -Identity $firstSite.name -ErrorAction Stop
            Write-Host "[Site] $($firstSite.name) (already exists)" -ForegroundColor DarkGray
        }
        catch {
            # First site doesn't exist - create it
            if ($WhatIf) {
                Write-Host "[WhatIf][Site] Would create: $($firstSite.name)" -ForegroundColor Yellow
            } else {
                New-ADReplicationSite -Name $firstSite.name -Description $firstSite.description -WhatIf:$false
                Write-Host "[Site] Created: $($firstSite.name)" -ForegroundColor Green
            }
        }
    }
    
    # Create remaining sites (skip first since we handled it above)
    for ($i = 1; $i -lt $StructureConfig.sites.Count; $i++) {
        $site = $StructureConfig.sites[$i]
        $name = $site.name
        $desc = $site.description

        try {
            $existing = Get-ADReplicationSite -Identity $name -ErrorAction Stop
            Write-Host "[Site] $name (already exists)" -ForegroundColor DarkGray
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][Site] Would create: $name" -ForegroundColor Yellow
            } else {
                New-ADReplicationSite -Name $name -Description $desc -WhatIf:$false
                Write-Host "[Site] Created: $name" -ForegroundColor Green
            }
        }
    }

    # --- Subnets ---
    foreach ($subnet in $StructureConfig.subnets) {
        $subnetName = $subnet.cidr
        $siteName   = $subnet.site

        try {
            $existingSubnet = Get-ADReplicationSubnet -Identity $subnetName -ErrorAction Stop
            Write-Host "[Subnet] $subnetName (already exists)" -ForegroundColor DarkGray
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][Subnet] Would create: $subnetName -> $siteName" -ForegroundColor Yellow
            } else {
                New-ADReplicationSubnet -Name $subnetName -Site $siteName -WhatIf:$false
                Write-Host "[Subnet] Created: $subnetName -> $siteName" -ForegroundColor Green
            }
        }
    }

    # --- Site Links ---
    foreach ($link in $StructureConfig.siteLinks) {
        $linkName = $link.name
        $sites    = $link.sites
        $cost     = if ($link.cost) { $link.cost } else { 100 }
        $replInt  = if ($link.replicationInterval) { $link.replicationInterval } else { 180 }

        try {
            $existingLink = Get-ADReplicationSiteLink -Identity $linkName -ErrorAction Stop
            Write-Host "[SiteLink] $linkName (already exists)" -ForegroundColor DarkGray
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][SiteLink] Would create: $linkName" -ForegroundColor Yellow
            } else {
                New-ADReplicationSiteLink -Name $linkName `
                    -SitesIncluded $sites `
                    -Cost $cost `
                    -ReplicationFrequencyInMinutes $replInt `
                    -WhatIf:$false
                Write-Host "[SiteLink] Created: $linkName (Cost: $cost)" -ForegroundColor Green
            }
        }
    }

    # Clean up the default site link if it exists
    try {
        $defaultLink = Get-ADReplicationSiteLink -Identity "DEFAULTIPSITELINK" -ErrorAction Stop
        if ($WhatIf) {
            Write-Host "[WhatIf][SiteLink] Would remove: DEFAULTIPSITELINK" -ForegroundColor Yellow
        } else {
            Remove-ADReplicationSiteLink -Identity "DEFAULTIPSITELINK" -Confirm:$false -WhatIf:$false
            Write-Host "[SiteLink] Removed: DEFAULTIPSITELINK" -ForegroundColor Green
        }
    }
    catch {
        # DEFAULTIPSITELINK might not exist or already removed
    }

    # --- Organizational Units ---
    Write-Host "`n[2] Deploying Organizational Units..." -ForegroundColor Cyan

    # Sort OUs by depth so parents are created before children
    $ousSorted = $StructureConfig.ous | Sort-Object -Property @{Expression={
        ($_.dn -split ',').Count
    }}

    foreach ($ou in $ousSorted) {
        $ouDN   = $ou.dn
        $ouName = $ou.name
        $desc   = $ou.description
        
        # Complete the DN if it doesn't include domain components
        if ($ouDN -notmatch "DC=") {
            $ouDN = "$ouDN,$DomainDN"
        }

        try {
            $existingOU = Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction Stop
            Write-Host "[OU] $ouName (already exists)" -ForegroundColor DarkGray
        }
        catch {
            # Parse parent DN
            $parts = $ouDN -split ',',2
            
            if ($parts.Count -lt 2) {
                # This is a root OU (e.g., "OU=Sites") - parent is the domain DN
                $parentPath = $DomainDN
            } else {
                $parentPath = $parts[1]
            }

            if ($WhatIf) {
                Write-Host "[WhatIf][OU] Would create: $ouName in $parentPath" -ForegroundColor Yellow
            } else {
                New-ADOrganizationalUnit -Name $ouName -Path $parentPath -Description $desc -WhatIf:$false
                Write-Host "[OU] Created: $ouName" -ForegroundColor Green
            }
        }
    }
}

function Invoke-DeployGroups {
    param(
        [Parameter(Mandatory)]
        $UsersConfig,

        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    if (-not $UsersConfig.groups) {
        Write-Host "`n[3] No groups defined in users.json; skipping." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n[3] Deploying Security Groups..." -ForegroundColor Cyan

    foreach ($grp in $UsersConfig.groups) {
        $groupName  = $grp.name
        $groupScope = if ($grp.scope) { $grp.scope } else { "Global" }
        $groupCat   = if ($grp.category) { $grp.category } else { "Security" }
        $groupPath  = $grp.ou
        $desc       = $grp.description
        
        # Complete the OU path if it doesn't include domain components
        if ($groupPath -notmatch "DC=") {
            $groupPath = "$groupPath,$DomainDN"
        }

        try {
            $existingGroup = Get-ADGroup -Identity $groupName -ErrorAction Stop
            Write-Host "[Group] $groupName (already exists)" -ForegroundColor DarkGray
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][Group] Would create: $groupName in $groupPath" -ForegroundColor Yellow
            } else {
                New-ADGroup -Name $groupName `
                    -GroupScope $groupScope `
                    -GroupCategory $groupCat `
                    -Path $groupPath `
                    -Description $desc `
                    -WhatIf:$false
                Write-Host "[Group] Created: $groupName" -ForegroundColor Green
            }
        }
    }
}

function Invoke-DeployServices {
    param(
        [Parameter(Mandatory)]
        $ServicesConfig,

        [Parameter(Mandatory)]
        [string]$DomainFQDN
    )

    Write-Host "`n[4] Deploying Services (DNS, etc.)..." -ForegroundColor Cyan

    # --- DNS Zones ---
    if ($ServicesConfig.dns -and $ServicesConfig.dns.zones) {
        $dnsModuleAvailable = Get-Module -ListAvailable -Name DnsServer
        if (-not $dnsModuleAvailable) {
            Write-Warning "[DNS] DnsServer module not available; skipping DNS zones."
        }
        else {
            Import-Module DnsServer -ErrorAction SilentlyContinue

            foreach ($zone in $ServicesConfig.dns.zones) {
                $zoneName = $zone.name
                $zoneType = if ($zone.type) { $zone.type } else { "Primary" }
                
                # Replace __AD_DOMAIN__ placeholder with actual domain FQDN
                if ($zoneName -eq "__AD_DOMAIN__") {
                    $zoneName = $DomainFQDN
                }
                
                # Skip zones with null/empty names
                if ([string]::IsNullOrWhiteSpace($zoneName)) {
                    Write-Warning "[DNS Zone] Skipping zone with empty name"
                    continue
                }

                try {
                    $existingZone = Get-DnsServerZone -Name $zoneName -ErrorAction Stop
                    Write-Host "[DNS Zone] $zoneName (already exists)" -ForegroundColor DarkGray
                }
                catch {
                    if ($WhatIf) {
                        Write-Host "[WhatIf][DNS Zone] Would create: $zoneName ($zoneType)" -ForegroundColor Yellow
                    } else {
                        if ($zoneType -eq "Primary") {
                            Add-DnsServerPrimaryZone -Name $zoneName -ReplicationScope "Forest" -WhatIf:$false
                        }
                        elseif ($zoneType -eq "Reverse") {
                            Add-DnsServerPrimaryZone -NetworkId $zoneName -ReplicationScope "Forest" -WhatIf:$false
                        }
                        Write-Host "[DNS Zone] Created: $zoneName" -ForegroundColor Green
                    }
                }
            }
        }
    }

    # --- DNS Forwarders ---
    if ($ServicesConfig.dns -and $ServicesConfig.dns.forwarders) {
        if (-not (Get-Module -Name DnsServer)) {
            Write-Warning "[DNS Forwarders] DnsServer module not loaded; skipping."
        }
        else {
            foreach ($fwd in $ServicesConfig.dns.forwarders) {
                if ($WhatIf) {
                    Write-Host "[WhatIf][DNS Forwarder] Would add: $fwd" -ForegroundColor Yellow
                } else {
                    try {
                        Add-DnsServerForwarder -IPAddress $fwd -ErrorAction Stop
                        Write-Host "[DNS Forwarder] Added: $fwd" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "[DNS Forwarder] $fwd (may already exist or error)" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    # Placeholders for other services (not yet implemented):
    # - DHCP
    # - WINS
    # - Certificate Services
}

function Invoke-DeployGPOs {
    param(
        [Parameter(Mandatory)]
        $GpoConfig,

        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    if (-not $GpoConfig.gpos) {
        Write-Host "`n[5] No GPOs defined in gpo.json; skipping." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n[5] Deploying Group Policy Objects..." -ForegroundColor Cyan

    $gpModuleAvailable = Get-Module -ListAvailable -Name GroupPolicy
    if (-not $gpModuleAvailable) {
        Write-Warning "[GPO] GroupPolicy module not available; skipping GPO creation."
        return
    }

    Import-Module GroupPolicy -ErrorAction SilentlyContinue

    foreach ($gpo in $GpoConfig.gpos) {
        $gpoName = $gpo.name

        try {
            $existingGPO = Get-GPO -Name $gpoName -ErrorAction Stop
            Write-Host "[GPO] $gpoName (already exists)" -ForegroundColor DarkGray
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][GPO] Would create: $gpoName" -ForegroundColor Yellow
            } else {
                $newGPO = New-GPO -Name $gpoName -WhatIf:$false
                Write-Host "[GPO] Created: $gpoName" -ForegroundColor Green
            }
        }
    }

    # Link GPOs to OUs
    if ($GpoConfig.links) {
        foreach ($linkDef in $GpoConfig.links) {
            # Handle both naming conventions from gpo.json
            $gpoName   = if ($linkDef.gpoName) { $linkDef.gpoName } else { $linkDef.gpo }
            $targetOU  = if ($linkDef.targetOu) { $linkDef.targetOu } else { $linkDef.target }
            $enforced  = if ($linkDef.enforced) { "Yes" } else { "No" }
            
            # Complete the OU path if it doesn't include domain components
            if ($targetOU -notmatch "DC=") {
                $targetOU = "$targetOU,$DomainDN"
            }

            if ($WhatIf) {
                Write-Host "[WhatIf][GPO Link] Would link: $gpoName -> $targetOU (Enforced: $enforced)" -ForegroundColor Yellow
            } else {
                try {
                    New-GPLink -Name $gpoName -Target $targetOU -LinkEnabled Yes -Enforced $enforced -ErrorAction Stop -WhatIf:$false | Out-Null
                    Write-Host "[GPO Link] $gpoName -> $targetOU" -ForegroundColor Green
                }
                catch {
                    Write-Host "[GPO Link] $gpoName -> $targetOU (may already be linked)" -ForegroundColor DarkGray
                }
            }
        }
    }
}

function Invoke-DeployComputers {
    <#
    .SYNOPSIS
        Creates/updates computer objects with optional hardware metadata.
    
    .DESCRIPTION
        v2.1 Enhancement: Stores hardware info (manufacturer, model, service_tag)
        as JSON in the "info" attribute. Updates existing computers if hardware
        data has changed.
    #>
    param(
        [Parameter(Mandatory)]
        $ComputersConfig,

        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    if (-not $ComputersConfig.computers) {
        Write-Host "`n[6] No computers defined in computers.json; skipping." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n[6] Deploying Computer Accounts..." -ForegroundColor Cyan

    foreach ($comp in $ComputersConfig.computers) {
        $compName = $comp.name
        $compPath = $comp.ou
        $compDesc = $comp.description
        
        # Complete the OU path if it doesn't include domain components
        if ($compPath -notmatch "DC=") {
            $compPath = "$compPath,$DomainDN"
        }
        
        # NEW v2.1: Extract hardware fields if present
        $manufacturer = if ($comp.manufacturer) { $comp.manufacturer } else { "" }
        $model        = if ($comp.model) { $comp.model } else { "" }
        $serviceTag   = if ($comp.service_tag) { $comp.service_tag } else { "" }
        
        # Build hardware JSON using renamed function
        $hardwareJSON = New-HardwareInfoJSON -Manufacturer $manufacturer -Model $model -ServiceTag $serviceTag

        try {
            $existingComp = Get-ADComputer -Identity $compName -Properties info -ErrorAction Stop
            
            # NEW v2.1: Check if hardware info needs updating
            $needsUpdate = $false
            if (-not [string]::IsNullOrWhiteSpace($hardwareJSON)) {
                if ($existingComp.info -ne $hardwareJSON) {
                    $needsUpdate = $true
                }
            }
            
            if ($needsUpdate -and -not $WhatIf) {
                Set-ADComputer -Identity $compName -Replace @{info=$hardwareJSON} -WhatIf:$false
                Write-Host "[Computer] $compName (updated hardware info)" -ForegroundColor Yellow
                
                # Display hardware details
                if (-not [string]::IsNullOrWhiteSpace($hardwareJSON)) {
                    $hwDisplay = if ($manufacturer -or $model -or $serviceTag) {
                        "$manufacturer $model [$serviceTag]".Trim()
                    } else { "" }
                    if ($hwDisplay) {
                        Write-Host "           Hardware: $hwDisplay" -ForegroundColor DarkGreen
                    }
                }
            }
            else {
                Write-Host "[Computer] $compName (already exists)" -ForegroundColor DarkGray
            }
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][Computer] Would create: $compName in $compPath" -ForegroundColor Yellow
                if (-not [string]::IsNullOrWhiteSpace($hardwareJSON)) {
                    $hwDisplay = "$manufacturer $model [$serviceTag]".Trim()
                    Write-Host "              Hardware: $hwDisplay" -ForegroundColor Yellow
                }
            } else {
                $computerParams = @{
                    Name        = $compName
                    Path        = $compPath
                    Description = $compDesc
                    Enabled     = $true
                    WhatIf      = $false
                }
                
                # Add hardware info if present
                if (-not [string]::IsNullOrWhiteSpace($hardwareJSON)) {
                    $computerParams["OtherAttributes"] = @{info = $hardwareJSON}
                }
                
                New-ADComputer @computerParams
                Write-Host "[Computer] Created: $compName" -ForegroundColor Green
                
                # Display hardware details
                if (-not [string]::IsNullOrWhiteSpace($hardwareJSON)) {
                    $hwDisplay = "$manufacturer $model [$serviceTag]".Trim()
                    Write-Host "           Hardware: $hwDisplay" -ForegroundColor DarkGreen
                }
            }
        }
    }
}

function Invoke-DeployUsers {
    param(
        [Parameter(Mandatory)]
        $UsersConfig,

        [Parameter(Mandatory)]
        [string]$DomainFQDN,

        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    if (-not $UsersConfig.users) {
        Write-Host "`n[7] No users defined in users.json; skipping." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n[7] Deploying User Accounts..." -ForegroundColor Cyan

    foreach ($usr in $UsersConfig.users) {
        $samAccountName = $usr.samAccountName
        $givenName      = $usr.givenName
        $surname        = $usr.surname
        $displayName    = "$givenName $surname"
        $upn            = "$samAccountName@$DomainFQDN"
        $userPath       = $usr.ou
        $title          = $usr.title
        $department     = $usr.department
        $company        = $usr.company
        
        # Complete the OU path if it doesn't include domain components
        if ($userPath -notmatch "DC=") {
            $userPath = "$userPath,$DomainDN"
        }

        # Optional attributes
        $office         = $usr.office
        $phone          = $usr.telephoneNumber
        $email          = $usr.mail
        $streetAddress  = $usr.streetAddress
        $city           = $usr.city
        $state          = $usr.state
        $postalCode     = $usr.postalCode
        $country        = $usr.country

        try {
            $existingUser = Get-ADUser -Identity $samAccountName -ErrorAction Stop
            Write-Host "[User] $samAccountName (already exists)" -ForegroundColor DarkGray
        }
        catch {
            if ($WhatIf) {
                Write-Host "[WhatIf][User] Would create: $samAccountName" -ForegroundColor Yellow
            } else {
                $userParams = @{
                    SamAccountName    = $samAccountName
                    UserPrincipalName = $upn
                    GivenName         = $givenName
                    Surname           = $surname
                    DisplayName       = $displayName
                    Name              = $displayName
                    Path              = $userPath
                    Enabled           = $true
                    AccountPassword   = (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force)
                    ChangePasswordAtLogon = $true
                    WhatIf            = $false
                }

                if ($title)   { $userParams["Title"] = $title }
                if ($department) { $userParams["Department"] = $department }
                if ($company) { $userParams["Company"] = $company }
                if ($office)  { $userParams["Office"] = $office }
                if ($phone)   { $userParams["OfficePhone"] = $phone }
                if ($email)   { $userParams["EmailAddress"] = $email }
                if ($streetAddress) { $userParams["StreetAddress"] = $streetAddress }
                if ($city)    { $userParams["City"] = $city }
                if ($state)   { $userParams["State"] = $state }
                if ($postalCode) { $userParams["PostalCode"] = $postalCode }
                if ($country) { $userParams["Country"] = $country }

                New-ADUser @userParams
                Write-Host "[User] Created: $samAccountName ($displayName)" -ForegroundColor Green
            }
        }

        # Add to groups
        if ($usr.memberOf -and $usr.memberOf.Count -gt 0) {
            foreach ($groupName in $usr.memberOf) {
                if ($WhatIf) {
                    Write-Host "[WhatIf][User Group] Would add $samAccountName -> $groupName" -ForegroundColor Yellow
                } else {
                    try {
                        Add-ADGroupMember -Identity $groupName -Members $samAccountName -ErrorAction Stop -WhatIf:$false
                        Write-Host "[User Group] Added: $samAccountName -> $groupName" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "[User Group] $samAccountName -> $groupName (may already be member)" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }
}

# =============================================================================
# Main execution
# =============================================================================

try {
    $structureConfig = Get-JsonConfig -FileName "structure.json"
    $servicesConfig  = Get-JsonConfig -FileName "services.json"
    $usersConfig     = Get-JsonConfig -FileName "users.json"
    $computersConfig = Get-JsonConfig -FileName "computers.json"
    $gpoConfig       = Get-JsonConfig -FileName "gpo.json"

    Invoke-DeploySitesAndOUs  -StructureConfig $structureConfig -DomainDN $DomainDN
    Invoke-DeployGroups       -UsersConfig $usersConfig   -DomainDN $DomainDN
    Invoke-DeployServices     -ServicesConfig $servicesConfig -DomainFQDN $DomainFQDN
    Invoke-DeployGPOs         -GpoConfig $gpoConfig       -DomainDN $DomainDN
    Invoke-DeployComputers    -ComputersConfig $computersConfig -DomainDN $DomainDN
    Invoke-DeployUsers        -UsersConfig $usersConfig   -DomainFQDN $DomainFQDN -DomainDN $DomainDN

    Write-Host "`n=====================================================" -ForegroundColor Green
    Write-Host "  Deployment complete for exercise '$ExerciseName'" -ForegroundColor Green
    Write-Host "  Hardware info stored in computer 'info' attributes" -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green
}
catch {
    Write-Error $_
    exit 1
}

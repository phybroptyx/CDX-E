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
        * Instructs you to reboot and rerun to apply the exercise config.

.NOTES
    - Run as a local admin (pre-forest) or Domain Admin (post-forest).
    - Designed for Windows Server 2012 R2 and later.
    
.VERSION
    2.1 - Hardware Info Enhancement
    - Modified Invoke-DeployComputers to store hardware metadata
    - Added Build-HardwareInfoJSON helper function
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
    [switch]$WhatIf
)

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "           Active Directory Deployment Engine        " -ForegroundColor Cyan
Write-Host "                Hardware Info Enhanced v2.1          " -ForegroundColor Cyan
Write-Host "=====================================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Resolve config path based on exercise layout
# ---------------------------------------------------------------------------
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
Write-Host "Config Path    : $ConfigPath`n"

# Make sure structure.json exists before we try to load it
$structurePath = Join-Path $ConfigPath "structure.json"
if (-not (Test-Path $structurePath)) {
    throw "structure.json not found at expected path: $structurePath. Run with -GenerateStructure or create it manually."
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
function Test-Prerequisites {
    Write-Host "[Prereq] Checking environment..." -ForegroundColor Cyan

    # Basic OS hint
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.ProductType -eq 1) {
            Write-Warning "This appears to be a client OS (e.g., Windows 10/11). AD DS deployment typically runs on Windows Server."
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

# ---------------------------------------------------------------------------
# Helper: Load JSON config from the exercise folder
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Ensure domain exists: either detect or create a new forest
# ---------------------------------------------------------------------------
function Ensure-ActiveDirectoryDomain {
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

    # ===== NEW FOREST CREATION =====
    Write-Host "`n=== MODE: NEW FOREST CREATION ===`n" -ForegroundColor Magenta

    # Check if AD DS role is installed; if not, install it
    if (-not (Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue | Where-Object Installed)) {
        Write-Host "[Domain] AD DS role not installed. Installing now (this may take a few minutes)..." -ForegroundColor Yellow
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
        Write-Host "[Domain] AD DS role installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "[Domain] AD DS role is already installed." -ForegroundColor DarkGreen
    }

    Import-Module ADDSDeployment -ErrorAction Stop | Out-Null

    # Prompt for domain details
    if (-not $DomainFQDNParam) {
        $DomainFQDNParam = Read-Host "Enter domain FQDN (e.g., stark.local)"
    }

    if (-not $DomainDNParam) {
        $parts = $DomainFQDNParam -split '\.'
        $DomainDNParam = ($parts | ForEach-Object { "DC=$_" }) -join ','
    }

    $netbios = Read-Host "Enter NetBIOS domain name (e.g., STARK)"
    Write-Host "`nYou will now set the DSRM password (used for Directory Services Restore Mode)." -ForegroundColor Cyan
    $dsrmPassword = Read-Host -AsSecureString -Prompt "DSRM password"

    if ($WhatIf) {
        Write-Host "[WhatIf] Would create new AD forest with:" -ForegroundColor Yellow
        Write-Host "  DomainFQDN : $DomainFQDNParam"
        Write-Host "  DomainDN   : $DomainDNParam"
        Write-Host "  NetBIOS    : $netbios"
        Write-Host "  (Forest creation requires reboot; no further config would run until rerun.)"
        return @{
            DomainFQDN = $DomainFQDNParam
            DomainDN   = $DomainDNParam
            CreatedNew = $true
        }
    }

    Write-Host "`n[Domain] Creating new AD forest '$DomainFQDNParam' on this server..." -ForegroundColor Green

    $splat = @{
        DomainName                    = $DomainFQDNParam
        DomainNetbiosName             = $netbios
        SafeModeAdministratorPassword = $dsrmPassword
        InstallDNS                    = $true
        Force                         = $true
        NoRebootOnCompletion          = $true
    }

    Install-ADDSForest @splat

    Write-Host "`n[Domain] New forest created. You MUST reboot this server before continuing." -ForegroundColor Yellow
    Write-Host "After reboot, rerun this script to apply the exercise configuration." -ForegroundColor Yellow

    return @{
        DomainFQDN = $DomainFQDNParam
        DomainDN   = $DomainDNParam
        CreatedNew = $true
    }
}

# --- Domain handling ---
$domainInfo = Ensure-ActiveDirectoryDomain -DomainFQDNParam $DomainFQDN -DomainDNParam $DomainDN
$DomainFQDN = $domainInfo.DomainFQDN
$DomainDN   = $domainInfo.DomainDN

Write-Host "`nUsing domain: FQDN = $DomainFQDN; DN = $DomainDN`n" -ForegroundColor Cyan

# If we just created a new forest in this run (and not in -WhatIf), stop here.
if ($domainInfo.CreatedNew -and -not $WhatIf) {
    Write-Host "`n[Domain] Forest creation completed. Please reboot this server, then rerun ad_deploy.ps1 for '$ExerciseName' to continue with Sites/OUs/etc." -ForegroundColor Yellow
    return
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
    foreach ($site in $StructureConfig.sites) {
        $name = $site.name
        $desc = $site.description

        # Does the target site already exist?
        $existingSite = Get-ADReplicationSite -Filter "Name -eq '$name'" -ErrorAction SilentlyContinue
        if ($existingSite) {
            Write-Host "Site exists: $name" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating site: $name" -ForegroundColor Green
            New-ADReplicationSite -Name $name -Description $desc -WhatIf:$WhatIf | Out-Null
        }
    }

    # --- Subnets ---
    foreach ($subnet in $StructureConfig.subnets) {
        $cidr = $subnet.cidr
        $siteName = $subnet.site
        $desc = $subnet.description

        $existingSubnet = Get-ADReplicationSubnet -Filter "Name -eq '$cidr'" -ErrorAction SilentlyContinue
        if ($existingSubnet) {
            Write-Host "Subnet exists: $cidr -> $siteName" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating subnet: $cidr -> $siteName" -ForegroundColor Green
            New-ADReplicationSubnet -Name $cidr -Site $siteName -Description $desc -WhatIf:$WhatIf | Out-Null
        }
    }

    # --- Site Links ---
    foreach ($link in $StructureConfig.sitelinks) {
        $linkName = $link.name
        $sites = $link.sites
        $cost = $link.cost
        $interval = $link.replicationInterval

        $existingLink = Get-ADReplicationSiteLink -Filter "Name -eq '$linkName'" -ErrorAction SilentlyContinue
        if ($existingLink) {
            Write-Host "Site link exists: $linkName" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating site link: $linkName (Cost: $cost, Interval: $interval min)" -ForegroundColor Green
            New-ADReplicationSiteLink -Name $linkName `
                                      -SitesIncluded $sites `
                                      -Cost $cost `
                                      -ReplicationFrequencyInMinutes $interval `
                                      -WhatIf:$WhatIf | Out-Null
        }
    }

    # Optionally remove the auto-created DEFAULTIPSITELINK if it exists and is not referenced
    try {
        $defaultLink = Get-ADReplicationSiteLink -Filter "Name -eq 'DEFAULTIPSITELINK'" -ErrorAction SilentlyContinue
        if ($defaultLink) {
            $linkedSites = $defaultLink.SitesIncluded
            if ($linkedSites.Count -eq 0) {
                Write-Host "Removing unused DEFAULTIPSITELINK..." -ForegroundColor Yellow
                Remove-ADReplicationSiteLink -Identity "DEFAULTIPSITELINK" -Confirm:$false -WhatIf:$WhatIf
            }
            else {
                Write-Host "DEFAULTIPSITELINK has linked sites; not removing." -ForegroundColor DarkGray
            }
        }
    }
    catch {
        Write-Warning "Failed to evaluate or remove DEFAULTIPSITELINK: $_"
    }

    # --- OUs ---
    Write-Host "`n[2] Creating Organizational Units..." -ForegroundColor Cyan

    # Your structure.json OUs look like:
    # { "name": "Sites", "parent_dn": "", "description": "..." }
    # { "name": "HQ", "parent_dn": "OU=Sites", "description": "..." }
    # etc.

    # Sort so that parents are created before children, based on parent_dn depth
    $sortedOUs = $StructureConfig.ous | Sort-Object {
        if ([string]::IsNullOrWhiteSpace($_.parent_dn)) {
            0
        }
        else {
            ([regex]::Matches($_.parent_dn, 'OU=').Count)
        }
    }

    foreach ($ou in $sortedOUs) {
        $name     = $ou.name
        $parentDn = $ou.parent_dn
        $desc     = $ou.description

        # Build full parent path:
        #  - If parent_dn is empty/null => directly under the domain
        #  - Otherwise treat parent_dn as a relative OU chain and append DomainDN
        if ([string]::IsNullOrWhiteSpace($parentDn)) {
            $parentPath = $DomainDN
        }
        else {
            $parentPath = "$parentDn,$DomainDN"
        }

        $dn = "OU=$name,$parentPath"

        $existing = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$dn)" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "OU exists: $dn" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating OU: $dn" -ForegroundColor Green
            New-ADOrganizationalUnit -Name $name `
                                     -Path $parentPath `
                                     -Description $desc `
                                     -ProtectedFromAccidentalDeletion $false `
                                     -WhatIf:$WhatIf | Out-Null
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

    Write-Host "`n[3] Creating Groups..." -ForegroundColor Cyan

    foreach ($group in $UsersConfig.groups) {
        $sam   = $group.sAMAccountName
        $name  = $group.name
        $scope = $group.scope
        $cat   = $group.category
        $desc  = $group.description
        $ou    = $group.ou

        $path  = "$ou,$DomainDN"

        $existing = Get-ADGroup -Filter "sAMAccountName -eq '$sam'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Group exists: $sam" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating group: $sam in $path" -ForegroundColor Green
            New-ADGroup -Name $name `
                        -SamAccountName $sam `
                        -GroupCategory $cat `
                        -GroupScope $scope `
                        -Path $path `
                        -Description $desc `
                        -WhatIf:$WhatIf | Out-Null
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

    Write-Host "`n[4] Configuring Services (DNS)..." -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name DnsServer)) {
        Write-Warning "DnsServer module not available; skipping DNS configuration."
        return
    }

    Import-Module DnsServer -ErrorAction SilentlyContinue | Out-Null

    # DNS Zones
    if ($ServicesConfig.dns -and $ServicesConfig.dns.zones) {
        foreach ($zone in $ServicesConfig.dns.zones) {

            # Allow domain-agnostic placeholder in JSON
            $rawName = $zone.name
            if ($rawName -eq "__AD_DOMAIN__") {
                $name = $DomainFQDN
            }
            else {
                $name = $rawName
            }

            $scope = $zone.replicationScope

            $existingZone = Get-DnsServerZone -Name $name -ErrorAction SilentlyContinue
            if ($existingZone) {
                Write-Host "DNS zone exists: $name" -ForegroundColor DarkGray
            }
            else {
                Write-Host "Creating DNS zone: $name" -ForegroundColor Green
                Add-DnsServerPrimaryZone -Name $name -ReplicationScope $scope -WhatIf:$WhatIf | Out-Null
            }
        }
    }

    # DNS Forwarders
    if ($ServicesConfig.dns -and $ServicesConfig.dns.forwarders) {
        $currentForwarders = @()
        try {
            $currentForwarders = (Get-DnsServerForwarder -ErrorAction SilentlyContinue).IPAddress
        } catch {}

        foreach ($fwd in $ServicesConfig.dns.forwarders) {
            if ($currentForwarders -and $currentForwarders -contains $fwd) {
                Write-Host "DNS forwarder exists: $fwd" -ForegroundColor DarkGray
            }
            else {
                Write-Host "Adding DNS forwarder: $fwd" -ForegroundColor Green
                Add-DnsServerForwarder -IPAddress $fwd -ErrorAction SilentlyContinue -WhatIf:$WhatIf | Out-Null
            }
        }
    }
}

function Invoke-DeployGPOs {
    param(
        [Parameter(Mandatory)]
        $GpoConfig,
        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    Write-Host "`n[5] Creating GPOs and Linking..." -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
        Write-Warning "GroupPolicy module not available; skipping GPO configuration."
        return
    }

    Import-Module GroupPolicy -ErrorAction SilentlyContinue | Out-Null

    # Create GPOs
    foreach ($gpo in $GpoConfig.gpos) {
        $gpoName = $gpo.name
        $gpoDesc = $gpo.description

        $existingGpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
        if ($existingGpo) {
            Write-Host "GPO exists: $gpoName" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating GPO: $gpoName" -ForegroundColor Green
            New-GPO -Name $gpoName -Comment $gpoDesc -WhatIf:$WhatIf | Out-Null
        }
    }

    # Link GPOs to target OUs
    foreach ($link in $GpoConfig.links) {
        $gpoName   = $link.gpoName
        $targetOu  = $link.targetOu
        $enforced  = $link.enforced
        $enabled   = $link.enabled

        $targetDn = "$targetOu,$DomainDN"

        $enforcedValue = if ($enforced) { "Yes" } else { "No" }
        $enabledValue  = if ($enabled) { "Yes" } else { "No" }

        $existingLink = Get-GPInheritance -Target $targetDn -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty GpoLinks -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -eq $gpoName }

        if ($existingLink) {
            Write-Host "GPO link exists: $gpoName -> $targetDn" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Linking GPO: $gpoName -> $targetDn" -ForegroundColor Yellow
            if ($WhatIf) {
                Write-Host "[WhatIf] Would link GPO: $gpoName to $targetDn (Enforced: $enforcedValue, Enabled: $enabledValue)" -ForegroundColor Yellow
            }
            else {
                New-GPLink -Name $gpoName `
                           -Target $targetDn `
                           -Enforced $enforcedValue `
                           -LinkEnabled $enabledValue | Out-Null
            }
        }
    }
}

# =============================================================================
# MODIFIED FUNCTION: Invoke-DeployComputers
# Hardware Attributes Storage: JSON in "info" attribute
# =============================================================================

<#
.SYNOPSIS
    Modified computer deployment function that stores hardware metadata in the 
    "info" attribute as JSON.

.DESCRIPTION
    This modified version of Invoke-DeployComputers stores manufacturer, model, 
    and service tag information in the computer object's "info" attribute as 
    JSON-encoded data. This approach:
    
    - Uses existing AD schema (no extensions needed)
    - Avoids Exchange extensionAttribute conflicts
    - Stores all hardware data in single field
    - Is fully reversible and Exchange-safe
    
.NOTES
    Version 2.1 - Hardware Info Enhancement
    Integrated: 2025-11-28
#>

function Invoke-DeployComputers {
    param(
        [Parameter(Mandatory)]
        $ComputersConfig,
        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    Write-Host "`n[6] Creating Computer Accounts..." -ForegroundColor Cyan

    foreach ($comp in $ComputersConfig.computers) {
        $name = $comp.name
        $ou   = $comp.ou
        $desc = $comp.description

        $path = "$ou,$DomainDN"

        # Check if computer already exists
        $existing = Get-ADComputer -Filter "Name -eq '$name'" -Properties info -ErrorAction SilentlyContinue
        
        if ($existing) {
            Write-Host "Computer exists: $name" -ForegroundColor DarkGray
            
            # Optional: Update hardware info if it exists and has changed
            if ($comp.manufacturer -or $comp.model -or $comp.service_tag) {
                $newHardwareData = Build-HardwareInfoJSON -Computer $comp
                
                # Only update if hardware data has changed
                if ($existing.info -ne $newHardwareData) {
                    Write-Host "  Updating hardware info for: $name" -ForegroundColor Yellow
                    Set-ADComputer -Identity $existing.DistinguishedName `
                                   -Replace @{info = $newHardwareData} `
                                   -WhatIf:$WhatIf
                }
            }
        }
        else {
            Write-Host "Creating computer: $name in $path" -ForegroundColor Green
            
            # Build hardware info JSON if data is available
            $otherAttributes = @{}
            
            if ($comp.manufacturer -or $comp.model -or $comp.service_tag) {
                $hardwareInfo = Build-HardwareInfoJSON -Computer $comp
                $otherAttributes['info'] = $hardwareInfo
                
                Write-Host "  + Hardware: $($comp.manufacturer) $($comp.model) [$($comp.service_tag)]" `
                    -ForegroundColor DarkGreen
            }
            
            # Create computer with hardware info
            New-ADComputer -Name $name `
                           -Path $path `
                           -Description $desc `
                           -OtherAttributes $otherAttributes `
                           -WhatIf:$WhatIf | Out-Null
        }
    }
}

# =============================================================================
# HELPER FUNCTIONS FOR HARDWARE INFO
# =============================================================================

<#
.SYNOPSIS
    Helper function to build JSON-encoded hardware information string.

.DESCRIPTION
    Creates a compact JSON string containing manufacturer, model, and service tag.
    Only includes fields that have values (omits null/empty).
#>
function Build-HardwareInfoJSON {
    param(
        [Parameter(Mandatory)]
        $Computer
    )
    
    # Build hashtable with only non-empty values
    $hardwareData = [ordered]@{}
    
    if (-not [string]::IsNullOrWhiteSpace($Computer.manufacturer)) {
        $hardwareData['manufacturer'] = $Computer.manufacturer
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Computer.model)) {
        $hardwareData['model'] = $Computer.model
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Computer.service_tag)) {
        $hardwareData['serviceTag'] = $Computer.service_tag
    }
    
    # Return null if no hardware data
    if ($hardwareData.Count -eq 0) {
        return $null
    }
    
    # Convert to compact JSON (single line, no formatting)
    return ($hardwareData | ConvertTo-Json -Compress -Depth 2)
}

<#
.SYNOPSIS
    Helper function to retrieve hardware information from a computer object.

.DESCRIPTION
    Reads the "info" attribute from an AD computer object and parses the JSON
    to extract hardware details.

.EXAMPLE
    $computer = Get-ADComputer "HQ-IT-WS001" -Properties info
    $hardware = Get-HardwareInfo -Computer $computer
    Write-Host "Model: $($hardware.model)"
#>
function Get-HardwareInfo {
    param(
        [Parameter(Mandatory)]
        [Microsoft.ActiveDirectory.Management.ADComputer]$Computer
    )
    
    if ([string]::IsNullOrWhiteSpace($Computer.info)) {
        return $null
    }
    
    try {
        # Parse JSON from info attribute
        $hardwareData = $Computer.info | ConvertFrom-Json
        return $hardwareData
    }
    catch {
        Write-Warning "Failed to parse hardware info for $($Computer.Name): $_"
        return $null
    }
}

# =============================================================================
# USER DEPLOYMENT FUNCTION
# =============================================================================

function Invoke-DeployUsers {
    param(
        [Parameter(Mandatory)]
        $UsersConfig,
        [Parameter(Mandatory)]
        [string]$DomainFQDN,
        [Parameter(Mandatory)]
        [string]$DomainDN
    )

    Write-Host "`n[7] Creating User Accounts..." -ForegroundColor Cyan

    foreach ($user in $UsersConfig.users) {
        $sam       = $user.sAMAccountName
        $numericId = $user.numericId
        $given     = $user.givenName
        $sn        = $user.sn
        $middle    = $user.initials
        $display   = $user.displayName
        $title     = $user.title

        $street    = $user.streetAddress
        $city      = $user.city
        $state     = $user.state
        $postal    = $user.postalCode
        $country   = $user.country
        $phone     = $user.telephoneNumber

        $ou        = $user.ou
        $dept      = $user.department

        $path = "$ou,$DomainDN"
        $upn  = "$sam@$DomainFQDN"

        # Generate a default password based on numeric ID or use a fixed password
        $defaultPassword = "Password$numericId"
        $securePassword  = ConvertTo-SecureString -String $defaultPassword -AsPlainText -Force

        $existing = Get-ADUser -Filter "sAMAccountName -eq '$sam'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "User exists: $sam" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating user: $sam ($display)" -ForegroundColor Green

            $userParams = @{
                Name                  = $display
                SamAccountName        = $sam
                UserPrincipalName     = $upn
                GivenName             = $given
                Surname               = $sn
                Initials              = $middle
                DisplayName           = $display
                Title                 = $title
                Department            = $dept
                StreetAddress         = $street
                City                  = $city
                State                 = $state
                PostalCode            = $postal
                Country               = $country
                OfficePhone           = $phone
                Path                  = $path
                AccountPassword       = $securePassword
                Enabled               = $true
                ChangePasswordAtLogon = $true
            }

            New-ADUser @userParams -WhatIf:$WhatIf | Out-Null
        }
    }

    # Group memberships
    Write-Host "`n[8] Assigning Group Memberships..." -ForegroundColor Cyan

    foreach ($user in $UsersConfig.users) {
        $sam = $user.sAMAccountName
        $memberOf = $user.memberOf

        if (-not $memberOf -or $memberOf.Count -eq 0) {
            continue
        }

        $userObj = Get-ADUser -Filter "sAMAccountName -eq '$sam'" -ErrorAction SilentlyContinue
        if (-not $userObj) {
            Write-Warning "User not found for group membership: $sam"
            continue
        }

        foreach ($groupSam in $memberOf) {
            $groupObj = Get-ADGroup -Filter "sAMAccountName -eq '$groupSam'" -ErrorAction SilentlyContinue
            if (-not $groupObj) {
                Write-Warning "Group not found for membership: $sam -> $groupSam"
                continue
            }

            $isMember = Get-ADGroupMember -Identity $groupObj.DistinguishedName -Recursive |
                        Where-Object { $_.DistinguishedName -eq $userObj.DistinguishedName }

            if ($isMember) {
                Write-Host "Membership already present: $sam -> $groupSam" -ForegroundColor DarkGray
            }
            else {
                Write-Host "Adding membership: $sam -> $groupSam" -ForegroundColor Green
                Add-ADGroupMember -Identity $groupObj.DistinguishedName `
                                  -Members $userObj.DistinguishedName `
                                  -ErrorAction SilentlyContinue `
                                  -WhatIf:$WhatIf
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

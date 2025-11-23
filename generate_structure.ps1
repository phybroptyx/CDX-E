<#
.SYNOPSIS
    Generate structure.json from exercise_template.json

.DESCRIPTION
    Reads an exercise-specific template file and generates the complete
    AD structure configuration (sites, subnets, site links, OUs) for
    deployment by ad_deploy.ps1.

.PARAMETER ExercisesRoot
    Root directory containing exercise folders (default: .\EXERCISES)

.PARAMETER ExerciseName
    Name of the exercise (e.g., CHILLED_ROCKET)

.PARAMETER TemplateFileName
    Name of the template file to read (default: exercise_template.json)

.PARAMETER OutputFileName
    Name of the output file to create (default: structure.json)

.PARAMETER Force
    Overwrite existing structure.json without prompting

.NOTES
    This script is called by ad_deploy.ps1 with -GenerateStructure flag,
    or can be run standalone to regenerate structure files.
#>

[CmdletBinding()]
param(
    [string]$ExercisesRoot = ".\EXERCISES",
    
    [Parameter(Mandatory)]
    [string]$ExerciseName,
    
    [string]$TemplateFileName = "exercise_template.json",
    
    [string]$OutputFileName = "structure.json",
    
    [switch]$Force
)

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "     Structure Generator - Template Processor       " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$exercisePath = Join-Path -Path $ExercisesRoot -ChildPath $ExerciseName
if (-not (Test-Path $exercisePath)) {
    Write-Host "[Generator] Creating exercise folder: $exercisePath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $exercisePath -Force | Out-Null
}

$templatePath = Join-Path -Path $exercisePath -ChildPath $TemplateFileName
$outputPath   = Join-Path -Path $exercisePath -ChildPath $OutputFileName

Write-Host "Exercise Path : $exercisePath"
Write-Host "Template File : $TemplateFileName"
Write-Host "Output File   : $OutputFileName"
Write-Host ""

# ---------------------------------------------------------------------------
# Validate template exists
# ---------------------------------------------------------------------------
if (-not (Test-Path $templatePath)) {
    throw "Template file not found: $templatePath`n`nPlease create an exercise_template.json file for this exercise."
}

# ---------------------------------------------------------------------------
# Check if output already exists
# ---------------------------------------------------------------------------
if ((Test-Path $outputPath) -and -not $Force) {
    $overwrite = Read-Host "Output file already exists. Overwrite? (Y/N)"
    if ($overwrite -notin @("Y", "y", "Yes", "YES")) {
        Write-Host "[Generator] Aborted by user." -ForegroundColor Yellow
        return
    }
}

# ---------------------------------------------------------------------------
# Load and parse template
# ---------------------------------------------------------------------------
Write-Host "[Generator] Loading template from: $templatePath" -ForegroundColor Cyan

try {
    $template = Get-Content -Path $templatePath -Raw | ConvertFrom-Json
}
catch {
    throw "Failed to parse template JSON: $_"
}

Write-Host "[Generator] Template loaded: $($template._meta.exerciseName)" -ForegroundColor Green
Write-Host "              Description: $($template._meta.description)" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# Build Sites array
# ---------------------------------------------------------------------------
Write-Host "[Generator] Processing sites..." -ForegroundColor Cyan

$sites = @()
foreach ($site in $template.sites) {
    $sites += @{
        name        = $site.name
        description = $site.description
    }
    Write-Host "  + Site: $($site.name)" -ForegroundColor DarkGreen
}

# ---------------------------------------------------------------------------
# Build Subnets array
# ---------------------------------------------------------------------------
Write-Host "`n[Generator] Processing subnets..." -ForegroundColor Cyan

$subnets = @()
foreach ($site in $template.sites) {
    if ($template.advancedOptions.createSiteSubnets -eq $false) {
        Write-Host "  [Skipped] Subnet creation disabled in template" -ForegroundColor DarkGray
        break
    }
    
    $subnets += @{
        cidr     = $site.subnet.cidr
        site     = $site.name
        location = $site.subnet.location
    }
    Write-Host "  + Subnet: $($site.subnet.cidr) -> $($site.name)" -ForegroundColor DarkGreen
}

# ---------------------------------------------------------------------------
# Build Site Links array
# ---------------------------------------------------------------------------
Write-Host "`n[Generator] Processing site links..." -ForegroundColor Cyan

$sitelinks = @()
foreach ($link in $template.siteLinks) {
    if ($template.advancedOptions.createSiteLinks -eq $false) {
        Write-Host "  [Skipped] Site link creation disabled in template" -ForegroundColor DarkGray
        break
    }
    
    $sitelinks += @{
        name                    = $link.name
        sites                   = @($link.sites)
        cost                    = $link.cost
        replicationIntervalMins = $link.replicationIntervalMins
    }
    Write-Host "  + Link: $($link.name) [Cost: $($link.cost), Sites: $($link.sites.Count)]" -ForegroundColor DarkGreen
}

# ---------------------------------------------------------------------------
# Build OU hierarchy
# ---------------------------------------------------------------------------
Write-Host "`n[Generator] Building OU hierarchy..." -ForegroundColor Cyan

$ous = @()
$orgStructure = $template.organizationalStructure

# Root "Sites" OU (or custom name from template)
$rootOUName = $orgStructure.rootOU
$rootOUDesc = $orgStructure.rootOUDescription

$ous += [pscustomobject]@{
    name        = $rootOUName
    parent_dn   = ""
    description = $rootOUDesc
}
Write-Host "  + Root OU: $rootOUName" -ForegroundColor DarkGreen

# Process each site mapping
foreach ($siteKey in $orgStructure.siteMappings.PSObject.Properties.Name) {
    $siteMapping = $orgStructure.siteMappings.$siteKey
    
    Write-Host "`n  Processing Site: $siteKey" -ForegroundColor Cyan
    
    # Site OU under root
    $ous += [pscustomobject]@{
        name        = $siteKey
        parent_dn   = "OU=$rootOUName"
        description = "$siteKey site OU (linked to $($siteMapping.siteName))"
    }
    Write-Host "    + OU: $siteKey" -ForegroundColor DarkGreen
    
    # Department OUs under each site
    foreach ($dept in $siteMapping.departments) {
        $deptParentDn = "OU=$siteKey,OU=$rootOUName"
        
        $ous += [pscustomobject]@{
            name        = $dept
            parent_dn   = $deptParentDn
            description = "$dept department at $siteKey"
        }
        Write-Host "      + Dept: $dept" -ForegroundColor DarkGreen
        
        # Sub-OUs under each department
        foreach ($subOU in $orgStructure.departmentSubOUs) {
            $ous += [pscustomobject]@{
                name        = $subOU
                parent_dn   = "OU=$dept,$deptParentDn"
                description = "$subOU for $dept at $siteKey"
            }
            Write-Host "        - SubOU: $subOU" -ForegroundColor DarkGray
        }
    }
}

# ---------------------------------------------------------------------------
# Assemble final structure object
# ---------------------------------------------------------------------------
Write-Host "`n[Generator] Assembling structure object..." -ForegroundColor Cyan

$structure = [ordered]@{
    _generated = @{
        timestamp    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        exerciseName = $ExerciseName
        templateFile = $TemplateFileName
        generator    = "generate_structure.ps1 v2.0"
    }
    sites      = $sites
    subnets    = $subnets
    sitelinks  = $sitelinks
    ous        = $ous
}

# ---------------------------------------------------------------------------
# Write output JSON
# ---------------------------------------------------------------------------
Write-Host "[Generator] Writing structure.json to: $outputPath" -ForegroundColor Cyan

try {
    $structure | ConvertTo-Json -Depth 8 | Set-Content -Path $outputPath -Encoding UTF8
    Write-Host "[Generator] ✓ Structure file generated successfully!" -ForegroundColor Green
}
catch {
    throw "Failed to write output file: $_"
}

# ---------------------------------------------------------------------------
# Summary report
# ---------------------------------------------------------------------------
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "                  Generation Summary                 " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Sites      : $($sites.Count)" -ForegroundColor White
Write-Host "Subnets    : $($subnets.Count)" -ForegroundColor White
Write-Host "Site Links : $($sitelinks.Count)" -ForegroundColor White
Write-Host "OUs        : $($ous.Count)" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""
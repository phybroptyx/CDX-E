# =============================================================================
# HARDWARE INFO UTILITY SCRIPTS
# Query and manage hardware information stored in AD computer objects
# =============================================================================

<#
.SYNOPSIS
    Utility scripts for working with hardware information stored in the "info" 
    attribute of Active Directory computer objects.

.DESCRIPTION
    These scripts demonstrate how to query, update, and export hardware 
    information stored as JSON in computer object "info" attributes.
#>

# =============================================================================
# SCRIPT 1: Query Single Computer
# =============================================================================

<#
.SYNOPSIS
    Retrieve hardware information for a single computer.

.EXAMPLE
    .\Get-ComputerHardwareInfo.ps1 -ComputerName "HQ-IT-WS001"
#>

function Get-ComputerHardwareInfo {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName
    )
    
    try {
        # Get computer with info attribute
        $computer = Get-ADComputer -Identity $ComputerName -Properties info, Description, DistinguishedName
        
        # Parse hardware info from JSON
        if ([string]::IsNullOrWhiteSpace($computer.info)) {
            Write-Host "No hardware information stored for $ComputerName" -ForegroundColor Yellow
            return
        }
        
        $hardwareData = $computer.info | ConvertFrom-Json
        
        # Display results
        Write-Host "`nComputer: $ComputerName" -ForegroundColor Cyan
        Write-Host "Distinguished Name: $($computer.DistinguishedName)" -ForegroundColor Gray
        Write-Host "Description: $($computer.Description)" -ForegroundColor Gray
        Write-Host "`nHardware Information:" -ForegroundColor Cyan
        Write-Host "  Manufacturer: $($hardwareData.manufacturer)" -ForegroundColor White
        Write-Host "  Model: $($hardwareData.model)" -ForegroundColor White
        Write-Host "  Service Tag: $($hardwareData.serviceTag)" -ForegroundColor White
        
        return $hardwareData
    }
    catch {
        Write-Error "Failed to retrieve hardware info for ${ComputerName}: $_"
    }
}

# =============================================================================
# SCRIPT 2: Query All Computers with Hardware Info
# =============================================================================

<#
.SYNOPSIS
    Retrieve hardware information for all computers in a specific OU or domain.

.EXAMPLE
    .\Get-AllComputerHardware.ps1 -SearchBase "OU=Workstations,OU=IT-Core,OU=HQ,OU=Sites,DC=stark,DC=local"
    
.EXAMPLE
    .\Get-AllComputerHardware.ps1 -ExportCSV "C:\Inventory\hardware.csv"
#>

function Get-AllComputerHardware {
    param(
        [string]$SearchBase,
        [string]$ExportCSV
    )
    
    # Build filter
    $filter = "info -like '*manufacturer*'"
    
    # Get computers
    $searchParams = @{
        Filter = $filter
        Properties = @('Name', 'info', 'Description', 'DistinguishedName', 'OperatingSystem')
    }
    
    if ($SearchBase) {
        $searchParams['SearchBase'] = $SearchBase
    }
    
    $computers = Get-ADComputer @searchParams
    
    Write-Host "Found $($computers.Count) computers with hardware information" -ForegroundColor Green
    
    # Parse and display
    $results = @()
    
    foreach ($computer in $computers) {
        try {
            $hardwareData = $computer.info | ConvertFrom-Json
            
            $result = [PSCustomObject]@{
                ComputerName = $computer.Name
                Manufacturer = $hardwareData.manufacturer
                Model = $hardwareData.model
                ServiceTag = $hardwareData.serviceTag
                Description = $computer.Description
                OperatingSystem = $computer.OperatingSystem
                OU = ($computer.DistinguishedName -split ',', 2)[1]
            }
            
            $results += $result
            
            Write-Host "$($computer.Name): $($hardwareData.manufacturer) $($hardwareData.model)" `
                -ForegroundColor White
        }
        catch {
            Write-Warning "Failed to parse hardware info for $($computer.Name)"
        }
    }
    
    # Export if requested
    if ($ExportCSV) {
        $results | Export-Csv -Path $ExportCSV -NoTypeInformation
        Write-Host "`nExported to: $ExportCSV" -ForegroundColor Green
    }
    
    return $results
}

# =============================================================================
# SCRIPT 3: Update Hardware Info for Existing Computer
# =============================================================================

<#
.SYNOPSIS
    Update hardware information for an existing computer object.

.EXAMPLE
    .\Set-ComputerHardwareInfo.ps1 -ComputerName "HQ-IT-WS001" `
        -Manufacturer "Dell Precision" `
        -Model "Dell Precision 7920 Tower" `
        -ServiceTag "ABC123XY"
#>

function Set-ComputerHardwareInfo {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        
        [string]$Manufacturer,
        [string]$Model,
        [string]$ServiceTag
    )
    
    try {
        # Get existing computer
        $computer = Get-ADComputer -Identity $ComputerName -Properties info
        
        # Parse existing hardware info (if any)
        $hardwareData = [ordered]@{}
        
        if (-not [string]::IsNullOrWhiteSpace($computer.info)) {
            try {
                $existingData = $computer.info | ConvertFrom-Json
                # Preserve existing values
                if ($existingData.manufacturer) { $hardwareData['manufacturer'] = $existingData.manufacturer }
                if ($existingData.model) { $hardwareData['model'] = $existingData.model }
                if ($existingData.serviceTag) { $hardwareData['serviceTag'] = $existingData.serviceTag }
            }
            catch {
                Write-Warning "Could not parse existing hardware info, will overwrite"
            }
        }
        
        # Update with new values (only if provided)
        if ($Manufacturer) { $hardwareData['manufacturer'] = $Manufacturer }
        if ($Model) { $hardwareData['model'] = $Model }
        if ($ServiceTag) { $hardwareData['serviceTag'] = $ServiceTag }
        
        # Convert to JSON
        $jsonData = $hardwareData | ConvertTo-Json -Compress -Depth 2
        
        # Update computer object
        Set-ADComputer -Identity $ComputerName -Replace @{info = $jsonData}
        
        Write-Host "Updated hardware info for $ComputerName" -ForegroundColor Green
        Write-Host "  Manufacturer: $($hardwareData.manufacturer)" -ForegroundColor White
        Write-Host "  Model: $($hardwareData.model)" -ForegroundColor White
        Write-Host "  Service Tag: $($hardwareData.serviceTag)" -ForegroundColor White
    }
    catch {
        Write-Error "Failed to update hardware info for ${ComputerName}: $_"
    }
}

# =============================================================================
# SCRIPT 4: Search Computers by Hardware Criteria
# =============================================================================

<#
.SYNOPSIS
    Find computers matching specific hardware criteria.

.EXAMPLE
    # Find all Dell computers
    .\Find-ComputerByHardware.ps1 -Manufacturer "Dell*"
    
.EXAMPLE
    # Find all systems with specific model
    .\Find-ComputerByHardware.ps1 -Model "*Precision 7920*"
    
.EXAMPLE
    # Find specific service tag
    .\Find-ComputerByHardware.ps1 -ServiceTag "ABC123XY"
#>

function Find-ComputerByHardware {
    param(
        [string]$Manufacturer,
        [string]$Model,
        [string]$ServiceTag
    )
    
    # Get all computers with hardware info
    $computers = Get-ADComputer -Filter "info -like '*manufacturer*'" -Properties info, Name, DistinguishedName
    
    $matches = @()
    
    foreach ($computer in $computers) {
        try {
            $hardwareData = $computer.info | ConvertFrom-Json
            
            $isMatch = $true
            
            # Check manufacturer filter
            if ($Manufacturer -and $hardwareData.manufacturer -notlike $Manufacturer) {
                $isMatch = $false
            }
            
            # Check model filter
            if ($Model -and $hardwareData.model -notlike $Model) {
                $isMatch = $false
            }
            
            # Check service tag filter
            if ($ServiceTag -and $hardwareData.serviceTag -notlike $ServiceTag) {
                $isMatch = $false
            }
            
            if ($isMatch) {
                $matches += [PSCustomObject]@{
                    ComputerName = $computer.Name
                    Manufacturer = $hardwareData.manufacturer
                    Model = $hardwareData.model
                    ServiceTag = $hardwareData.serviceTag
                    DistinguishedName = $computer.DistinguishedName
                }
            }
        }
        catch {
            # Skip computers with invalid JSON
            continue
        }
    }
    
    Write-Host "Found $($matches.Count) matching computers" -ForegroundColor Green
    
    return $matches | Format-Table -AutoSize
}

# =============================================================================
# SCRIPT 5: Generate Hardware Inventory Report
# =============================================================================

<#
.SYNOPSIS
    Generate comprehensive hardware inventory report with statistics.

.EXAMPLE
    .\New-HardwareInventoryReport.ps1 -OutputPath "C:\Reports\HardwareInventory.html"
#>

function New-HardwareInventoryReport {
    param(
        [string]$OutputPath = ".\HardwareInventoryReport.html"
    )
    
    # Get all computers with hardware info
    $computers = Get-ADComputer -Filter "info -like '*manufacturer*'" `
        -Properties info, Name, OperatingSystem, DistinguishedName
    
    $inventory = @()
    $manufacturerStats = @{}
    $modelStats = @{}
    
    foreach ($computer in $computers) {
        try {
            $hardwareData = $computer.info | ConvertFrom-Json
            
            $inventory += [PSCustomObject]@{
                ComputerName = $computer.Name
                Manufacturer = $hardwareData.manufacturer
                Model = $hardwareData.model
                ServiceTag = $hardwareData.serviceTag
                OS = $computer.OperatingSystem
                OU = ($computer.DistinguishedName -split ',', 2)[1]
            }
            
            # Update statistics
            $mfr = $hardwareData.manufacturer
            if ($manufacturerStats.ContainsKey($mfr)) {
                $manufacturerStats[$mfr]++
            } else {
                $manufacturerStats[$mfr] = 1
            }
            
            $mdl = $hardwareData.model
            if ($modelStats.ContainsKey($mdl)) {
                $modelStats[$mdl]++
            } else {
                $modelStats[$mdl] = 1
            }
        }
        catch {
            continue
        }
    }
    
    # Generate HTML report
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Hardware Inventory Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #34495e; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th { background-color: #3498db; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .summary { background-color: #ecf0f1; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Hardware Inventory Report</h1>
    <div class="summary">
        <strong>Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")<br>
        <strong>Total Systems:</strong> $($inventory.Count)<br>
        <strong>Unique Manufacturers:</strong> $($manufacturerStats.Count)<br>
        <strong>Unique Models:</strong> $($modelStats.Count)
    </div>
    
    <h2>Manufacturer Distribution</h2>
    <table>
        <tr><th>Manufacturer</th><th>Count</th></tr>
"@
    
    foreach ($mfr in $manufacturerStats.GetEnumerator() | Sort-Object Value -Descending) {
        $html += "        <tr><td>$($mfr.Key)</td><td>$($mfr.Value)</td></tr>`n"
    }
    
    $html += @"
    </table>
    
    <h2>Complete Inventory</h2>
    <table>
        <tr>
            <th>Computer Name</th>
            <th>Manufacturer</th>
            <th>Model</th>
            <th>Service Tag</th>
            <th>Operating System</th>
            <th>OU</th>
        </tr>
"@
    
    foreach ($item in $inventory | Sort-Object ComputerName) {
        $html += @"
        <tr>
            <td>$($item.ComputerName)</td>
            <td>$($item.Manufacturer)</td>
            <td>$($item.Model)</td>
            <td>$($item.ServiceTag)</td>
            <td>$($item.OS)</td>
            <td>$($item.OU)</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
</body>
</html>
"@
    
    # Save report
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "Report generated: $OutputPath" -ForegroundColor Green
    Write-Host "Total systems inventoried: $($inventory.Count)" -ForegroundColor Cyan
    
    # Open report in default browser
    Start-Process $OutputPath
}

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

<#
# Example 1: Query single computer
Get-ComputerHardwareInfo -ComputerName "HQ-IT-WS001"

# Example 2: Get all hardware info and export to CSV
Get-AllComputerHardware -ExportCSV "C:\Inventory\hardware.csv"

# Example 3: Update hardware info for a computer
Set-ComputerHardwareInfo -ComputerName "HQ-IT-WS001" `
    -Manufacturer "Dell Precision" `
    -Model "Dell Precision 7920 Tower" `
    -ServiceTag "XYZ789"

# Example 4: Find all Dell Precision systems
Find-ComputerByHardware -Manufacturer "Dell*" -Model "*Precision*"

# Example 5: Generate HTML inventory report
New-HardwareInventoryReport -OutputPath "C:\Reports\Hardware.html"
#>

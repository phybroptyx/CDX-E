# HARDWARE INFO STORAGE IMPLEMENTATION GUIDE
**JSON-in-Info Attribute Approach**  
**CDX-E Active Directory Deployment**  
**Date:** 2025-11-28

---

## OVERVIEW

This guide provides step-by-step instructions for implementing hardware attribute storage using the "info" field with JSON encoding in your CDX-E deployment.

**Approach:** Store manufacturer, model, and service tag as JSON in the existing AD "info" attribute  
**Risk Level:** VERY LOW (Exchange-safe, no schema changes)  
**Reversibility:** HIGH (can change approach anytime)

---

## IMPLEMENTATION STEPS

### Step 1: Backup Current ad_deploy.ps1

```powershell
# Create backup before modification
Copy-Item ".\ad_deploy.ps1" ".\ad_deploy.ps1.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
```

### Step 2: Modify ad_deploy.ps1

**Location:** Find the `Invoke-DeployComputers` function (around line 250-280)

**Action:** Replace the entire function with the modified version

**Original Function:**
```powershell
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

        $existing = Get-ADComputer -Filter "Name -eq '$name'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Computer exists: $name" -ForegroundColor DarkGray
        }
        else {
            Write-Host "Creating computer: $name in $path" -ForegroundColor Green
            New-ADComputer -Name $name `
                           -Path $path `
                           -Description $desc `
                           -WhatIf:$WhatIf | Out-Null
        }
    }
}
```

**Modified Function:** (See `modified_computer_deployment_function.ps1`)

Copy the **entire contents** of `modified_computer_deployment_function.ps1` to replace the original function.

This includes:
- `Invoke-DeployComputers` (modified)
- `Build-HardwareInfoJSON` (new helper function)
- `Get-HardwareInfo` (new helper function)

### Step 3: Validate computers.json Format

Ensure your `computers.json` includes the hardware fields:

```json
{
  "computers": [
    {
      "name": "HQ-IT-WS001",
      "ou": "OU=Workstations,OU=IT-Core,OU=HQ,OU=Sites",
      "description": "IT Department Workstation",
      "manufacturer": "HP EliteDesk",
      "model": "HP EliteDesk 800 G9",
      "service_tag": "ABC123XY"
    }
  ]
}
```

**Required Fields:**
- `name` - Computer name
- `ou` - Organizational Unit (relative DN)
- `description` - Computer description

**Optional Hardware Fields:**
- `manufacturer` - Hardware manufacturer
- `model` - Hardware model
- `service_tag` - Service tag or serial number

**Note:** If hardware fields are missing or empty, the computer will still be created without hardware info in the "info" attribute.

### Step 4: Test with -WhatIf

Before deploying, test with the `-WhatIf` parameter:

```powershell
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf
```

**Expected Output:**
```
[6] Creating Computer Accounts...
Creating computer: HQ-IT-WS001 in OU=Workstations,OU=IT-Core,OU=HQ,OU=Sites,DC=stark,DC=local
  + Hardware: HP EliteDesk HP EliteDesk 800 G9 [ABC123XY]
What if: Performing the operation "New-ADComputer" on target "CN=HQ-IT-WS001,OU=Workstations,OU=IT-Core,OU=HQ,OU=Sites,DC=stark,DC=local"
```

### Step 5: Deploy to Active Directory

Run the actual deployment:

```powershell
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"
```

**Monitor Output:**
- Green text = New computers created
- Gray text = Existing computers skipped
- Yellow text = Hardware info updated for existing computers
- Dark green text = Hardware metadata confirmation

---

## VERIFICATION

### Verify Single Computer

```powershell
# Get computer with info attribute
$computer = Get-ADComputer "HQ-IT-WS001" -Properties info

# Display raw JSON
Write-Host "Raw Info: $($computer.info)"

# Parse and display hardware info
$hardware = $computer.info | ConvertFrom-Json
Write-Host "Manufacturer: $($hardware.manufacturer)"
Write-Host "Model: $($hardware.model)"
Write-Host "Service Tag: $($hardware.serviceTag)"
```

**Expected Output:**
```
Raw Info: {"manufacturer":"HP EliteDesk","model":"HP EliteDesk 800 G9","serviceTag":"ABC123XY"}
Manufacturer: HP EliteDesk
Model: HP EliteDesk 800 G9
Service Tag: ABC123XY
```

### Verify Multiple Computers

```powershell
# Get all computers with hardware info
Get-ADComputer -Filter "info -like '*manufacturer*'" -Properties info, Name | 
    Select-Object Name, @{N='HardwareInfo';E={$_.info}} |
    Format-Table -AutoSize
```

### Use Utility Scripts

Load the utility functions:

```powershell
# Dot-source the utility script
. .\hardware_info_utility_scripts.ps1

# Query single computer
Get-ComputerHardwareInfo -ComputerName "HQ-IT-WS001"

# Get all hardware info
$allHardware = Get-AllComputerHardware

# Export to CSV
Get-AllComputerHardware -ExportCSV "C:\Inventory\hardware.csv"

# Generate HTML report
New-HardwareInventoryReport -OutputPath "C:\Reports\HardwareInventory.html"
```

---

## UPDATING EXISTING COMPUTERS

### Scenario: Computers Already Deployed Without Hardware Info

If you've already deployed computers and need to add hardware info:

```powershell
# Option 1: Re-run deployment (will update existing computers)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"

# Option 2: Manually update specific computers
. .\hardware_info_utility_scripts.ps1

Set-ComputerHardwareInfo -ComputerName "HQ-IT-WS001" `
    -Manufacturer "HP EliteDesk" `
    -Model "HP EliteDesk 800 G9" `
    -ServiceTag "ABC123XY"
```

### Bulk Update from CSV

```powershell
# Import CSV with columns: ComputerName, Manufacturer, Model, ServiceTag
$updates = Import-Csv "C:\Updates\hardware_updates.csv"

# Dot-source utility functions
. .\hardware_info_utility_scripts.ps1

foreach ($update in $updates) {
    Set-ComputerHardwareInfo -ComputerName $update.ComputerName `
        -Manufacturer $update.Manufacturer `
        -Model $update.Model `
        -ServiceTag $update.ServiceTag
}
```

---

## QUERYING HARDWARE INFO

### PowerShell Examples

**Query by Manufacturer:**
```powershell
# Get all Dell systems
Get-ADComputer -Filter "info -like '*Dell*'" -Properties info, Name |
    ForEach-Object {
        $hw = $_.info | ConvertFrom-Json
        [PSCustomObject]@{
            Name = $_.Name
            Manufacturer = $hw.manufacturer
            Model = $hw.model
            ServiceTag = $hw.serviceTag
        }
    } | Format-Table -AutoSize
```

**Query by Model:**
```powershell
# Get all EliteDesk systems
Get-ADComputer -Filter "info -like '*EliteDesk*'" -Properties info, Name |
    ForEach-Object {
        $hw = $_.info | ConvertFrom-Json
        [PSCustomObject]@{
            Name = $_.Name
            Model = $hw.model
            ServiceTag = $hw.serviceTag
        }
    } | Format-Table -AutoSize
```

**Find Specific Service Tag:**
```powershell
# Find computer by service tag
$serviceTag = "ABC123XY"
Get-ADComputer -Filter "info -like '*$serviceTag*'" -Properties info, Name |
    ForEach-Object {
        $hw = $_.info | ConvertFrom-Json
        Write-Host "Found: $($_.Name) - $($hw.manufacturer) $($hw.model)"
    }
```

---

## INTEGRATION WITH OTHER SYSTEMS

### Export for Asset Management

```powershell
# Export hardware inventory for external systems
$computers = Get-ADComputer -Filter "info -like '*manufacturer*'" `
    -Properties info, Name, Description, OperatingSystem, DistinguishedName

$inventory = foreach ($computer in $computers) {
    $hw = $computer.info | ConvertFrom-Json
    [PSCustomObject]@{
        ComputerName = $computer.Name
        Manufacturer = $hw.manufacturer
        Model = $hw.model
        ServiceTag = $hw.serviceTag
        Description = $computer.Description
        OperatingSystem = $computer.OperatingSystem
        OU = ($computer.DistinguishedName -split ',',2)[1]
    }
}

# Export formats
$inventory | Export-Csv "inventory.csv" -NoTypeInformation
$inventory | ConvertTo-Json -Depth 3 | Out-File "inventory.json"
$inventory | Export-Clixml "inventory.xml"
```

### Integration with SCCM/ConfigMgr

```powershell
# Create custom collection based on manufacturer
$dellSystems = Get-ADComputer -Filter "info -like '*Dell*'" -Properties info
$dellComputerNames = $dellSystems | ForEach-Object { $_.Name }

# Use these names in SCCM query or collection
```

### Integration with Monitoring Tools

```powershell
# Generate monitoring tag list by hardware model
$hardware = Get-ADComputer -Filter "info -like '*manufacturer*'" -Properties info, Name

$monitoringTags = $hardware | ForEach-Object {
    $hw = $_.info | ConvertFrom-Json
    [PSCustomObject]@{
        Hostname = $_.Name
        Tag_Manufacturer = $hw.manufacturer
        Tag_Model = $hw.model -replace '\s+', '_'  # Remove spaces for tags
    }
}

$monitoringTags | Export-Csv "monitoring_tags.csv" -NoTypeInformation
```

---

## MAINTENANCE

### Regular Inventory Audit

Create scheduled task to generate weekly reports:

```powershell
# Save as: C:\Scripts\Weekly-HardwareReport.ps1
. C:\Scripts\hardware_info_utility_scripts.ps1

$reportPath = "C:\Reports\HardwareInventory_$(Get-Date -Format 'yyyyMMdd').html"
New-HardwareInventoryReport -OutputPath $reportPath

# Email report (configure SMTP settings)
Send-MailMessage -To "it-admin@stark.local" `
    -From "ad-reports@stark.local" `
    -Subject "Weekly Hardware Inventory Report" `
    -Body "Attached is this week's hardware inventory report." `
    -Attachments $reportPath `
    -SmtpServer "smtp.stark.local"
```

### Cleanup Old/Invalid JSON

```powershell
# Find computers with invalid JSON in info field
$computers = Get-ADComputer -Filter "info -like '*manufacturer*'" -Properties info, Name

foreach ($computer in $computers) {
    try {
        $null = $computer.info | ConvertFrom-Json
    }
    catch {
        Write-Warning "Invalid JSON in $($computer.Name): $($computer.info)"
        # Optional: Clear invalid data
        # Set-ADComputer -Identity $computer.Name -Clear info
    }
}
```

---

## FUTURE MIGRATION PATH

### If You Later Decide to Use Custom Schema

The JSON-in-info approach is fully reversible:

```powershell
# Step 1: Export all hardware data
$computers = Get-ADComputer -Filter "info -like '*manufacturer*'" -Properties info, Name
$exportData = foreach ($computer in $computers) {
    $hw = $computer.info | ConvertFrom-Json
    [PSCustomObject]@{
        Name = $computer.Name
        Manufacturer = $hw.manufacturer
        Model = $hw.model
        ServiceTag = $hw.serviceTag
    }
}
$exportData | Export-Csv "hardware_export.csv" -NoTypeInformation

# Step 2: (After creating custom schema attributes)
# Import and populate new attributes
$importData = Import-Csv "hardware_export.csv"
foreach ($item in $importData) {
    Set-ADComputer -Identity $item.Name -Replace @{
        hardwareManufacturer = $item.Manufacturer
        hardwareModel = $item.Model
        hardwareServiceTag = $item.ServiceTag
    }
}

# Step 3: (Optional) Clear info attribute
foreach ($item in $importData) {
    Set-ADComputer -Identity $item.Name -Clear info
}
```

---

## TROUBLESHOOTING

### Issue: Computer Created But No Hardware Info

**Symptom:** Computer exists but `info` attribute is empty

**Causes:**
1. Hardware fields missing from `computers.json`
2. Hardware fields contain null/empty values
3. JSON parsing error during creation

**Solution:**
```powershell
# Check JSON data
$comp = Get-Content ".\EXERCISES\CHILLED_ROCKET\computers.json" | ConvertFrom-Json
$comp.computers | Where-Object { $_.name -eq "HQ-IT-WS001" } | 
    Select-Object name, manufacturer, model, service_tag

# Manually add hardware info
. .\hardware_info_utility_scripts.ps1
Set-ComputerHardwareInfo -ComputerName "HQ-IT-WS001" `
    -Manufacturer "HP EliteDesk" `
    -Model "HP EliteDesk 800 G9" `
    -ServiceTag "ABC123XY"
```

### Issue: JSON Parsing Errors

**Symptom:** `ConvertFrom-Json : Invalid JSON primitive` error

**Causes:**
1. Malformed JSON in info attribute
2. Special characters not escaped
3. Manual editing corrupted JSON

**Solution:**
```powershell
# View raw info attribute
$computer = Get-ADComputer "HQ-IT-WS001" -Properties info
$computer.info

# Clear and rebuild
$hardwareData = [ordered]@{
    manufacturer = "HP EliteDesk"
    model = "HP EliteDesk 800 G9"
    serviceTag = "ABC123XY"
}
$jsonData = $hardwareData | ConvertTo-Json -Compress
Set-ADComputer -Identity "HQ-IT-WS001" -Replace @{info = $jsonData}
```

### Issue: Search Not Finding Computers

**Symptom:** `Get-ADComputer -Filter "info -like '*manufacturer*'"` returns no results

**Causes:**
1. No computers have hardware info populated
2. Attribute not indexed (normal, expected)
3. LDAP filter syntax issue

**Solution:**
```powershell
# Get ALL computers and filter manually
$allComputers = Get-ADComputer -Filter * -Properties info
$withHardware = $allComputers | Where-Object { $_.info -like '*manufacturer*' }

Write-Host "Computers with hardware info: $($withHardware.Count)"
Write-Host "Total computers: $($allComputers.Count)"
```

---

## BEST PRACTICES

### 1. Consistent JSON Schema

Always use the same field names:
- `manufacturer` (not "Manufacturer" or "mfr")
- `model` (not "Model" or "modelNumber")
- `serviceTag` (not "ServiceTag" or "serial")

### 2. Validate Before Deployment

```powershell
# Test JSON parsing before deployment
$testData = @{
    manufacturer = "Test Mfr"
    model = "Test Model"
    serviceTag = "TEST123"
} | ConvertTo-Json -Compress

try {
    $null = $testData | ConvertFrom-Json
    Write-Host "JSON validation: PASS" -ForegroundColor Green
} catch {
    Write-Host "JSON validation: FAIL" -ForegroundColor Red
}
```

### 3. Document Custom Usage

Create a README in your exercise folder:

```markdown
# Hardware Info Storage

This exercise uses the AD "info" attribute to store hardware metadata:

- **Manufacturer**: Hardware manufacturer name
- **Model**: Full hardware model designation
- **Service Tag**: Manufacturer service tag or serial number

## Retrieval

Dot-source utility script:
. ..\..\..\hardware_info_utility_scripts.ps1

Query computer:
Get-ComputerHardwareInfo -ComputerName "HQ-IT-WS001"
```

### 4. Include in Deployment Documentation

Add to exercise README:

```
## Hardware Inventory

Computer objects include hardware information stored as JSON in the "info" attribute:

{
  "manufacturer": "HP EliteDesk",
  "model": "HP EliteDesk 800 G9",
  "serviceTag": "ABC123XY"
}

Use the provided utility scripts to query this information.
```

---

## DEPLOYMENT CHECKLIST

- [ ] Backup original `ad_deploy.ps1`
- [ ] Replace `Invoke-DeployComputers` function
- [ ] Add helper functions (`Build-HardwareInfoJSON`, `Get-HardwareInfo`)
- [ ] Validate `computers.json` includes hardware fields
- [ ] Test with `-WhatIf` parameter
- [ ] Deploy to test OU first
- [ ] Verify hardware info stored correctly
- [ ] Deploy to remaining OUs
- [ ] Generate initial inventory report
- [ ] Document usage in exercise README
- [ ] Dot-source utility scripts for team
- [ ] Schedule regular inventory audits

---

## FILES PROVIDED

| File | Purpose |
|------|---------|
| **modified_computer_deployment_function.ps1** | Modified ad_deploy.ps1 function |
| **hardware_info_utility_scripts.ps1** | Query and management utilities |
| **IMPLEMENTATION_GUIDE.md** | This document |

---

## SUPPORT

For questions or issues:
1. Review troubleshooting section above
2. Check PowerShell verbose output: `.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose`
3. Validate JSON syntax: `Get-Content "computers.json" | ConvertFrom-Json`
4. Test info attribute directly: `Get-ADComputer "COMPUTERNAME" -Properties info`

---

**Implementation Guide Version:** 1.0  
**Last Updated:** 2025-11-28  
**Framework:** CDX-E v2.0  
**Approach:** JSON-in-Info Attribute (Recommendation #2)

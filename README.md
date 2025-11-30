# CDX-E Active Directory Deployment Framework
**Template-Driven, Modular AD Environment Builder**  
**Version 2.2 - Auto-Reboot Enhancement**

---

## Overview

This repository provides a **generic Active Directory deployment engine** for building repeatable, configuration-driven lab environments. The framework reads JSON configuration files (topology, users, computers, services, GPOs) and deploys complete AD forests and configurations on Windows Server.

**Key Features:**
- ✨ **Template-Driven Architecture** - Define topology once, deploy anywhere
- 🔄 **Idempotent Operations** - Safe to re-run without duplicating objects
- 🌳 **Forest Creation** - Automated new forest deployment with optional auto-reboot
- 🏢 **Enterprise Topology** - Multi-site, multi-OU, global infrastructure support
- 💾 **Hardware Metadata** - Optional hardware info storage (manufacturer, model, service tag)
- 🤖 **Auto-Reboot** - Automated reboot and deployment continuation (v2.2)
- 📋 **WhatIf Mode** - Preview changes before execution

---

## Version History

| Version | Release Date | Key Features |
|---------|--------------|--------------|
| **2.2** | 2025-11-29 | Auto-reboot with scheduled task automation, remote session detection |
| **2.1** | 2025-11-28 | Hardware info storage in AD "info" attribute (JSON encoding) |
| **2.0** | 2025-11-27 | Template-driven architecture, exercise_template.json workflow |
| **1.0** | 2024-XX-XX | Initial release with manual structure.json creation |

---

## What's New in v2.2

### 🤖 Automatic Reboot After Forest Creation

**Problem Solved:** Forest creation requires a reboot before continuing deployment. Previously required manual intervention and context loss in remote sessions.

**New Capability:**
- Optional `-AutoReboot` flag enables automatic system restart
- Configurable countdown delay (default: 30 seconds, cancelable with Ctrl+C)
- **Remote session detection** - Automatically creates scheduled task for post-reboot continuation
- **Scheduled task automation** - Deployment resumes automatically after reboot
- **Self-cleanup** - Task removes itself after successful completion

### Usage Example

```powershell
# Traditional (manual reboot - still supported):
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure
# <manually reboot>
# <manually rerun script>

# NEW - Automated reboot and continuation:
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot
# <system reboots automatically after 30s countdown>
# <deployment continues automatically post-reboot>
# <task self-deletes when complete>
```

### Technical Details

**Remote Session Detection:**
- Detects PowerShell remoting context (`$PSSenderInfo`)
- Creates Windows scheduled task: `CDX-PostReboot-Deployment`
- Task runs as `NT AUTHORITY\SYSTEM` with highest privileges
- Triggers at system startup
- Executes: `.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"`

**Benefits:**
- ✅ Eliminates manual reboot step
- ✅ Maintains deployment continuity in remote sessions
- ✅ Reduces deployment time (~15 min → ~10 min)
- ✅ Streamlines multi-DC deployments
- ✅ User can cancel reboot if needed (Ctrl+C during countdown)

---

## Table of Contents

1. [Version History](#version-history)
2. [What's New in v2.2](#whats-new-in-v22)
3. [Folder Layout](#folder-layout)
4. [Prerequisites](#prerequisites)
5. [Script Responsibilities](#script-responsibilities)
6. [Script Parameters](#script-parameters)
7. [JSON Configuration Files](#json-configuration-files)
8. [Execution Workflows](#execution-workflows)
9. [Execution Flow Details](#execution-flow-details)
10. [Template-Driven Architecture Benefits](#template-driven-architecture-benefits)
11. [Hardware Info Storage (v2.1)](#hardware-info-storage-v21)
12. [Troubleshooting](#troubleshooting)
13. [Template Library](#template-library)
14. [Best Practices](#best-practices)
15. [Quick Reference](#quick-reference)
16. [Support and Contribution](#support-and-contribution)

---

## 1. Folder Layout

Recommended structure:

```
ad_deploy.ps1              # Main AD deployment script (v2.2 with auto-reboot)
generate_structure.ps1     # Topology generator (reads templates)

EXERCISES/
├── CHILLED_ROCKET/        # Example scenario folder
│   ├── exercise_template.json  # Topology definition (sites, OUs, departments)
│   ├── structure.json          # Generated: AD Sites, Subnets, Site Links, OU structure
│   ├── services.json           # DNS Zones and other service configuration
│   ├── users.json              # User accounts, group memberships
│   ├── computers.json          # Computer objects (pre-staged, optionally with hardware info)
│   ├── gpo.json                # Group Policy Objects and linked targets
│   └── README.md               # (Optional) Scenario notes
└── <OTHER_SCENARIO>/
    ├── exercise_template.json  # Different topology for this scenario
    └── ...

UTILITIES/                  # Optional utility scripts (v2.1)
├── hardware_info_utility_scripts.ps1       # Hardware management functions
└── Test-HardwareInfoImplementation.ps1     # Validation test suite

DOCUMENTATION/             # Optional documentation
├── IMPLEMENTATION_GUIDE.md                 # Hardware info deployment guide
├── PSREMOTING_DEPLOYMENT_GUIDE_v2.md       # Remote deployment guide (v2.2 updated)
└── (other documentation files)
```

---

## 2. Prerequisites

Before using this script, ensure:

1. You are logged in as (or running PowerShell as) a **Domain Admin** (or local admin for forest creation)
2. The target system is joined to the **target domain** or will host a new one
3. Required PowerShell modules are installed:
   - `ActiveDirectory` (mandatory post-forest creation)
   - `ADDSDeployment` (for new forest creation)
   - `DnsServer` (for DNS deployment)
   - `GroupPolicy` (for GPO deployment)

If deploying a **new forest**, the script will:
- Prompt for domain details (FQDN, NetBIOS name)
- Install the AD DS role if needed
- Create the forest
- **Automatically reboot** (if `-AutoReboot` flag used) **← NEW in v2.2**
- **Auto-continue deployment** post-reboot (remote sessions only) **← NEW in v2.2**
- OR instruct you to manually reboot and rerun (default behavior)

---

## 3. Script Responsibilities

`ad_deploy.ps1` deploys Active Directory configurations based on the contents of the selected `EXERCISES/<ExerciseName>` folder.

### Deployment Order

1. **Forest Detection/Creation**
   - Detects existing AD domain or prompts to create new forest
   - If new forest: installs AD DS role, creates forest
   - **NEW v2.2:** Optionally reboots automatically with `-AutoReboot` flag
   - **NEW v2.2:** Creates scheduled task for post-reboot deployment continuation
   - If existing: continues to configuration deployment

2. **Sites & Replication Topology**
   - AD Sites with descriptions
   - Subnets linked to sites
   - Site Links with cost and replication intervals
   - Cleanup of auto-created `DEFAULTIPSITELINK`

3. **Organizational Units (OUs)**
   - Hierarchical OU structure sorted by depth
   - Parent OUs created before children

4. **Security Groups**
   - Creates groups in specified OUs

5. **DNS & Services**
   - DNS zones (forward and reverse lookup)
   - DNS forwarders
   - _(DHCP, WINS, Certificate Services defined but not yet implemented)_

6. **Group Policy Objects**
   - Creates GPOs
   - Links GPOs to target OUs with enforcement settings

7. **Computer Accounts** _(Enhanced in v2.1)_
   - Pre-stages computer objects in specified OUs
   - Stores hardware metadata (manufacturer, model, service_tag) if provided
   - Updates hardware info if changed on re-run (idempotent)
   - Displays hardware information during deployment

8. **User Accounts**
   - Creates users with full attributes (address, phone, title, etc.)
   - Assigns group memberships

> 🟢 All operations are idempotent: existing objects are skipped or updated, not recreated.

---

## 4. Script Parameters

### ad_deploy.ps1

```powershell
[CmdletBinding()]
param(
    [string]$ExercisesRoot = ".\EXERCISES",
    [string]$ExerciseName,
    [string]$ConfigPath,
    [string]$DomainFQDN,
    [string]$DomainDN,
    [switch]$GenerateStructure,
    [switch]$WhatIf,
    [switch]$AutoReboot,           # NEW v2.2
    [int]$RebootDelaySeconds = 30  # NEW v2.2
)
```

**-ExerciseName**  
Name of the exercise folder (e.g., `CHILLED_ROCKET`)

**-GenerateStructure**  
Generates (or regenerates) `structure.json` under `EXERCISES/<ExerciseName>` by calling `generate_structure.ps1`, which reads `exercise_template.json` to build the topology.

Useful for:
- Initial exercise setup
- Regenerating topology after template modifications
- Updating site/OU structure without manual JSON editing

**-WhatIf**  
Runs in simulation mode. No changes are made to AD, DNS, or GPOs.

**-AutoReboot** _(NEW in v2.2)_  
Enables automatic system reboot after forest creation. Features:
- 30-second countdown with cancel option (Ctrl+C)
- Remote session detection
- Scheduled task creation for post-reboot deployment
- Automatic deployment continuation after reboot

**-RebootDelaySeconds** _(NEW in v2.2)_  
Customizes the countdown duration before automatic reboot (default: 30 seconds). Only applies when `-AutoReboot` is used.

**-DomainFQDN / -DomainDN**  
Optional overrides for domain detection (rarely needed).

### generate_structure.ps1

```powershell
[CmdletBinding()]
param(
    [string]$ExercisesRoot = ".\EXERCISES",
    [Parameter(Mandatory)]
    [string]$ExerciseName,
    [string]$TemplateFileName = "exercise_template.json",
    [string]$OutputFileName = "structure.json",
    [switch]$Force
)
```

**-Force**  
Overwrites existing `structure.json` without prompting.

---

## 5. JSON Configuration Files

### Core Configuration Files

The following files must be present under the selected exercise folder:

| File                     | Purpose                                          | Generated? |
|--------------------------|--------------------------------------------------|------------|
| `exercise_template.json` | Topology blueprint (sites, OUs, departments)    | Manual     |
| `structure.json`         | AD Sites, Subnets, Site Links, OU structure     | Auto       |
| `services.json`          | DNS Zones and other service configuration       | Manual     |
| `users.json`             | User accounts, group memberships                | Manual     |
| `computers.json`         | Computer objects (pre-staged, optionally with hardware info) | Manual |
| `gpo.json`               | Group Policy Objects and linked targets         | Manual     |

---

### 5.1. computers.json Format _(Enhanced in v2.1)_

The `computers.json` file defines computer objects to be created in Active Directory.

#### Basic Format (v2.0)

```json
{
  "computers": [
    {
      "name": "HQ-IT-WS001",
      "ou": "OU=Workstations,OU=IT-Core,OU=HQ,OU=Sites",
      "description": "IT Department Workstation"
    }
  ]
}
```

#### Enhanced Format (v2.1 - Hardware Info)

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

#### Hardware Fields (Optional - v2.1)

- **`manufacturer`** - Hardware manufacturer (e.g., "Dell", "HP", "Lenovo")
- **`model`** - Specific model name or number
- **`service_tag`** - Service tag, serial number, or asset tag

**Storage:** Hardware data is stored as JSON in the AD computer object's "info" attribute:
```json
{"manufacturer":"HP EliteDesk","model":"HP EliteDesk 800 G9","serviceTag":"ABC123XY"}
```

#### Query Examples

**PowerShell - Direct Query:**
```powershell
# Retrieve hardware info from AD
$computer = Get-ADComputer "HQ-IT-WS001" -Properties info
$hardware = $computer.info | ConvertFrom-Json
Write-Host "Manufacturer: $($hardware.manufacturer)"
Write-Host "Model: $($hardware.model)"
Write-Host "Service Tag: $($hardware.serviceTag)"
```

**Using Utility Functions:**
```powershell
# Load utility scripts
. .\UTILITIES\hardware_info_utility_scripts.ps1

# Query single computer
Get-ComputerHardwareInfo -ComputerName "HQ-IT-WS001"

# Export all hardware to CSV
Get-AllComputerHardware -ExportCSV "inventory.csv"
```

> **Note:** Hardware fields are completely optional. The deployment engine works with or without them.

---

## 6. Execution Workflows

### Workflow 1: Creating a New Exercise

```powershell
# 1. Create exercise folder
New-Item -ItemType Directory -Path ".\EXERCISES\NEW_EXERCISE"

# 2. Create topology template (copy from existing or create new)
Copy-Item ".\EXERCISES\CHILLED_ROCKET\exercise_template.json" `
          ".\EXERCISES\NEW_EXERCISE\exercise_template.json"

# 3. Edit template to define your topology
notepad ".\EXERCISES\NEW_EXERCISE\exercise_template.json"

# 4. Generate structure.json from template
.\generate_structure.ps1 -ExerciseName "NEW_EXERCISE"

# 5. Create other config files (users.json, computers.json, etc.)
# ... (copy templates and modify as needed)

# 6. Deploy to AD
.\ad_deploy.ps1 -ExerciseName "NEW_EXERCISE"
```

---

### Workflow 2: First-Time Deployment (New Forest) - Manual Reboot

```powershell
# Run 1: Create forest (traditional method)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure

# Script will:
# - Generate structure.json from exercise_template.json
# - Detect no domain exists
# - Prompt to create new forest
# - Install AD DS role if needed
# - Create forest
# - Exit with reboot instruction

# Manually reboot the server

# Run 2: Deploy configuration
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"

# Script will:
# - Detect existing domain
# - Deploy all configuration (sites, OUs, users, etc.)
# - Store hardware info for computers (if provided)
# - Complete successfully
```

---

### Workflow 2b: First-Time Deployment (New Forest) - AUTO-REBOOT _(NEW v2.2)_

```powershell
# Single run with automatic reboot and continuation
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot

# Script will:
# - Generate structure.json from exercise_template.json
# - Detect no domain exists
# - Prompt to create new forest
# - Install AD DS role if needed
# - Create forest
# - Display 30-second countdown (cancelable with Ctrl+C)
# - Automatically reboot system
# - Create scheduled task for post-reboot deployment
# 
# Post-reboot (automatic):
# - Scheduled task triggers at startup
# - Continues deployment (sites, OUs, users, computers, etc.)
# - Stores hardware info for computers (if provided)
# - Removes scheduled task
# - Completes successfully
```

**Remote Session Example:**
```powershell
# From cdx-mgmt-01 via PowerShell Remoting
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot
}

# Output includes:
# [AutoReboot] Remote PowerShell session detected
# [AutoReboot] Creating scheduled task for post-reboot deployment...
# [AutoReboot] ✓ Scheduled task created successfully
# [AutoReboot] Post-reboot deployment will continue automatically!
# [AutoReboot] System will RESTART in 30 seconds...
# [AutoReboot] Press Ctrl+C NOW to cancel automatic reboot
```

---

### Workflow 3: Custom Reboot Delay

```powershell
# 60-second countdown instead of default 30 seconds
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot -RebootDelaySeconds 60
```

---

### Workflow 4: Updating Existing Exercise

```powershell
# 1. Modify the template
notepad ".\EXERCISES\CHILLED_ROCKET\exercise_template.json"

# 2. Regenerate structure (with force to skip prompt)
.\generate_structure.ps1 -ExerciseName "CHILLED_ROCKET" -Force

# 3. Redeploy (idempotent - only adds/updates changes)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"
```

---

### Workflow 5: Idempotent Redeployment

```powershell
# Run anytime to ensure environment matches configuration
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"

# The script will:
# - Detect existing AD forest
# - Skip existing objects (shown in gray)
# - Create only missing objects (shown in green)
# - Update modified objects where applicable
# - Update hardware info if changed (v2.1)
```

---

### Workflow 6: What-If Mode (Validation)

```powershell
# Test what would happen without making changes
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf

# Shows intended actions in yellow without executing them
```

---

## 7. Execution Flow Details

### Phase 1: Initialization
1. Parse parameters and resolve exercise path
2. If `-GenerateStructure`: call `generate_structure.ps1`
   - Generator reads `exercise_template.json`
   - Builds sites, subnets, site links, and OU hierarchy
   - Writes `structure.json`
   - Returns control to ad_deploy.ps1
3. Validate all required JSON files exist

### Phase 2: Domain Detection
1. Attempt `Get-ADDomain`
   - **Success**: Domain exists → Continue to deployment
   - **Failure**: No domain detected → Prompt for forest creation

### Phase 3: Forest Creation (if needed)
1. Prompt user: "Create new AD forest?"
2. Install AD DS role if missing
3. Prompt for domain FQDN, NetBIOS name, DSRM password
4. Execute `Install-ADDSForest`
5. **NEW v2.2:** Handle reboot based on `-AutoReboot` flag:
   - **If `-AutoReboot` enabled:**
     - Detect remote session context
     - Create scheduled task (if remote)
     - Display countdown with cancel option
     - Automatically reboot system
   - **If `-AutoReboot` disabled (default):**
     - Display manual reboot instruction
     - Exit script

### Phase 4: Post-Reboot Continuation _(NEW v2.2 - Automatic)_
1. Scheduled task triggers at system startup (remote sessions only)
2. Executes: `ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"`
3. Continues to Phase 5 (Configuration Deployment)
4. Removes scheduled task after successful completion

### Phase 5: Configuration Deployment (if domain exists)
1. Load all JSON configuration files
2. Execute deployment functions sequentially:
   - Sites, subnets, site links
   - OUs (sorted by hierarchy depth)
   - Groups
   - DNS zones and forwarders
   - GPOs and links
   - Computer accounts **(with hardware info if provided - v2.1)**
   - User accounts and group memberships
3. Display completion message

---

## 8. Template-Driven Architecture Benefits

The template-driven approach provides several advantages:

| Benefit | Description |
|---------|-------------|
| **Separation of Concerns** | Topology data (JSON) separated from generation logic (PowerShell) |
| **Reusability** | One generator script works for all exercises |
| **Maintainability** | Edit JSON templates instead of PowerShell code |
| **Documentation** | Template serves as self-documenting exercise specification |
| **Version Control** | Track topology changes as data, not code |
| **Rapid Development** | Create new exercises by copying/modifying templates |
| **Flexibility** | Enable/disable features via `advancedOptions` in template |
| **Validation** | Future: JSON schema validation for template correctness |
| **Auto-Reboot (v2.2)** | Streamlined deployment with minimal manual intervention |

---

## 9. Hardware Info Storage (v2.1)

### Overview

Version 2.1 adds the ability to store hardware metadata (manufacturer, model, service tag) directly in Active Directory computer objects using the existing "info" attribute with JSON encoding.

**Key Features:**
- ✅ **Exchange-Safe** - No conflict with future Exchange deployments
- ✅ **No Schema Modifications** - Uses standard AD attributes
- ✅ **Fully Reversible** - Can migrate to custom schema later
- ✅ **Optional** - Works with or without hardware data

### Storage Method

Hardware data is stored as compact JSON in the AD "info" attribute:

```json
{"manufacturer":"Dell PowerEdge","model":"Dell PowerEdge R640","serviceTag":"ABC123XY"}
```

### Utility Scripts (v2.1)

Located in `UTILITIES/` folder:

**hardware_info_utility_scripts.ps1** - Management functions:
- `Get-ComputerHardwareInfo` - Retrieve hardware info for single computer
- `Get-AllComputerHardware` - Export inventory to CSV
- `Set-ComputerHardwareInfo` - Update hardware info for existing computer
- `Find-ComputerByHardware` - Search computers by hardware criteria
- `New-HardwareInventoryReport` - Generate HTML inventory report

**Test-HardwareInfoImplementation.ps1** - Validation suite:
- Pre-deployment testing
- JSON encoding/decoding validation
- Hardware info roundtrip tests

### Usage Examples

```powershell
# Load utility functions
. .\UTILITIES\hardware_info_utility_scripts.ps1

# Query single computer
Get-ComputerHardwareInfo -ComputerName "HQ-IT-WS001"

# Export inventory to CSV
Get-AllComputerHardware -ExportCSV "hardware_inventory.csv"

# Generate HTML report
New-HardwareInventoryReport -OutputPath "inventory.html"

# Search for Dell computers
Find-ComputerByHardware -Manufacturer "Dell*"

# Update hardware info for existing computer
Set-ComputerHardwareInfo -ComputerName "HQ-IT-WS001" `
                         -Manufacturer "Dell" `
                         -Model "OptiPlex 7090" `
                         -ServiceTag "XYZ789"
```

### Implementation Notes

- **Exchange-Safe**: Does not use extensionAttribute fields
- **No Schema Changes**: Uses standard AD "info" attribute
- **Fully Reversible**: Can migrate to custom schema later if needed
- **Backward Compatible**: Works without hardware data in computers.json

See `DOCUMENTATION/IMPLEMENTATION_GUIDE.md` for detailed setup instructions.

---

## 10. Troubleshooting

### Common Issues

**"Template file not found: exercise_template.json"**
- Ensure `exercise_template.json` exists in the exercise folder
- Create one manually or copy from an existing exercise
- Use `-GenerateStructure` only after template exists

**"Module not available: ActiveDirectory"**
- Install RSAT tools: `Install-WindowsFeature RSAT-AD-PowerShell`
- Or install from Windows Features (client OS)

**"No existing domain detected"**
- Expected on first run (will prompt for forest creation)
- If domain should exist, check network connectivity to DC
- Verify you're running on a domain-joined machine

**Forest creation fails**
- Ensure running as local administrator
- Verify DSRM password meets complexity requirements
- Check for conflicting DNS/DHCP services

**Automatic reboot cancelled** _(NEW v2.2)_
- User pressed Ctrl+C during countdown
- Script exits with manual reboot instruction
- Manually reboot and rerun script to continue

**Scheduled task not created** _(NEW v2.2)_
- Check permissions - requires administrator rights
- Verify Task Scheduler service is running
- Review error output for specific failure reason
- Manual workaround: Reboot and rerun script manually

**DNS or GPO sections skipped**
- Install missing modules: `DnsServer`, `GroupPolicy`
- Warnings will indicate which modules are unavailable

**Objects not being created**
- Check for JSON syntax errors (no comments, no trailing commas)
- Verify OU paths use relative DN format
- Review error messages for specific object failures

**Hardware info not appearing (v2.1)**
- Verify computers.json has hardware fields (manufacturer, model, service_tag)
- Check that fields are not null or empty
- Run with `-WhatIf` to see what would be created

### Validation and Testing

```powershell
# Test template processing without deployment
.\generate_structure.ps1 -ExerciseName "CHILLED_ROCKET" -Force

# Validate generated structure
$structure = Get-Content ".\EXERCISES\CHILLED_ROCKET\structure.json" | ConvertFrom-Json
Write-Host "Sites: $($structure.sites.Count)"
Write-Host "OUs: $($structure.ous.Count)"

# Test deployment in What-If mode
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf

# Test deployment with auto-reboot in What-If mode (v2.2)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf -AutoReboot

# Enable verbose output for debugging
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose

# Test hardware info implementation (v2.1)
.\UTILITIES\Test-HardwareInfoImplementation.ps1

# Verify scheduled task creation (v2.2)
Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -ErrorAction SilentlyContinue
```

---

## 11. Template Library (Future)

Future releases may include a library of starter templates:

- **Small Enterprise** (1 site, 50 users, minimal infrastructure)
- **Medium Enterprise** (3 sites, 500 users, branch offices)
- **Large Enterprise** (5+ sites, 5000+ users, global infrastructure)
- **Financial Services** (compliance-focused, audit requirements)
- **Healthcare** (HIPAA considerations, department isolation)
- **Manufacturing** (OT/IT integration, site-based structure)
- **Government** (security classifications, compartmentalization)

---

## 12. Best Practices

### Exercise Development

1. **Start with Template**: Always begin by creating/copying `exercise_template.json`
2. **Incremental Testing**: Generate and validate structure.json before creating other configs
3. **Version Control**: Commit all JSON files to source control
4. **Documentation**: Update exercise README.md with scenario details
5. **Naming Conventions**: Use consistent naming (e.g., `EXERCISE_NAME` in caps)

### Deployment

1. **Test in Isolated Environment**: Use dedicated lab/test domain
2. **Snapshot Before Deployment**: VM snapshots enable rollback
3. **Use What-If First**: Validate intended changes before execution
4. **Review Logs**: Check PowerShell output for warnings/errors
5. **Validate Post-Deployment**: Verify critical objects were created
6. **Use Auto-Reboot for Efficiency** _(v2.2)_: `-AutoReboot` reduces manual steps

### Maintenance

1. **Regular Updates**: Keep templates synchronized with live changes
2. **Idempotent Runs**: Periodically rerun deployment to ensure consistency
3. **Backup Configurations**: Archive JSON files with exercise versions
4. **Document Changes**: Track template modifications in version control
5. **Monitor Scheduled Tasks** _(v2.2)_: Verify auto-deployment tasks complete successfully

---

## 13. Quick Reference

### Command Cheat Sheet

```powershell
# Create new exercise from template
.\generate_structure.ps1 -ExerciseName "EXERCISE_NAME"

# Deploy fresh environment
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -GenerateStructure

# Deploy with automatic reboot (v2.2)
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -GenerateStructure -AutoReboot

# Deploy with custom reboot delay (v2.2)
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -GenerateStructure -AutoReboot -RebootDelaySeconds 60

# Update existing environment
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"

# Test without changes
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -WhatIf

# Force regenerate structure
.\generate_structure.ps1 -ExerciseName "EXERCISE_NAME" -Force

# Create new forest + deploy (manual reboot)
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"  # Run 1: Creates forest
# <reboot>
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"  # Run 2: Deploys config

# Create new forest + deploy (automatic reboot - v2.2)
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -AutoReboot  # Fully automated!

# Query hardware info (v2.1)
$computer = Get-ADComputer "COMPUTER_NAME" -Properties info
$computer.info | ConvertFrom-Json

# Check for post-reboot scheduled task (v2.2)
Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment"
```

### File Checklist

Before deployment, ensure these files exist:
- ✅ `exercise_template.json` (manually created)
- ✅ `users.json` (manually created)
- ✅ `computers.json` (manually created - optionally with hardware fields)
- ✅ `services.json` (manually created)
- ✅ `gpo.json` (manually created)
- ⚙️ `structure.json` (generated by script)

**Optional Utility Scripts (v2.1):**
- ⚙️ `UTILITIES/hardware_info_utility_scripts.ps1` (hardware management)
- ⚙️ `UTILITIES/Test-HardwareInfoImplementation.ps1` (validation)

**Optional Documentation (v2.2):**
- ⚙️ `DOCUMENTATION/PSREMOTING_DEPLOYMENT_GUIDE_v2.md` (remote deployment guide)

---

## 14. Auto-Reboot Technical Reference (v2.2)

### Invoke-GracefulReboot Function

**Purpose:** Handles automatic system reboot with countdown and scheduled task creation.

**Features:**
- Remote session detection (`$PSSenderInfo`)
- Scheduled task creation for post-reboot continuity
- Countdown timer with cancel option
- Error handling and fallback

### Scheduled Task Details

**Task Name:** `CDX-PostReboot-Deployment`  
**Trigger:** At system startup  
**User:** `NT AUTHORITY\SYSTEM`  
**Privilege Level:** Highest  
**Command:** `PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\CDX-Deploy\ad_deploy.ps1" -ExerciseName "EXERCISE_NAME"`

**Task Settings:**
- Runs even if on battery
- Starts when available
- Execution time limit: 2 hours
- Self-deletes after successful completion

### Deployment Timeline

**With Auto-Reboot:**
1. Forest creation: ~5 min
2. Reboot: ~2 min (including countdown)
3. Post-reboot deployment: ~3-5 min
4. **Total: ~10-12 min**

**Without Auto-Reboot (Traditional):**
1. Forest creation: ~5 min
2. Manual reboot decision: ~1-2 min
3. Reboot: ~2 min
4. Manual script rerun: ~1 min
5. Post-reboot deployment: ~3-5 min
6. **Total: ~12-15 min**

**Time Saved:** 2-3 minutes + reduced cognitive load

---

## 15. Support and Contribution

This modular approach enables **rapid iteration** and **repeatable AD builds** for multiple cyber range scenarios.

For questions, issues, or contributions:
- Review existing templates in `EXERCISES/` folders
- Check troubleshooting section for common issues
- Consult PowerShell verbose output for debugging
- Refer to GitHub repositories for updates and examples
- Review `DOCUMENTATION/PSREMOTING_DEPLOYMENT_GUIDE_v2.md` for remote deployment best practices

Use this framework as the backbone to spin up Stark Industries today… and tear it down tomorrow… **now with even less manual intervention!** 🚀

---

**Framework Version:** 2.2  
**Last Updated:** 2025-11-29  
**Key Features:** Template-driven, Idempotent, Hardware Info, Auto-Reboot  
**Status:** ✅ Production Ready

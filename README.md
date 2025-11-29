# AD Deployment Engine (`ad_deploy.ps1`)

## 1. Overview

`ad_deploy.ps1` is a **generic Active Directory deployment engine** designed to build and rebuild lab environments from structured JSON configuration files. It works with a matching structure generator (`generate_structure.ps1`) to produce all required Active Directory design files for scalable, reusable cyber defense exercises.

This framework is **scenario-agnostic**, meaning the same `ad_deploy.ps1` file can deploy multiple Active Directory environments based on the selected scenario folder.

**New in v2.0:** The structure generator now uses a **template-driven architecture**, separating topology definitions (stored in `exercise_template.json`) from generation logic. This makes creating new exercises faster and more maintainable.

**New in v2.1:** The deployment engine now supports **hardware metadata storage** for computer objects, enabling asset tracking and inventory management without requiring schema modifications or Exchange extensionAttribute usage.

---

## 1.1. What's New in v2.1

**Hardware Metadata Storage** (2025-11-28)

The deployment engine now supports storing hardware attributes (manufacturer, model, service tag) for computer objects:

- **Storage Method**: JSON-encoded data in AD "info" attribute
- **Exchange-Safe**: No conflicts with Exchange extensionAttribute fields
- **No Schema Changes**: Uses existing AD schema
- **Optional**: Works with or without hardware data in computers.json
- **Idempotent**: Safe to re-run; updates changed hardware info automatically

> **Backward Compatibility:** The hardware info enhancement is **completely optional**. Existing computers.json files without hardware fields will continue to work perfectly. The deployment engine automatically detects and uses hardware data when present, and gracefully ignores it when absent. No changes to existing configurations are required.

See Section 6.1 (computers.json format) for implementation details.

---

## 2. Folder Layout

Recommended structure:

```
ad_deploy.ps1              # Main AD deployment script (v2.1 with hardware info)
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

DOCUMENTATION/             # Optional documentation (v2.1)
├── IMPLEMENTATION_GUIDE.md                 # Hardware info deployment guide
└── (other documentation files)
```

---

## 3. Prerequisites

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
- Create the forest and instruct you to reboot
- Require a second run post-reboot to apply the exercise configuration

---

## 4. Script Responsibilities

`ad_deploy.ps1` deploys Active Directory configurations based on the contents of the selected `EXERCISES/<ExerciseName>` folder.

### Deployment Order

1. **Forest Detection/Creation**
   - Detects existing AD domain or prompts to create new forest
   - If new forest: installs AD DS role, creates forest, exits with reboot instruction
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

## 5. Script Parameters

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
    [switch]$WhatIf
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

## 6. JSON Configuration Files

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

### 6.1. computers.json Format _(Enhanced in v2.1)_

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

## 7. Execution Workflows

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

### Workflow 2: First-Time Deployment (New Forest)

```powershell
# Run 1: Create forest
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure

# Script will:
# - Generate structure.json from exercise_template.json
# - Detect no domain exists
# - Prompt to create new forest
# - Install AD DS role if needed
# - Create forest
# - Exit with reboot instruction

# Reboot the server

# Run 2: Deploy configuration
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"

# Script will:
# - Detect existing domain
# - Deploy all configuration (sites, OUs, users, etc.)
# - Store hardware info for computers (if provided)
# - Complete successfully
```

### Workflow 3: Updating Existing Exercise

```powershell
# 1. Modify the template
notepad ".\EXERCISES\CHILLED_ROCKET\exercise_template.json"

# 2. Regenerate structure (with force to skip prompt)
.\generate_structure.ps1 -ExerciseName "CHILLED_ROCKET" -Force

# 3. Redeploy (idempotent - only adds/updates changes)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET"
```

### Workflow 4: Idempotent Redeployment

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

### Workflow 5: What-If Mode (Validation)

```powershell
# Test what would happen without making changes
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf

# Shows intended actions in yellow without executing them
```

---

## 8. Execution Flow Details

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
5. **EXIT** with reboot instruction (no deployment yet)

### Phase 4: Configuration Deployment (if domain exists)
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

## 9. Template-Driven Architecture Benefits

The new template-driven approach provides several advantages:

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

# Enable verbose output for debugging
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose

# Test hardware info implementation (v2.1)
.\UTILITIES\Test-HardwareInfoImplementation.ps1
```

---

## 11. Extending This Framework

### Immediate Extensions

You can extend this deployment engine by:

1. **Additional Configuration Files**
   - Cross-forest trusts
   - Service accounts and constrained delegation
   - Custom ACLs or delegation models
   - Fine-grained password policies

2. **Service Deployment Completion**
   - Implement DHCP scope creation
   - Add Certificate Services deployment
   - Configure NTP hierarchy
   - Deploy WINS (if needed for legacy systems)

3. **Template Enhancements**
   - Add schema validation for exercise_template.json
   - Support multiple template versions/formats
   - Include metadata for exercise difficulty, duration, objectives

4. **User Population Automation**
   - Generate realistic user populations at scale
   - Create organizational hierarchies algorithmically
   - Import from CSV or external data sources

5. **Validation and Reporting**
   - Post-deployment validation checks
   - Summary reports for exercise controllers
   - Compliance verification against template
   - Health checks for replication, DNS, GPO application

### Future Enhancements

- **VM Provisioning Integration**: Link computer account creation to automated VM deployment
- **Configuration Drift Detection**: Compare live AD state against JSON configurations
- **Rollback Capability**: Track created objects and offer cleanup/removal mode
- **Multi-Forest Support**: Deploy complex forest trust topologies
- **API Integration**: REST endpoints for exercise orchestration
- **Web UI**: Visual editor for exercise templates

---

## 12. Hardware Info Utilities (v2.1)

The framework includes optional utility scripts for managing hardware metadata:

### Available Utilities

**Location:** `UTILITIES/` directory (recommended)

1. **hardware_info_utility_scripts.ps1** - Management functions
   - `Get-ComputerHardwareInfo` - Query individual computer
   - `Get-AllComputerHardware` - Export all hardware to CSV
   - `Set-ComputerHardwareInfo` - Update hardware for existing computer
   - `Find-ComputerByHardware` - Search by manufacturer/model/tag
   - `New-HardwareInventoryReport` - Generate HTML reports

2. **Test-HardwareInfoImplementation.ps1** - Validation suite
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

## 13. Template Library (Future)

Future releases may include a library of starter templates:

- **Small Enterprise** (1 site, 50 users, minimal infrastructure)
- **Medium Enterprise** (3 sites, 500 users, branch offices)
- **Large Enterprise** (5+ sites, 5000+ users, global infrastructure)
- **Financial Services** (compliance-focused, audit requirements)
- **Healthcare** (HIPAA considerations, department isolation)
- **Manufacturing** (OT/IT integration, site-based structure)
- **Government** (security classifications, compartmentalization)

---

## 14. Best Practices

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

### Maintenance

1. **Regular Updates**: Keep templates synchronized with live changes
2. **Idempotent Runs**: Periodically rerun deployment to ensure consistency
3. **Backup Configurations**: Archive JSON files with exercise versions
4. **Document Changes**: Track template modifications in version control

---

## 15. Quick Reference

### Command Cheat Sheet

```powershell
# Create new exercise from template
.\generate_structure.ps1 -ExerciseName "EXERCISE_NAME"

# Deploy fresh environment
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -GenerateStructure

# Update existing environment
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"

# Test without changes
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME" -WhatIf

# Force regenerate structure
.\generate_structure.ps1 -ExerciseName "EXERCISE_NAME" -Force

# Create new forest + deploy (requires reboot between)
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"  # Run 1: Creates forest
# <reboot>
.\ad_deploy.ps1 -ExerciseName "EXERCISE_NAME"  # Run 2: Deploys config

# Query hardware info (v2.1)
$computer = Get-ADComputer "COMPUTER_NAME" -Properties info
$computer.info | ConvertFrom-Json
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

---

## 16. Support and Contribution

This modular approach enables **rapid iteration** and **repeatable AD builds** for multiple cyber range scenarios.

For questions, issues, or contributions:
- Review existing templates in `EXERCISES/` folders
- Check troubleshooting section for common issues
- Consult PowerShell verbose output for debugging
- Refer to GitHub repositories for updates and examples

Use this framework as the backbone to spin up Stark Industries today… and tear it down tomorrow. 🛡️🧨

---

## Version History

### Version 2.1 (2025-11-28)
**Hardware Metadata Enhancement**
- Added hardware info storage (manufacturer, model, service_tag)
- JSON encoding in AD "info" attribute
- Exchange-safe implementation (no extensionAttributes)
- Utility scripts for hardware management
- Optional feature - backward compatible

### Version 2.0 (2024-11-22)
**Template-Driven Architecture**
- Introduced exercise_template.json
- Separated topology from generation logic
- Enhanced generate_structure.ps1
- Improved maintainability

---

**Version:** 2.1  
**Last Updated:** 2025-11-28  
**Architecture:** Template-Driven Deployment Engine with Hardware Metadata Storage

# POWERSHELL REMOTING DEPLOYMENT GUIDE
**CDX-E Active Directory Remote Deployment via CDX-Internet**  
**Version 2.0 - Unicode-Safe File Transfer**

---

## EXECUTIVE SUMMARY

This guide provides complete procedures for deploying Active Directory infrastructure to domain controllers remotely from **cdx-mgmt-01** using PowerShell Remoting (WinRM) over the CDX-Internet management network. This approach enables centralized management and deployment across all five Stark Industries sites without requiring physical console access to each domain controller.

**Key Benefits:**
- Deploy from single management workstation (cdx-mgmt-01)
- No physical DC access required after initial setup
- Consistent deployment across all sites
- Leverage CDX-Internet OSPF routing for connectivity
- Idempotent operations (safe to re-run)
- **Unicode-safe file transfer** (prevents encoding corruption)
- **Automatic reboot and continuation** (v2.2 - eliminates manual intervention)

**Critical Enhancements:**

**v2.0:** Proper UTF-8 encoding preservation during file transfer to prevent PowerShell syntax errors caused by Unicode characters (checkmarks ✓) in the CDX-E scripts.

**v2.2:** Automatic reboot capability with scheduled task creation for seamless deployment continuation after forest creation. Perfect for remote deployments - no session loss, no manual rerun required.

---

## PREREQUISITES

Before beginning remote deployment:

### On cdx-mgmt-01 (Management Workstation)
- [x] Windows 11 Professional installed
- [x] NIC2 configured with CDX-Internet IP (4.244.16.87/16)
- [x] Static routes configured for all Stark sites
- [x] CDX-E repository cloned to `C:\CDX-E`
- [x] Network connectivity to target DC via CDX-Internet
- [x] PowerShell 5.1 or later
- [x] Administrator credentials for target DC

### On Target DC (e.g., STK-DC-01)
- [x] Windows Server 2022/2025 installed
- [x] OOBE (Out-of-Box Experience) completed
- [x] Static IP configured on CDX-Internet subnet
- [x] Default gateway pointing to site's SDP router
- [x] WinRM enabled and configured
- [x] Firewall rules allowing WinRM (TCP 5985/5986)
- [x] **Built-in Administrator account enabled** (required for AD installation)
- [x] Built-in Administrator password set and documented

---

## DEPLOYMENT ARCHITECTURE

```
cdx-mgmt-01 (4.244.16.87/16)
    │
    ├─ Home Network (NIC1): Internet access, metric 10
    └─ CDX-Internet (NIC2): Management plane, metric 25
           │
           ↓
    IXP-T1-EQIX-4 (Seattle, OSPF Area 4)
           │
           ↓
    OSPF Routing to All Sites
           │
           ├─ HQ Site: STK-DC-01 (66.218.180.10)
           ├─ Dallas Site: STK-DC-02 (50.222.72.10)
           ├─ Malibu Site: STK-DC-03 (4.150.216.10)
           ├─ Nagasaki Site: STK-DC-04 (14.206.0.10)
           └─ Amsterdam Site: STK-DC-05 (37.74.124.10)
```

---

## PHASE 1: TARGET DC PREPARATION

### Step 1.1: Complete OOBE on Target DC

On the target domain controller (console or Proxmox KVM access):

```powershell
# Set computer name
Rename-Computer -NewName "STK-DC-01" -Force

# Configure static IP for CDX-Internet connectivity
# HQ Example: 66.218.180.10/22
New-NetIPAddress -InterfaceAlias "Ethernet" `
    -IPAddress 66.218.180.10 `
    -PrefixLength 22 `
    -DefaultGateway 66.218.180.1

# Set temporary DNS servers (will change after AD installation)
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" `
    -ServerAddresses 8.8.8.8,8.8.4.4

# Verify network configuration
Get-NetIPConfiguration

# Restart to apply computer name
Restart-Computer -Force
```

**Site-Specific IP Configuration:**

| Site | DC Name | IP Address | Subnet Mask | Gateway |
|------|---------|------------|-------------|---------|
| HQ | STK-DC-01 | 66.218.180.10 | /22 | 66.218.180.1 |
| Dallas | STK-DC-02 | 50.222.72.10 | /22 | 50.222.72.1 |
| Malibu | STK-DC-03 | 4.150.216.10 | /22 | 4.150.216.1 |
| Nagasaki | STK-DC-04 | 14.206.0.10 | /22 | 14.206.0.1 |
| Amsterdam | STK-DC-05 | 37.74.124.10 | /23 | 37.74.124.1 |

---

### Step 1.2: Enable PowerShell Remoting on Target DC

After restart, on the target DC (console access):

```powershell
# Enable PowerShell Remoting
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM to allow remote connections
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Configure WinRM service for automatic start
Set-Service WinRM -StartupType Automatic

# Verify WinRM is listening
Test-WSMan -ComputerName localhost

# Expected output:
# wsmid           : http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd
# ProtocolVersion : http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd
# ProductVendor   : Microsoft Corporation
# ProductVersion  : OS: 10.0.20348 SP: 0.0 Stack: 3.0

# Configure Windows Firewall to allow WinRM
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

# Verify firewall rules
Get-NetFirewallRule -DisplayGroup "Windows Remote Management" | 
    Where-Object {$_.Enabled -eq $true} | 
    Select-Object DisplayName, Enabled, Direction
```

---

### Step 1.3: Enable Built-in Administrator Account (Required for Remote Deployment)

**⚠️ CRITICAL:** If your server was cloned from a template that uses a custom local administrator account (e.g., `cdxadmin`), you **must** enable the built-in Administrator account to avoid UAC token filtering issues during AD deployment.

**Why This is Required:**
- Windows applies UAC token filtering to remote PowerShell sessions from local admin accounts
- Even if `cdxadmin` is in the Administrators group, remote sessions receive filtered tokens
- The built-in `Administrator` account is **exempt** from UAC filtering
- Forest installation requires full administrator privileges that filtered tokens don't provide

**On the target DC (console access):**

```powershell
Write-Host "=== Enabling Built-in Administrator Account ===" -ForegroundColor Cyan

# Enable the built-in Administrator account
Enable-LocalUser -Name "Administrator"

# Set a strong password
$password = Read-Host "Enter password for built-in Administrator" -AsSecureString
Set-LocalUser -Name "Administrator" -Password $password

# Verify the account is enabled
$adminAccount = Get-LocalUser -Name "Administrator"
if ($adminAccount.Enabled) {
    Write-Host "[OK] Built-in Administrator account enabled" -ForegroundColor Green
    Write-Host "     Use this account for PowerShell Remoting deployment" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Failed to enable Administrator account" -ForegroundColor Red
}
```

**Alternative: If you prefer to use your custom admin account (e.g., cdxadmin):**

You can disable UAC remote restrictions instead, though this is less secure:

```powershell
Write-Host "=== Disabling UAC Remote Restrictions ===" -ForegroundColor Cyan

# Allow remote admin accounts to receive full tokens
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$regName = "LocalAccountTokenFilterPolicy"

Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Type DWord -Force

# Verify the setting
$value = Get-ItemProperty -Path $regPath -Name $regName | Select-Object -ExpandProperty $regName
if ($value -eq 1) {
    Write-Host "[OK] UAC remote restrictions disabled" -ForegroundColor Green
    Write-Host "     Custom admin accounts can now use full privileges remotely" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Registry setting failed to apply" -ForegroundColor Red
}
```

**Recommendation:** Use the built-in Administrator account for deployment, then disable it after AD installation is complete if desired.

---

### Step 1.4: Verify Connectivity from cdx-mgmt-01

From **cdx-mgmt-01**, test connectivity to the target DC:

```powershell
# Test ICMP (ping)
Test-NetConnection -ComputerName 66.218.180.10

# Test WinRM port (TCP 5985)
Test-NetConnection -ComputerName 66.218.180.10 -Port 5985

# Expected output for WinRM test:
# ComputerName     : 66.218.180.10
# RemoteAddress    : 66.218.180.10
# RemotePort       : 5985
# InterfaceAlias   : Ethernet 2
# SourceAddress    : 4.244.16.87
# TcpTestSucceeded : True

# Test WinRM protocol
Test-WSMan -ComputerName 66.218.180.10

# If test fails, verify:
# 1. Static routes on cdx-mgmt-01 include target subnet
# 2. SDP firewall rules allow management subnet (4.244.16.0/24)
# 3. Target DC firewall has WinRM rules enabled
```

---

## PHASE 2: ESTABLISH REMOTE SESSION FROM CDX-MGMT-01

### Step 2.1: Create PowerShell Remote Session

From **cdx-mgmt-01**:

```powershell
# Prompt for built-in Administrator credentials
$targetDC = "66.218.180.10"
$cred = Get-Credential -UserName "Administrator" `
    -Message "Enter built-in Administrator password for $targetDC"

# Create persistent PowerShell session
$session = New-PSSession -ComputerName $targetDC -Credential $cred

# Verify session state
$session

# Expected output:
# Id Name            ComputerName    ComputerType    State         ConfigurationName     Availability
# -- ----            ------------    ------------    -----         -----------------     ------------
#  1 WinRM1          66.218.180.10   RemoteMachine   Opened        Microsoft.PowerShell     Available
```

**Note:** Using the built-in `Administrator` account ensures you have full privileges without UAC token filtering issues.

---

### Step 2.2: Test Remote Execution

```powershell
# Test basic command execution in remote session
Invoke-Command -Session $session -ScriptBlock {
    Write-Host "Connected to: $env:COMPUTERNAME" -ForegroundColor Green
    
    # Display network configuration
    Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"} | 
        Select-Object IPAddress, InterfaceAlias, PrefixLength
    
    # Display available disk space
    Get-Volume | Where-Object {$_.DriveLetter -eq "C"} | 
        Select-Object DriveLetter, FileSystemLabel, 
            @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}},
            @{Name="Free(GB)";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}
}

# If successful, you should see:
# - Computer name (e.g., STK-DC-01)
# - IP configuration showing 66.218.180.10
# - Disk space information
```

---

## PHASE 3: TRANSFER CDX-E REPOSITORY (UNICODE-SAFE METHOD)

### ⚠️ CRITICAL: Why Unicode-Safe Transfer is Required

The CDX-E PowerShell scripts (`ad_deploy.ps1` and `generate_structure.ps1`) contain Unicode characters such as checkmarks (✓) in output messages:

```powershell
# Example from generate_structure.ps1 (line 236):
Write-Host "[Generator] ✓ Structure file generated successfully!" -ForegroundColor Green
```

**The Problem:**
- Standard `Copy-Item -ToSession` does **NOT** preserve UTF-8 encoding
- Unicode characters get corrupted during transfer
- PowerShell interprets corrupted characters as unterminated strings
- Deployment fails with syntax errors at line 234/236

**The Solution:**
- Read file content with explicit UTF-8 encoding
- Transfer content as a parameter via `Invoke-Command`
- Write content with explicit UTF-8 encoding on remote system
- Validate syntax after transfer

---

### Step 3.1: Create Destination Folder on DC

```powershell
Invoke-Command -Session $session -ScriptBlock {
    # Create deployment directory
    New-Item -ItemType Directory -Path "C:\CDX-Deploy" -Force | Out-Null
    Write-Host "[OK] Created C:\CDX-Deploy" -ForegroundColor Green
    
    # Create EXERCISES subdirectory
    New-Item -ItemType Directory -Path "C:\CDX-Deploy\EXERCISES" -Force | Out-Null
    Write-Host "[OK] Created C:\CDX-Deploy\EXERCISES" -ForegroundColor Green
}
```

---

### Step 3.2: Transfer PowerShell Scripts (UTF-8 Encoding Preserved)

**Use this method for all .ps1 files to prevent corruption:**

```powershell
Write-Host "`n=== Transferring PowerShell Scripts (UTF-8 Safe) ===" -ForegroundColor Cyan

# Transfer ad_deploy.ps1 with UTF-8 encoding preservation
Write-Host "[1/2] Transferring ad_deploy.ps1..." -ForegroundColor Yellow

$adDeployContent = Get-Content "C:\CDX-E\ad_deploy.ps1" -Raw -Encoding UTF8

Invoke-Command -Session $session -ScriptBlock {
    param($content)
    Set-Content -Path "C:\CDX-Deploy\ad_deploy.ps1" -Value $content -Encoding UTF8 -Force
} -ArgumentList $adDeployContent

Write-Host "      [OK] ad_deploy.ps1 transferred" -ForegroundColor Green

# Transfer generate_structure.ps1 with UTF-8 encoding preservation
Write-Host "[2/2] Transferring generate_structure.ps1..." -ForegroundColor Yellow

$generateStructureContent = Get-Content "C:\CDX-E\generate_structure.ps1" -Raw -Encoding UTF8

Invoke-Command -Session $session -ScriptBlock {
    param($content)
    Set-Content -Path "C:\CDX-Deploy\generate_structure.ps1" -Value $content -Encoding UTF8 -Force
} -ArgumentList $generateStructureContent

Write-Host "      [OK] generate_structure.ps1 transferred" -ForegroundColor Green

# Validate script syntax on remote system
Write-Host "`nValidating transferred scripts..." -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    $scripts = @("ad_deploy.ps1", "generate_structure.ps1")
    $allValid = $true
    
    foreach ($script in $scripts) {
        $scriptPath = "C:\CDX-Deploy\$script"
        $errors = $null
        
        # Parse script to detect syntax errors
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $scriptPath -Raw), 
            [ref]$errors
        )
        
        if ($errors.Count -eq 0) {
            Write-Host "  [VALID] $script - syntax OK" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] $script - syntax errors detected:" -ForegroundColor Red
            $errors | Format-Table Line, Message -AutoSize
            $allValid = $false
        }
    }
    
    if ($allValid) {
        Write-Host "`n[SUCCESS] All PowerShell scripts validated!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "`n[FAILURE] Syntax errors detected - DO NOT PROCEED" -ForegroundColor Red
        return $false
    }
}
```

**Expected Output:**
```
=== Transferring PowerShell Scripts (UTF-8 Safe) ===
[1/2] Transferring ad_deploy.ps1...
      [OK] ad_deploy.ps1 transferred
[2/2] Transferring generate_structure.ps1...
      [OK] generate_structure.ps1 transferred

Validating transferred scripts...
  [VALID] ad_deploy.ps1 - syntax OK
  [VALID] generate_structure.ps1 - syntax OK

[SUCCESS] All PowerShell scripts validated!
```

---

### Step 3.3: Transfer JSON Configuration Files (Standard Method)

**JSON files don't contain Unicode decorations, so standard copy is safe:**

```powershell
Write-Host "`n=== Transferring Exercise Configuration Files ===" -ForegroundColor Cyan

# Copy entire CHILLED_ROCKET exercise folder
Copy-Item -Path "C:\CDX-E\EXERCISES\CHILLED_ROCKET" `
    -Destination "C:\CDX-Deploy\EXERCISES\" `
    -ToSession $session `
    -Recurse -Force

Write-Host "[OK] CHILLED_ROCKET exercise folder copied" -ForegroundColor Green

# Verify critical configuration files exist
Invoke-Command -Session $session -ScriptBlock {
    $exercisePath = "C:\CDX-Deploy\EXERCISES\CHILLED_ROCKET"
    
    Write-Host "`nVerifying CHILLED_ROCKET exercise files..." -ForegroundColor Cyan
    
    $requiredFiles = @(
        "exercise_template.json",
        "users.json",
        "computers.json",
        "services.json",
        "gpo.json"
    )
    
    $allPresent = $true
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $exercisePath $file
        if (Test-Path $filePath) {
            $fileSize = [math]::Round((Get-Item $filePath).Length / 1KB, 2)
            Write-Host "  [OK] $file ($fileSize KB)" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $file" -ForegroundColor Red
            $allPresent = $false
        }
    }
    
    if ($allPresent) {
        Write-Host "`n[SUCCESS] All required configuration files present!" -ForegroundColor Green
    } else {
        Write-Host "`n[WARNING] Some files are missing - verify transfer" -ForegroundColor Yellow
    }
}
```

**Expected Output:**
```
=== Transferring Exercise Configuration Files ===
[OK] CHILLED_ROCKET exercise folder copied

Verifying CHILLED_ROCKET exercise files...
  [OK] exercise_template.json (8.45 KB)
  [OK] users.json (42.31 KB)
  [OK] computers.json (195.67 KB)
  [OK] services.json (3.21 KB)
  [OK] gpo.json (1.89 KB)

[SUCCESS] All required configuration files present!
```

---

## PHASE 4: EXECUTE AD DEPLOYMENT (FIRST RUN - FOREST CREATION)

### Step 4.1: First Deployment Run (Creates Forest) - Traditional Method

**This run will:**
1. Generate `structure.json` from `exercise_template.json`
2. Detect no existing AD domain
3. Prompt to create new forest
4. Install AD DS role (if needed)
5. Create `stark.local` forest
6. Exit with manual reboot instruction

```powershell
Write-Host "`n=== Starting AD Deployment (Forest Creation - Manual Reboot) ===" -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    
    # Run with -GenerateStructure to create structure.json
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -Verbose
}
```

**Expected Prompts:**
```
Exercise Name  : CHILLED_ROCKET
Config Path    : C:\CDX-Deploy\EXERCISES\CHILLED_ROCKET

[Generator] Loading template from: exercise_template.json
[Generator] Template loaded: CHILLED_ROCKET
[Generator] ✓ Structure file generated successfully!

[Domain] No existing AD domain detected.

Would you like to create a new AD forest? (Y/N): Y
Enter domain FQDN (e.g., stark.local): stark.local
Enter domain NetBIOS name (e.g., STARK): STARK

[Forest] Installing AD DS role...
[Forest] Creating new forest: stark.local
[Forest] Enter DSRM password: ********

... (forest creation proceeds) ...

[Forest] Forest created successfully!
[Forest] REBOOT REQUIRED - please restart and rerun this script.
```

**Interactive Responses:**
- "Would you like to create a new AD forest?" → **Y**
- "Enter domain FQDN" → **stark.local**
- "Enter domain NetBIOS name" → **STARK**
- "Enter DSRM password" → **Complex password (meets requirements)**

---

### Step 4.1B: First Deployment Run (Creates Forest) - AUTOMATIC REBOOT ⚡ (v2.2)

**NEW in v2.2:** Fully automated forest creation with automatic reboot and deployment continuation.

**This run will:**
1. Generate `structure.json` from `exercise_template.json`
2. Detect no existing AD domain
3. Prompt to create new forest
4. Install AD DS role (if needed)
5. Create `stark.local` forest
6. **Detect remote PSSession**
7. **Create scheduled task for post-reboot deployment**
8. **Display 30-second countdown (cancelable with Ctrl+C)**
9. **Automatically reboot system**
10. **Auto-resume deployment after reboot via scheduled task**

```powershell
Write-Host "`n=== Starting AD Deployment (Forest Creation - AUTO-REBOOT) ===" -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    
    # Run with -GenerateStructure AND -AutoReboot flags
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot -Verbose
}
```

**Expected Output:**
```
Exercise Name  : CHILLED_ROCKET
Config Path    : C:\CDX-Deploy\EXERCISES\CHILLED_ROCKET
Auto-Reboot    : ENABLED (30s countdown)

[Generator] Loading template from: exercise_template.json
[Generator] Template loaded: CHILLED_ROCKET
[Generator] ✓ Structure file generated successfully!

[Domain] No existing AD domain detected.

Would you like to create a new AD forest? (Y/N): Y
Enter domain FQDN (e.g., stark.local): stark.local
Enter domain NetBIOS name (e.g., STARK): STARK

[Forest] Installing AD DS role...
[Forest] Creating new forest: stark.local
[Forest] Enter DSRM password: ********

... (forest creation proceeds) ...

[Domain] ✓ New forest created successfully!

=====================================================
           AUTOMATIC REBOOT INITIATED
=====================================================

[AutoReboot] Remote PowerShell session detected
[AutoReboot] Creating scheduled task for post-reboot deployment...
[AutoReboot] ✓ Scheduled task created successfully
              Task Name: CDX-PostReboot-Deployment
              Will execute: C:\CDX-Deploy\ad_deploy.ps1
              With exercise: CHILLED_ROCKET

[AutoReboot] Post-reboot deployment will continue automatically!

[AutoReboot] System will RESTART in 30 seconds...
[AutoReboot] Press Ctrl+C NOW to cancel automatic reboot

[AutoReboot] Restarting in 30 seconds...
[AutoReboot] Restarting in 29 seconds...
[AutoReboot] Restarting in 28 seconds...
...
[AutoReboot] Restarting NOW...
[AutoReboot] Executing system restart...
=====================================================
```

**What Happens Next (Automatic):**
1. **System reboots** (~2 minutes)
2. **Scheduled task triggers** at system startup
3. **Deployment continues** automatically (Sites, OUs, Users, Computers, etc.)
4. **Task self-deletes** after successful completion
5. **You get notification** that deployment is complete

**Benefits:**
- ✅ **Zero manual intervention** after initial prompts
- ✅ **No session loss** - scheduled task handles continuation
- ✅ **No manual rerun** required
- ✅ **Faster deployment** - eliminates waiting time
- ✅ **Perfect for remote deployments** - maintains context

**Custom Countdown:**
```powershell
# 60-second countdown instead of default 30 seconds
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot -RebootDelaySeconds 60
}
```

**Cancel Reboot:**
- Press **Ctrl+C** during countdown
- Script exits with manual reboot instruction
- No scheduled task created

---

### Step 4.2: Wait for DC Reboot (Traditional Method Only)

```powershell
Write-Host "`n[INFO] Waiting for DC to reboot after forest creation..." -ForegroundColor Yellow
Write-Host "[INFO] This typically takes 3-5 minutes" -ForegroundColor Yellow

# Close existing session (will be invalid after reboot)
Remove-PSSession $session

# Wait for DC to come back online
$dcOnline = $false
$attempts = 0
$maxAttempts = 20

while (-not $dcOnline -and $attempts -lt $maxAttempts) {
    Start-Sleep -Seconds 15
    $attempts++
    
    Write-Host "[Attempt $attempts/$maxAttempts] Testing connectivity..." -ForegroundColor Gray
    
    $testResult = Test-NetConnection -ComputerName $targetDC -Port 5985 -WarningAction SilentlyContinue
    
    if ($testResult.TcpTestSucceeded) {
        $dcOnline = $true
        Write-Host "[SUCCESS] DC is online!" -ForegroundColor Green
    }
}

if (-not $dcOnline) {
    Write-Host "[ERROR] DC did not come back online within expected time" -ForegroundColor Red
    Write-Host "[ACTION] Verify DC status via Proxmox console" -ForegroundColor Yellow
    exit
}
```

---

### Step 4.3: Reconnect with Domain Credentials

After reboot, the DC is now a domain controller. Reconnect using **domain credentials**:

```powershell
Write-Host "`n=== Reconnecting with Domain Credentials ===" -ForegroundColor Cyan

# Domain Administrator credentials (not local Administrator)
$domainCred = Get-Credential -UserName "STARK\Administrator" `
    -Message "Enter domain Administrator password (use DSRM password)"

# Create new session with domain credentials
$session = New-PSSession -ComputerName $targetDC -Credential $domainCred

# Verify session
$session

Write-Host "[OK] Session re-established with domain credentials" -ForegroundColor Green
```

---

## PHASE 5: EXECUTE AD DEPLOYMENT (SECOND RUN - EXERCISE CONFIGURATION)

### Step 5.1: Second Deployment Run - Traditional Method

**⚠️ SKIP THIS STEP if you used `-AutoReboot` - deployment continues automatically**

**Only follow these steps if you used traditional manual reboot method:**

After manually rebooting and reconnecting with domain credentials, run the deployment:

**This run will:**
1. Detect existing `stark.local` domain
2. Deploy AD Sites, Subnets, Site Links
3. Create OU hierarchy
4. Create security groups
5. Configure DNS zones
6. Create/link GPOs
7. Pre-stage computer objects (with hardware info if present)
8. Create user accounts

```powershell
Write-Host "`n=== Starting AD Deployment (Exercise Configuration) ===" -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    
    # Run WITHOUT -GenerateStructure (structure.json already exists)
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
}
```

**Expected Output:**
```
=====================================================
     Active Directory Deployment Engine
          Hardware Info Enhanced v2.1
=====================================================

Exercise Name  : CHILLED_ROCKET
Config Path    : C:\CDX-Deploy\EXERCISES\CHILLED_ROCKET

[Domain] Existing AD domain detected: stark.local
=== MODE: POST-FOREST CONFIGURATION / EXERCISE DEPLOYMENT ===

[1] Deploying AD Sites, Subnets, and Site Links...
[Site] Creating site: HQ
[Site] Creating site: Malibu
[Site] Creating site: Dallas
[Site] Creating site: Nagasaki
[Site] Creating site: Amsterdam

[Subnet] Linking 66.218.180.0/22 -> HQ
[Subnet] Linking 4.150.216.0/22 -> Malibu
... (continues for all subnets) ...

[SiteLink] Creating: HQ-Dallas (Cost: 100)
[SiteLink] Creating: HQ-Malibu (Cost: 50)
... (continues for all site links) ...

[2] Creating Organizational Units...
[OU] Creating: Sites
[OU] Creating: HQ
[OU] Creating: IT-Core
... (continues for all OUs) ...

[3] Creating Security Groups...
[Group] Creating: Domain Administrators
[Group] Creating: HQ-IT-Admins
... (continues for all groups) ...

[4] Configuring DNS...
[DNS] Creating forward zone: stark.local
[DNS] Creating reverse zone: 180.218.66.in-addr.arpa
... (continues for all zones) ...

[5] Deploying Group Policy Objects...
[GPO] Creating: Baseline Workstation Policy
[GPO] Linking to: OU=Workstations,OU=IT-Core,OU=HQ,OU=Sites
... (continues for all GPOs) ...

[6] Creating Computer Accounts...
[Computer] Creating: HQ-DC-01 (Dell PowerEdge R640)
[Computer] Creating: HQ-DC-02 (Dell PowerEdge R640)
... (continues for all 343 computers) ...

[7] Creating User Accounts...
[User] Creating: tony.stark (CEO)
[User] Creating: pepper.potts (COO)
... (continues for all users) ...

[8] Deployment complete!
Summary:
  - Sites: 5
  - Subnets: 41
  - Site Links: 4
  - OUs: 65
  - Groups: 58
  - Computers: 343
  - Users: 543
  - GPOs: 2
```

---

### Step 5.1B: Verify Auto-Deployment Completion (Auto-Reboot Method) ⚡ (v2.2)

**If you used `-AutoReboot` flag, the deployment continues automatically after reboot.**

**To verify deployment completed successfully:**

```powershell
# Reconnect to DC after it comes back online
Write-Host "`n=== Verifying Auto-Deployment Completion ===" -ForegroundColor Cyan

# Wait for DC to come back online (typically 3-5 minutes)
$dcOnline = $false
$attempts = 0
$maxAttempts = 20

Write-Host "[INFO] Waiting for DC to complete reboot..." -ForegroundColor Yellow

while (-not $dcOnline -and $attempts -lt $maxAttempts) {
    Start-Sleep -Seconds 15
    $attempts++
    
    Write-Host "[Attempt $attempts/$maxAttempts] Testing connectivity..." -ForegroundColor Gray
    
    $testResult = Test-NetConnection -ComputerName $targetDC -Port 5985 -WarningAction SilentlyContinue
    
    if ($testResult.TcpTestSucceeded) {
        $dcOnline = $true
        Write-Host "[SUCCESS] DC is online!" -ForegroundColor Green
    }
}

# Reconnect with domain credentials
$domainCred = Get-Credential -UserName "STARK\Administrator" `
    -Message "Enter domain Administrator password (DSRM password)"

$session = New-PSSession -ComputerName $targetDC -Credential $domainCred

# Check if scheduled task still exists (should be deleted after completion)
$taskStatus = Invoke-Command -Session $session -ScriptBlock {
    $task = Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -ErrorAction SilentlyContinue
    
    if ($task) {
        Write-Host "[WARNING] Scheduled task still exists - deployment may be in progress" -ForegroundColor Yellow
        Write-Host "          Wait a few more minutes and check again" -ForegroundColor Yellow
        return "Running"
    } else {
        Write-Host "[SUCCESS] Scheduled task removed - deployment completed!" -ForegroundColor Green
        return "Completed"
    }
}

# Verify deployment results
if ($taskStatus -eq "Completed") {
    Write-Host "`n=== Deployment Verification ===" -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        Import-Module ActiveDirectory
        
        Write-Host "`nDeployment Statistics:" -ForegroundColor Cyan
        Write-Host "  Sites      : $((Get-ADReplicationSite -Filter *).Count)" -ForegroundColor Green
        Write-Host "  OUs        : $((Get-ADOrganizationalUnit -Filter *).Count)" -ForegroundColor Green
        Write-Host "  Computers  : $((Get-ADComputer -Filter *).Count)" -ForegroundColor Green
        Write-Host "  Users      : $((Get-ADUser -Filter *).Count)" -ForegroundColor Green
        Write-Host "  Groups     : $((Get-ADGroup -Filter *).Count)" -ForegroundColor Green
        
        Write-Host "`n✅ AUTO-DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    }
}
```

**Expected Timeline:**
- Forest creation: ~5 minutes
- Reboot + countdown: ~2.5 minutes
- Post-reboot deployment: ~3-5 minutes
- **Total: ~10-12 minutes** (fully automated!)

---

### Step 5.2: Post-Deployment Validation

```powershell
Write-Host "`n=== Post-Deployment Validation ===" -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    Import-Module ActiveDirectory
    
    Write-Host "`nAD Sites:" -ForegroundColor Yellow
    Get-ADReplicationSite -Filter * | Select-Object Name, Description | Format-Table
    
    Write-Host "OUs (sample):" -ForegroundColor Yellow
    Get-ADOrganizationalUnit -Filter * | 
        Select-Object -First 10 Name, DistinguishedName | 
        Format-Table -AutoSize
    
    Write-Host "Computers (sample):" -ForegroundColor Yellow
    Get-ADComputer -Filter * | 
        Select-Object -First 10 Name, DNSHostName | 
        Format-Table -AutoSize
    
    Write-Host "Users (sample):" -ForegroundColor Yellow
    Get-ADUser -Filter * | 
        Select-Object -First 10 Name, SamAccountName, UserPrincipalName | 
        Format-Table -AutoSize
    
    Write-Host "Deployment Statistics:" -ForegroundColor Cyan
    Write-Host "  Sites      : $((Get-ADReplicationSite -Filter *).Count)"
    Write-Host "  OUs        : $((Get-ADOrganizationalUnit -Filter *).Count)"
    Write-Host "  Computers  : $((Get-ADComputer -Filter *).Count)"
    Write-Host "  Users      : $((Get-ADUser -Filter *).Count)"
    Write-Host "  Groups     : $((Get-ADGroup -Filter *).Count)"
}
```

---

## PHASE 6: DEPLOY ADDITIONAL DOMAIN CONTROLLERS

### Step 6.1: Provision Secondary DCs

Repeat PHASE 1 for each additional DC:

| Site | DC Name | IP Address | Role |
|------|---------|------------|------|
| HQ | STK-DC-02 | 66.218.180.11 | Secondary DC |
| Dallas | STK-DC-02 | 50.222.72.10 | Primary DC for site |
| Malibu | STK-DC-03 | 4.150.216.10 | Primary DC for site |
| Nagasaki | STK-DC-04 | 14.206.0.10 | Primary DC for site |
| Amsterdam | STK-DC-05 | 37.74.124.10 | Primary DC for site |

---

### Step 6.2: Join Additional DCs to Domain

For each secondary/site DC (example: STK-DC-02 at Dallas):

```powershell
# From cdx-mgmt-01
$targetDC2 = "50.222.72.10"  # STK-DC-02 (Dallas)

# Create session with LOCAL credentials
$localCred = Get-Credential -UserName "Administrator" `
    -Message "Enter LOCAL Administrator password for STK-DC-02"
$session2 = New-PSSession -ComputerName $targetDC2 -Credential $localCred

# Promote to domain controller
Invoke-Command -Session $session2 -ScriptBlock {
    param($domainName, $domainCred)
    
    # Install AD DS role
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    
    # Promote to DC in existing domain
    Install-ADDSDomainController `
        -DomainName $domainName `
        -Credential $domainCred `
        -InstallDns `
        -Force
        
} -ArgumentList "stark.local", $domainCred

# DC will reboot automatically
Write-Host "[INFO] DC promotion initiated - system will reboot" -ForegroundColor Yellow
```

---

### Step 6.3: Verify AD Replication

After all DCs are online:

```powershell
# Reconnect to primary DC (STK-DC-01)
$session = New-PSSession -ComputerName "66.218.180.10" -Credential $domainCred

Invoke-Command -Session $session -ScriptBlock {
    # Check replication status
    Get-ADReplicationPartnerMetadata -Target * -Scope Domain | 
        Select-Object Server, Partner, LastReplicationSuccess, 
            ConsecutiveReplicationFailures | 
        Format-Table -AutoSize
    
    # Verify all DCs are visible
    Write-Host "`nDomain Controllers:" -ForegroundColor Cyan
    Get-ADDomainController -Filter * | 
        Select-Object Name, Site, IPv4Address, IsGlobalCatalog | 
        Format-Table -AutoSize
}
```

---

## PHASE 7: MULTI-SITE DEPLOYMENT MANAGEMENT

### Step 7.1: Create Sessions to All DCs

```powershell
Write-Host "`n=== Creating Sessions to All DCs ===" -ForegroundColor Cyan

$domainCred = Get-Credential -UserName "STARK\Administrator"

$dcEndpoints = @{
    "STK-DC-01" = "66.218.180.10"  # HQ
    "STK-DC-02" = "50.222.72.10"   # Dallas
    "STK-DC-03" = "4.150.216.10"   # Malibu
    "STK-DC-04" = "14.206.0.10"    # Nagasaki
    "STK-DC-05" = "37.74.124.10"   # Amsterdam
}

$sessions = @{}

foreach ($dc in $dcEndpoints.Keys) {
    $ip = $dcEndpoints[$dc]
    
    Write-Host "Connecting to $dc ($ip)..." -ForegroundColor Yellow
    
    try {
        $sessions[$dc] = New-PSSession -ComputerName $ip -Credential $domainCred -ErrorAction Stop
        Write-Host "  [OK] Connected to $dc" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to connect to $dc`: $_" -ForegroundColor Red
    }
}

Write-Host "`n[SUCCESS] Connected to $($sessions.Count) domain controllers" -ForegroundColor Green
```

---

### Step 7.2: Execute Commands Across All DCs

```powershell
# Example: Check AD replication status on all DCs
Invoke-Command -Session $sessions.Values -ScriptBlock {
    $dcName = $env:COMPUTERNAME
    
    Write-Host "`n=== $dcName ===" -ForegroundColor Cyan
    
    # Replication status
    $replStatus = Get-ADReplicationPartnerMetadata -Target * -Scope Domain | 
        Where-Object {$_.Server -eq $dcName}
    
    Write-Host "Replication Partners: $($replStatus.Count)"
    Write-Host "Last Replication: $($replStatus[0].LastReplicationSuccess)"
    
    # FSMO roles (if held)
    $domain = Get-ADDomain
    $forest = Get-ADForest
    
    $roles = @()
    if ($domain.PDCEmulator -like "*$dcName*") { $roles += "PDC Emulator" }
    if ($domain.RIDMaster -like "*$dcName*") { $roles += "RID Master" }
    if ($domain.InfrastructureMaster -like "*$dcName*") { $roles += "Infrastructure Master" }
    if ($forest.SchemaMaster -like "*$dcName*") { $roles += "Schema Master" }
    if ($forest.DomainNamingMaster -like "*$dcName*") { $roles += "Domain Naming Master" }
    
    if ($roles.Count -gt 0) {
        Write-Host "FSMO Roles: $($roles -join ', ')" -ForegroundColor Yellow
    }
}
```

---

### Error 6: Auto-Reboot Scheduled Task Issues (v2.2)

**Symptom 1: Scheduled task not created**
```
[AutoReboot] Failed to create scheduled task: Access is denied
```

**Cause:**
- Insufficient permissions
- Task Scheduler service not running
- Group Policy blocking scheduled task creation

**Solution:**
```powershell
# Verify you're running as Administrator
Invoke-Command -Session $session -ScriptBlock {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Host "[OK] Running with Administrator privileges" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Not running as Administrator" -ForegroundColor Red
    }
    
    # Check Task Scheduler service
    $schedSvc = Get-Service -Name "Schedule"
    Write-Host "Task Scheduler Status: $($schedSvc.Status)"
}

# Manual workaround: Just reboot and rerun script manually
# The auto-reboot is a convenience feature, not required
```

---

**Symptom 2: Deployment didn't continue after reboot**
```
Scheduled task exists but deployment not completed
```

**Cause:**
- Task execution failed
- Script path incorrect
- Permissions issue

**Solution:**
```powershell
# Check task execution history
Invoke-Command -Session $session -ScriptBlock {
    $task = Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -ErrorAction SilentlyContinue
    
    if ($task) {
        # Get task info
        $taskInfo = Get-ScheduledTaskInfo -TaskName "CDX-PostReboot-Deployment"
        Write-Host "Last Run Time: $($taskInfo.LastRunTime)"
        Write-Host "Last Result: $($taskInfo.LastTaskResult)"
        Write-Host "Next Run Time: $($taskInfo.NextRunTime)"
        
        # Check if script path is correct
        $action = (Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment").Actions[0]
        Write-Host "Script Path: $($action.Arguments)"
        
        # Manually trigger the task for testing
        Start-ScheduledTask -TaskName "CDX-PostReboot-Deployment"
    } else {
        Write-Host "[INFO] Task not found - may have completed and self-deleted" -ForegroundColor Green
    }
}

# If task failed, manually run deployment:
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
}

# Then manually remove the task
Invoke-Command -Session $session -ScriptBlock {
    Unregister-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -Confirm:$false
}
```

---

**Symptom 3: Want to cancel auto-reboot**
```
[AutoReboot] Restarting in 30 seconds...
```

**Solution:**
- Press **Ctrl+C** during countdown to cancel
- Script will exit with manual reboot instruction
- No scheduled task will be created
- You can manually reboot when ready

---

## ADVANCED SCENARIOS

### Scenario 1: Deploy with Custom Parameters

```powershell
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    
    # Override domain detection
    .\ad_deploy.ps1 `
        -ExerciseName "CHILLED_ROCKET" `
        -DomainFQDN "stark.local" `
        -DomainDN "DC=stark,DC=local" `
        -Verbose
}
```

---

### Scenario 2: WhatIf Mode (Test Without Changes)

```powershell
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    
    # See what would be created without actually creating it
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf
}
```

---

### Scenario 3: Auto-Reboot with Custom Delay (v2.2)

```powershell
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    
    # 60-second countdown instead of default 30 seconds
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot -RebootDelaySeconds 60
}
```

---

### Scenario 4: Monitor Auto-Deployment Progress (v2.2)

```powershell
# After auto-reboot initiated, monitor from cdx-mgmt-01

Write-Host "Monitoring auto-deployment progress..." -ForegroundColor Cyan

# Wait for reboot to complete
Start-Sleep -Seconds 120

# Poll for task completion
$deploymentComplete = $false
$attempts = 0

while (-not $deploymentComplete -and $attempts -lt 20) {
    Start-Sleep -Seconds 30
    $attempts++
    
    try {
        # Try to reconnect
        $domainCred = Get-Credential -UserName "STARK\Administrator"
        $monitorSession = New-PSSession -ComputerName $targetDC -Credential $domainCred -ErrorAction Stop
        
        $taskStatus = Invoke-Command -Session $monitorSession -ScriptBlock {
            Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -ErrorAction SilentlyContinue
        }
        
        if (-not $taskStatus) {
            Write-Host "[SUCCESS] Deployment completed! (Task self-deleted)" -ForegroundColor Green
            $deploymentComplete = $true
        } else {
            Write-Host "[Attempt $attempts] Deployment still in progress..." -ForegroundColor Yellow
        }
        
        Remove-PSSession $monitorSession
    }
    catch {
        Write-Host "[Attempt $attempts] DC not ready yet..." -ForegroundColor Gray
    }
}
```

---

### Scenario 5: Retrieve Deployment Logs

```powershell
# Copy PowerShell transcript from DC
$logFiles = Invoke-Command -Session $session -ScriptBlock {
    Get-ChildItem "C:\CDX-Deploy" -Filter "*.log" | Select-Object FullName
}

foreach ($log in $logFiles) {
    Copy-Item -Path $log.FullName `
        -Destination "C:\Logs\" `
        -FromSession $session
}
```

---

### Scenario 4: Incremental Updates

```powershell
# After modifying exercise_template.json locally
# 1. Transfer updated template
$templateContent = Get-Content "C:\CDX-E\EXERCISES\CHILLED_ROCKET\exercise_template.json" -Raw

Invoke-Command -Session $session -ScriptBlock {
    param($content)
    Set-Content -Path "C:\CDX-Deploy\EXERCISES\CHILLED_ROCKET\exercise_template.json" `
        -Value $content -Force
} -ArgumentList $templateContent

# 2. Regenerate structure.json
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\generate_structure.ps1 -ExerciseName "CHILLED_ROCKET" -Force
}

# 3. Redeploy (idempotent - only creates missing objects)
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
}
```

---

## ERROR HANDLING

### Error 1: Session Timeout

**Symptom:**
```
Invoke-Command : The network path was not found.
```

**Solution:**
```powershell
# Test if session is still alive
if ($session.State -ne "Opened") {
    Write-Host "[WARNING] Session closed - reconnecting..." -ForegroundColor Yellow
    Remove-PSSession $session
    $session = New-PSSession -ComputerName $targetDC -Credential $domainCred
}
```

---

### Error 2: Deployment Fails Mid-Process

**Symptom:**
Deployment stops with errors in OU creation, user creation, etc.

**Solution:**
```powershell
# Review error output
# Deployment is idempotent - just re-run
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose
}

# Script will skip existing objects and create only what's missing
```

---

### Error 3: WinRM Connection Drops

**Symptom:**
```
The WinRM client cannot process the request.
```

**Solution:**
```powershell
# Increase WinRM timeout
Set-Item WSMan:\localhost\Client\NetworkDelayms -Value 15000

# Or use HTTPS for more reliable connections
$sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
$session = New-PSSession -ComputerName $targetDC `
    -Credential $domainCred `
    -UseSSL `
    -SessionOption $sessionOption
```

---

### Error 4: Unicode Corruption (Script Syntax Errors)

**Symptom:**
```
The string is missing the terminator: ".
At C:\CDX-Deploy\generate_structure.ps1:234 char:5
```

**Solution:**
This means UTF-8 encoding was not preserved during transfer. Re-transfer using the UTF-8 safe method from Step 3.2:

```powershell
# Re-transfer with proper encoding
$scriptContent = Get-Content "E:\Git\CDX-E\generate_structure.ps1" -Raw -Encoding UTF8

Invoke-Command -Session $session -ScriptBlock {
    param($content)
    Set-Content -Path "C:\CDX-Deploy\generate_structure.ps1" `
        -Value $content -Encoding UTF8 -Force
    
    # Validate
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize(
        (Get-Content "C:\CDX-Deploy\generate_structure.ps1" -Raw), 
        [ref]$errors
    )
    
    if ($errors.Count -eq 0) {
        Write-Host "[OK] Script syntax validated" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Still has errors" -ForegroundColor Red
        $errors | Format-Table
    }
} -ArgumentList $scriptContent
```

---

### Error 5: UAC Token Filtering (Insufficient Privileges)

**Symptom:**
```
Failed to install Active Directory Domain Services Role: You do not have adequate 
user rights to make changes to the target computer.
```

**Cause:**
You're using a custom local administrator account (e.g., `cdxadmin`) instead of the built-in Administrator account. Windows applies UAC token filtering to remote sessions from local admin accounts, resulting in insufficient privileges for AD installation.

**Solution 1 - Use Built-in Administrator (Recommended):**

On target DC (console access):
```powershell
# Enable built-in Administrator account
Enable-LocalUser -Name "Administrator"

# Set password
$password = Read-Host "Enter password for Administrator" -AsSecureString
Set-LocalUser -Name "Administrator" -Password $password
```

From cdx-mgmt-01:
```powershell
# Reconnect with built-in Administrator
Remove-PSSession $session

$adminCred = Get-Credential -UserName "Administrator"
$session = New-PSSession -ComputerName $targetDC -Credential $adminCred

# Retry deployment
Invoke-Command -Session $session -ScriptBlock {
    Set-Location C:\CDX-Deploy
    .\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -Verbose
}
```

**Solution 2 - Disable UAC Remote Restrictions (Less Secure):**

On target DC:
```powershell
# Disable UAC token filtering for remote admin accounts
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force

# Verify
Get-ItemProperty -Path $regPath | Select-Object LocalAccountTokenFilterPolicy
```

From cdx-mgmt-01:
```powershell
# Reconnect session to apply new token
Remove-PSSession $session
$session = New-PSSession -ComputerName $targetDC -Credential $cred

# Verify privileges
Invoke-Command -Session $session -ScriptBlock {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Host "Has Admin Privileges: $isAdmin"
}

# Retry deployment if privileges verified
```

---

## SECURITY CONSIDERATIONS

### Credential Management

```powershell
# Store credentials securely during session
$securePassword = Read-Host "Enter password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential("STARK\Administrator", $securePassword)

# Clear credentials when done
Remove-Variable cred, securePassword
```

---

### HTTPS Sessions (Production Recommendation)

```powershell
# Configure DC for HTTPS WinRM (requires certificate)
Invoke-Command -Session $session -ScriptBlock {
    # Create self-signed cert for testing
    $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME `
        -CertStoreLocation Cert:\LocalMachine\My
    
    # Create HTTPS listener
    New-Item -Path WSMan:\localhost\Listener -Transport HTTPS `
        -Address * -CertificateThumbPrint $cert.Thumbprint -Force
    
    # Configure firewall
    New-NetFirewallRule -DisplayName "WinRM HTTPS" `
        -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow
}

# Connect via HTTPS
$sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
$session = New-PSSession -ComputerName $targetDC `
    -Credential $domainCred `
    -UseSSL `
    -SessionOption $sessionOption
```

---

## DEPLOYMENT CHECKLIST

### Pre-Deployment

- [ ] cdx-mgmt-01 network configured (4.244.16.87/16)
- [ ] Static routes configured for all sites
- [ ] Firewall rules deployed to all SDPs
- [ ] Target DC provisioned and OOBE complete
- [ ] Built-in Administrator account enabled on target DC
- [ ] WinRM enabled on target DC
- [ ] Network connectivity tested (ping + TCP 5985)
- [ ] CDX-E repository cloned (verify path: E:\Git\CDX-E\ or C:\CDX-E\)
- [ ] Credentials documented
- [ ] **Decide: Manual vs. Auto-reboot deployment** (v2.2)

### Forest Creation

**Traditional Manual Method:**
- [ ] Remote session established
- [ ] Repository transferred (UTF-8 safe method)
- [ ] Scripts validated (syntax check passed)
- [ ] First deployment run completed (forest created)
- [ ] DC rebooted manually
- [ ] Reconnected with domain credentials

**Auto-Reboot Method (v2.2):**
- [ ] Remote session established
- [ ] Repository transferred (UTF-8 safe method)
- [ ] Scripts validated (syntax check passed)
- [ ] First deployment run completed with `-AutoReboot` flag
- [ ] Scheduled task created successfully
- [ ] Countdown completed (or cancelled if needed)
- [ ] DC rebooted automatically
- [ ] Post-reboot deployment completed automatically
- [ ] Scheduled task self-deleted

### Exercise Deployment

- [ ] Second deployment run completed (or auto-completed)
- [ ] AD Sites created (5 sites)
- [ ] OUs created (65+ organizational units)
- [ ] Users created (543 accounts)
- [ ] Computers pre-staged (343 objects)
- [ ] Groups created (58+ security groups)
- [ ] GPOs deployed and linked
- [ ] DNS zones configured

### Post-Deployment

- [ ] Validation checks passed
- [ ] Additional DCs promoted
- [ ] AD replication verified
- [ ] FSMO roles identified
- [ ] **Scheduled task verified removed** (auto-reboot only - v2.2)
- [ ] Documentation updated
- [ ] Snapshots/backups created

---

## QUICK REFERENCE

### Essential Commands

```powershell
# Create session
$session = New-PSSession -ComputerName $ip -Credential $cred

# Test session
$session.State

# Execute command
Invoke-Command -Session $session -ScriptBlock { ... }

# Transfer file (UTF-8 safe for .ps1)
$content = Get-Content "script.ps1" -Raw -Encoding UTF8
Invoke-Command -Session $session -ScriptBlock {
    param($c)
    Set-Content -Path "C:\remote\script.ps1" -Value $c -Encoding UTF8
} -ArgumentList $content

# Transfer file (standard for JSON)
Copy-Item -Path "file.json" -Destination "C:\remote\" -ToSession $session

# Close session
Remove-PSSession $session
```

---

### Target DC IP Addresses

| Site | DC Name | IP Address | Subnet Mask | Gateway |
|------|---------|------------|-------------|---------|
| HQ | STK-DC-01 | 66.218.180.10 | /22 | 66.218.180.1 |
| HQ | STK-DC-02 | 66.218.180.11 | /22 | 66.218.180.1 |
| Dallas | STK-DC-02 | 50.222.72.10 | /22 | 50.222.72.1 |
| Malibu | STK-DC-03 | 4.150.216.10 | /22 | 4.150.216.1 |
| Nagasaki | STK-DC-04 | 14.206.0.10 | /22 | 14.206.0.1 |
| Amsterdam | STK-DC-05 | 37.74.124.10 | /23 | 37.74.124.1 |

---

### Deployment Commands

```powershell
# TRADITIONAL METHOD - First run (creates forest, manual reboot required)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -Verbose

# TRADITIONAL METHOD - Second run (deploys exercise after manual reboot)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose

# AUTO-REBOOT METHOD - Single automated run (v2.2 - NEW!)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot

# AUTO-REBOOT METHOD - Custom countdown (v2.2)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure -AutoReboot -RebootDelaySeconds 60

# Test mode (no changes made)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf

# Test mode with auto-reboot simulation (v2.2)
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf -AutoReboot

# Regenerate structure only
.\generate_structure.ps1 -ExerciseName "CHILLED_ROCKET" -Force
```

---

### Auto-Reboot Commands (v2.2)

```powershell
# Check if auto-deployment scheduled task exists
Get-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -ErrorAction SilentlyContinue

# Monitor task status
Get-ScheduledTaskInfo -TaskName "CDX-PostReboot-Deployment"

# Manually remove task (if needed)
Unregister-ScheduledTask -TaskName "CDX-PostReboot-Deployment" -Confirm:$false

# Verify deployment completed successfully
Import-Module ActiveDirectory
Get-ADComputer -Filter * | Measure-Object | Select-Object Count
Get-ADUser -Filter * | Measure-Object | Select-Object Count
Get-ADReplicationSite -Filter * | Measure-Object | Select-Object Count
```

---

**Document Version:** 2.2 (Auto-Reboot + Unicode-Safe)  
**Last Updated:** 2025-11-29  
**Framework:** CDX-E v2.2  
**Management Network:** 4.244.16.0/24 via CDX-Internet

---

*"Deployment isn't about perfection on the first try—it's about having the tools to recover from the second, third, and nth try… and now, not having to manually intervene at all."*  
— J.A.R.V.I.S., Automated Deployment Operations Division
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -Verbose

# Test mode
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -WhatIf

# Regenerate structure only
.\generate_structure.ps1 -ExerciseName "CHILLED_ROCKET" -Force
```

---

**Document Version:** 2.0 (Unicode-Safe)  
**Last Updated:** 2025-11-29  
**Framework:** CDX-E v2.1  
**Management Network:** 4.244.16.0/24 via CDX-Internet

---

*"Deployment isn't about perfection on the first try—it's about having the tools to recover from the second, third, and nth try."*  
— J.A.R.V.I.S., Deployment Operations Division

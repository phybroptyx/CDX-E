# CHILLED_ROCKET Deployment Guide

**Stark Industries Global Enterprise Environment**  
**CDX-E Framework v2.1**  
**Last Updated:** 2025-12-07

---

## Overview

This guide provides complete instructions for deploying the CHILLED_ROCKET exercise environment - a full-scale Stark Industries global enterprise simulation consisting of 343 virtual machines across 5 geographic sites.

### Environment Summary

| Component | Count | Description |
|-----------|-------|-------------|
| **Domain Controllers** | 6 | Windows Server 2012 R2 - 2019 |
| **Member Servers** | 30 | File, Database, Web, Application servers |
| **Workstations** | 295 | Windows 10/11 Enterprise and Professional |
| **AD Sites** | 5 | HQ, Dallas, Malibu, Nagasaki, Amsterdam |
| **User Accounts** | 543 | Across all departments |
| **Security Groups** | 58+ | Department and role-based |
| **Group Policies** | 5+ | Baseline and branding policies |

### Domain Configuration

| Property | Value |
|----------|-------|
| **Domain FQDN** | stark-industries.midgard.mrvl |
| **NetBIOS Name** | STARK |
| **Forest Functional Level** | Windows Server 2012 R2 |
| **Domain Functional Level** | Windows Server 2012 R2 |

---

## Prerequisites

### Infrastructure Requirements

#### Proxmox Cluster

| Node | Hostname | Role | Storage |
|------|----------|------|---------|
| Node 1 | cdx-pve-01 | Primary | RAID + NAS |
| Node 2 | cdx-pve-02 | Secondary | RAID + NAS |
| Node 3 | cdx-pve-03 | Secondary | RAID + NAS |

**Minimum Resources:**
- 384 GB RAM total across cluster
- 4 TB storage for VM disks
- 10 Gbps inter-node networking

#### Management Workstation (cdx-mgmt-01)

- Windows 10/11 with PowerShell 5.1+
- Network access to Proxmox cluster (port 8006)
- Network access to all VM subnets
- CDX-E repository cloned locally

#### VM Templates

Ensure the following templates exist on your Proxmox cluster:

| Template ID | Operating System | Purpose |
|-------------|------------------|---------|
| 2003 | Windows Server 2012 R2 | Legacy DCs |
| 2004 | Windows Server 2016 | Standard servers |
| 2006 | Windows Server 2019 | Modern servers |
| 2008 | Windows Server 2022 | Development servers |
| 2009 | Windows 11 Professional | Workstations |
| 2010 | Windows 10 Enterprise | Workstations |

### Network Configuration

#### Site Subnets

| Site | Location | Primary Subnet | Bridge Range |
|------|----------|----------------|--------------|
| HQ | New York, USA | 66.218.180.0/22 | stk100-stk110 |
| Malibu | California, USA | 4.150.216.0/22 | stk111-stk115 |
| Dallas | Texas, USA | 50.222.72.0/22 | stk116-stk124 |
| Nagasaki | Japan | 14.206.0.0/22 | stk125-stk132 |
| Amsterdam | Netherlands | 37.74.124.0/23 | stk133-stk140 |

#### Required Network Bridges

Create the following bridges on each Proxmox node before deployment:

```bash
# Example: HQ Core Servers bridge
auto stk100
iface stk100 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

See `NETWORK_BRIDGE_REFERENCE.md` for complete bridge configurations.

### Software Prerequisites

On the management workstation:

```powershell
# Verify PowerShell version
$PSVersionTable.PSVersion

# Required: 5.1 or higher
```

On template VMs:
- QEMU Guest Agent installed and running
- WinRM enabled for remote management
- Local administrator account (cdxadmin) configured

---

## Repository Structure

```
CDX-E/
├── ad_deploy.ps1                    # AD deployment engine
├── deploy.ps1                       # Master orchestration script
├── generate_structure.ps1           # Topology generator
├── Clone-ProxmoxVMs.ps1            # VM provisioning script
├── Enhanced-Repository-Transfer.ps1 # File transfer utility
│
├── EXERCISES/
│   └── CHILLED_ROCKET/
│       ├── exercise_template.json   # Topology definition
│       ├── structure.json           # Generated AD structure
│       ├── users.json               # User accounts
│       ├── computers.json           # Computer objects (343 VMs)
│       ├── services.json            # DNS configuration
│       ├── gpo.json                 # Group Policy definitions
│       ├── Domain Files/            # Branding images
│       │   ├── domain-splash-stark-industries.jpg
│       │   ├── domain-u-wall-stark-industries.jpg
│       │   └── tony-stark-vip.jpg
│       └── split_configs/           # Per-site VM configurations
│
├── UTILITIES/                       # Helper scripts
└── DOCUMENTATION/                   # Reference documentation
```

---

## Deployment Phases

The deployment is organized into 8 phases, each building on the previous:

| Phase | Name | Duration | Description |
|-------|------|----------|-------------|
| 1 | Forest Root DC | 45 min | Deploy STK-DC-01, create AD forest |
| 2 | User Accounts | 15 min | Create OUs, groups, users |
| 3 | Group Policy | 15 min | Deploy GPOs with branding |
| 4 | Site DCs | 90 min | Deploy and promote site DCs |
| 5 | Member Servers | 45 min | Deploy file, DB, web servers |
| 6 | DHCP | 20 min | Configure DHCP scopes |
| 7 | Workstations | 3-4 hrs | Deploy 295 workstations |
| 8 | Validation | 10 min | Verify deployment |

**Total Estimated Time:** 8 hours

---

## Pre-Deployment Checklist

Before starting deployment, verify:

- [ ] Proxmox cluster operational (all 3 nodes online)
- [ ] VM templates available (2003, 2004, 2006, 2008, 2009, 2010)
- [ ] Network bridges configured on all nodes
- [ ] CDX-E repository cloned to `E:\Git\CDX-E\` on cdx-mgmt-01
- [ ] Management workstation can reach Proxmox API (port 8006)
- [ ] Management workstation can reach target VM subnets
- [ ] Branding images placed in `Domain Files/` folder
- [ ] Passwords prepared for DSRM, Domain Admin, and local admin

### Verify Proxmox Connectivity

```powershell
# Test API access
$proxmoxHost = "cdx-pve-01"
$testUrl = "https://${proxmoxHost}:8006/api2/json/version"

try {
    $response = Invoke-RestMethod -Uri $testUrl -SkipCertificateCheck
    Write-Host "[OK] Proxmox API accessible - Version: $($response.data.version)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Cannot reach Proxmox API: $_" -ForegroundColor Red
}
```

### Verify Template Availability

```powershell
# List available templates (requires authentication)
# Or check via Proxmox web UI: Datacenter > Storage > NAS > CT/VM Templates
```

---

## Deployment Procedure

### Step 1: Open PowerShell as Administrator

On cdx-mgmt-01:

```powershell
# Navigate to repository
cd E:\Git\CDX-E

# Verify deploy.ps1 exists
Test-Path ".\deploy.ps1"
```

### Step 2: Launch Deployment

```powershell
.\deploy.ps1 -ProxmoxPassword "YourProxmoxRootPassword"
```

### Step 3: Provide Credentials

The script will prompt for three passwords:

```
============================================================
   CREDENTIAL COLLECTION
============================================================

Please provide the following passwords for deployment:
  - These will be used for DSRM, Domain Administrator, and
    local cdxadmin accounts across all deployed systems.

Enter DSRM (Directory Services Restore Mode) password: ********
Enter Domain Administrator password: ********
Enter Local Administrator (cdxadmin) password: ********
```

**Password Requirements:**
- Minimum 8 characters
- Mix of uppercase, lowercase, numbers, and symbols
- Must meet Windows complexity requirements

### Step 4: Confirm Deployment

```
============================================================
   DEPLOYMENT CONFIRMATION
============================================================

Domain:    stark-industries.midgard.mrvl
NetBIOS:   STARK
Exercise:  CHILLED_ROCKET

WARNING: This will deploy 343 VMs across 5 sites.
         Estimated deployment time: 8 hours

Type 'DEPLOY' to continue: DEPLOY
```

### Step 5: Monitor Progress

The script provides real-time status updates:

```
============================================================
   PHASE 1: Forest Root Domain Controller Deployment
   Estimated Duration: 45 minutes
============================================================

Step 1.1: Deploying STK-DC-01 VM with boosted resources...
STK-DC-01 deployed with 16 GB RAM (boosted for forest creation)
Step 1.2: Waiting for STK-DC-01 network availability via QEMU guest agent...
    [OK] VM 5001 is ready at 66.218.180.40
Step 1.3: Setting Execution Policy to Unrestricted on STK-DC-01...
    [OK] Execution policy set to Unrestricted on 66.218.180.40
Step 1.4: Transferring CDX-E repository to STK-DC-01...
Repository transferred and verified successfully
Step 1.5: Creating Active Directory forest (stark-industries.midgard.mrvl)...
    ... waiting for AD services (attempt 1 / 30)
    ... waiting for AD services (attempt 2 / 30)
Active Directory forest created: stark-industries.midgard.mrvl (STARK)
Phase 1 complete: Forest Root DC operational
```

---

## Phase Details

### Phase 1: Forest Root Domain Controller

**What happens:**
1. STK-DC-01 VM deployed with 16 GB RAM (boosted for forest creation)
2. QEMU guest agent confirms VM is ready
3. Windows Firewall configured to allow ICMP
4. PowerShell execution policy set to Unrestricted
5. CDX-E repository transferred to `C:\CDX-E`
6. AD DS role installed
7. New forest created: `stark-industries.midgard.mrvl`
8. System reboots to complete promotion

**Key Systems:**

| VM ID | Name | IP Address | Role |
|-------|------|------------|------|
| 5001 | STK-DC-01 | 66.218.180.40 | Forest Root DC |

### Phase 2: User Account Deployment

**What happens:**
1. Connects to STK-DC-01 via PSRemoting
2. Executes `ad_deploy.ps1` to create:
   - AD Sites and subnets
   - Organizational Unit hierarchy
   - Security groups
   - DNS zones and forwarders
   - User accounts with full attributes

**Objects Created:**

| Object Type | Count |
|-------------|-------|
| AD Sites | 5 |
| Subnets | 41 |
| Site Links | 4 |
| OUs | 65+ |
| Security Groups | 58+ |
| User Accounts | 543 |

### Phase 3: Group Policy Deployment with Branding

**What happens:**
1. Branding images staged to SYSVOL:
   - `domain-splash-stark-industries.jpg` → Logon/lock screen
   - `domain-u-wall-stark-industries.jpg` → Default wallpaper
   - `tony-stark-vip.jpg` → Tony Stark's workstation
2. GPOs created with registry policies
3. Security filtering configured for VIP workstation
4. GPOs linked to appropriate OUs
5. STK-DC-01 memory reverted to 8 GB

**GPOs Created:**

| GPO Name | Target | Purpose |
|----------|--------|---------|
| Baseline Workstation Policy | Workstation OUs | Security hardening |
| Baseline Server Policy | Server OUs | Security hardening |
| SI Domain Branding - Logon Screen | OU=Sites (Enforced) | Corporate logon screen |
| SI Domain Branding - Workstation Wallpaper | OU=Sites | Default wallpaper |
| SI VIP - Tony Stark Wallpaper | ML-DEV-W32805N only | VIP wallpaper |

### Phase 4: Site Domain Controllers

**What happens:**
1. Site DC VMs deployed across cluster nodes
2. QEMU guest agent confirms availability
3. Systems joined to domain
4. AD DS role installed
5. Promoted to domain controllers
6. Assigned to appropriate AD sites
7. Replication verified

**Site DCs:**

| VM ID | Name | Site | IP Address | Node |
|-------|------|------|------------|------|
| 5002 | STK-DC-02 | HQ | 66.218.180.41 | cdx-pve-01 |
| 5003 | STK-DC-03 | Dallas | 50.222.74.10 | cdx-pve-01 |
| 5004 | STK-DC-04 | Malibu | 4.150.217.10 | cdx-pve-01 |
| 5005 | STK-DC-05 | Nagasaki | 14.206.2.10 | cdx-pve-03 |
| 5006 | STK-DC-06 | Amsterdam | 37.74.126.10 | cdx-pve-02 |

### Phase 5: Member Servers

**What happens:**
1. Core infrastructure servers deployed
2. QEMU guest agent confirms availability
3. ICMP enabled on each server
4. Systems joined to domain

**Server Types:**

| Type | Count | Purpose |
|------|-------|---------|
| File Servers | 8 | Department file shares |
| Database Servers | 6 | SQL Server instances |
| Web Servers | 4 | IIS web applications |
| Application Servers | 5 | Business applications |
| Network Management | 5 | Monitoring and management |
| WSUS Servers | 3 | Regional update services |

### Phase 6: DHCP Deployment

**What happens:**
1. DHCP scopes configured per site
2. Scope options set (DNS, gateway, domain)
3. Reservations created for critical systems
4. DHCP authorized in Active Directory

**DHCP Scopes:**

| Site | Scope | Range |
|------|-------|-------|
| HQ | 66.218.181.0/24 | .100 - .250 |
| Dallas | 50.222.73.0/24 | .100 - .250 |
| Malibu | 4.150.218.0/24 | .100 - .250 |
| Nagasaki | 14.206.1.0/24 | .100 - .250 |
| Amsterdam | 37.74.125.0/24 | .100 - .250 |

### Phase 7: Workstation Deployment

**What happens:**
1. Workstations deployed by site (staggered to manage load)
2. QEMU guest agent confirms availability
3. ICMP enabled on each workstation
4. Systems joined to domain
5. GPOs applied (including branding)

**Workstation Distribution:**

| Site | Count | VM ID Range |
|------|-------|-------------|
| HQ (New York) | 92 | 6001-6092 |
| Dallas | 55 | 6100-6154 |
| Malibu | 21 | 6200-6220 |
| Nagasaki | 68 | 6300-6367 |
| Amsterdam | 59 | 6400-6458 |

**VIP Workstations:**

| User | Hostname | VM ID | Location |
|------|----------|-------|----------|
| Tony Stark (CEO) | ML-DEV-W32805N | 6200 | Malibu |
| Pepper Potts (COO) | HQ-OPS-XAJI0Y6DPB | 6001 | HQ |
| Happy Hogan (COS) | HQ-SUP-J2D54I3QK2 | 6022 | HQ |

### Phase 8: Validation

**What happens:**
1. AD domain health check
2. Domain controller enumeration
3. Replication status verification
4. Computer and user count validation
5. GPO status verification
6. Branding image accessibility check

---

## Advanced Options

### Skip Phases

To skip specific phases (e.g., if resuming after failure):

```powershell
# Skip phases 1, 2, 3 (start from Phase 4)
.\deploy.ps1 -ProxmoxPassword "Password" -SkipPhases @(1,2,3)
```

### Pause Between Phases

To pause for confirmation after each phase:

```powershell
.\deploy.ps1 -ProxmoxPassword "Password" -PauseAfterPhase
```

### What-If Mode

To preview deployment without making changes:

```powershell
.\deploy.ps1 -ProxmoxPassword "Password" -WhatIf
```

### Custom Timeouts

To adjust QEMU guest agent timeout:

```powershell
.\deploy.ps1 -ProxmoxPassword "Password" -AgentTimeoutSeconds 600 -AgentPollIntervalSeconds 15
```

---

## Post-Deployment Tasks

### 1. Create VM Snapshots

```powershell
# Via Proxmox CLI on each node
qm snapshot 5001 baseline --description "Post-deployment baseline"
```

Or use Proxmox web UI: Select VM → Snapshots → Take Snapshot

### 2. Verify AD Replication

```powershell
# On any DC
repadmin /replsummary
repadmin /showrepl
```

### 3. Test Branding

1. Log into any workstation
2. Verify lock screen shows Stark Industries branding
3. Verify desktop wallpaper is applied
4. Log into ML-DEV-W32805N (Tony Stark's workstation)
5. Verify VIP wallpaper is displayed

### 4. Document Credentials

Store the following securely:
- DSRM password (for each DC)
- Domain Administrator password
- Local administrator (cdxadmin) password

### 5. Configure Backups

Set up backup jobs for:
- Domain Controllers (critical)
- File Servers (important)
- Database Servers (important)

---

## Troubleshooting

### Deployment Fails at Phase 1

**Symptom:** STK-DC-01 does not become available

**Solutions:**
1. Check Proxmox console for VM boot issues
2. Verify template 2006 exists and is valid
3. Check network bridge stk100 exists
4. Verify QEMU guest agent is installed in template

### Forest Creation Fails

**Symptom:** "Forest deployment timeout" error

**Solutions:**
1. Check DSRM password meets complexity requirements
2. Verify network connectivity from STK-DC-01
3. Check for sufficient disk space
4. Review Windows event logs on STK-DC-01

### Repository Transfer Fails

**Symptom:** "Repository transfer failed" error

**Solutions:**
1. Verify cdxadmin account exists on template
2. Check WinRM is enabled on target VM
3. Verify firewall allows WinRM (port 5985)
4. Check for sufficient disk space on target

### Site DCs Fail to Promote

**Symptom:** DC promotion errors in Phase 4

**Solutions:**
1. Verify DNS resolution to STK-DC-01
2. Check domain admin credentials
3. Verify AD replication is healthy
4. Review dcpromo logs on target server

### Workstations Fail to Join Domain

**Symptom:** Domain join errors in Phase 7

**Solutions:**
1. Verify DHCP is configured correctly
2. Check DNS resolution to domain controllers
3. Verify domain admin credentials
4. Check for computer account conflicts

### Branding Not Applied

**Symptom:** Default Windows wallpaper/lock screen displayed

**Solutions:**
1. Verify images exist in NETLOGON\Images
2. Check GPO is linked and enabled
3. Run `gpupdate /force` on workstation
4. Check `gpresult /r` for GPO application
5. Verify UNC path accessibility

---

## Recovery Procedures

### Restart Failed Phase

If a phase fails, you can restart from that phase:

```powershell
# Example: Restart from Phase 4
.\deploy.ps1 -ProxmoxPassword "Password" -SkipPhases @(1,2,3)
```

### Rollback to Snapshot

If deployment is corrupted:

1. Stop all VMs in the exercise
2. Restore from baseline snapshots
3. Restart deployment from appropriate phase

### Complete Reset

To completely reset and start over:

1. Delete all CHILLED_ROCKET VMs (5001-6458)
2. Remove computer accounts from AD (or delete entire domain)
3. Restart from Phase 1

---

## Deployment Log

The script automatically saves a deployment log:

```
EXERCISES/CHILLED_ROCKET/deployment_log_YYYYMMDD_HHMMSS.txt
```

Review this log for:
- Timestamps of each operation
- Success/failure status
- Error messages
- Warning notifications

---

## Reference

### Key IP Addresses

| System | IP Address | Purpose |
|--------|------------|---------|
| STK-DC-01 | 66.218.180.40 | Primary DC |
| STK-DC-02 | 66.218.180.41 | Secondary DC (HQ) |
| STK-DC-03 | 50.222.74.10 | Dallas DC |
| STK-DC-04 | 4.150.217.10 | Malibu DC |
| STK-DC-05 | 14.206.2.10 | Nagasaki DC |
| STK-DC-06 | 37.74.126.10 | Amsterdam DC |

### Key Accounts

| Account | Purpose |
|---------|---------|
| STARK\Administrator | Domain Administrator |
| cdxadmin | Local administrator on all systems |
| tstark | Tony Stark user account |
| ppotts | Pepper Potts user account |

### Related Documentation

| Document | Description |
|----------|-------------|
| `README.md` | CDX-E framework overview |
| `NETWORK_BRIDGE_REFERENCE.md` | Network configuration |
| `DEPLOYMENT_SUMMARY.md` | Exercise summary |
| `MASTER_WORKSTATION_INVENTORY.md` | Workstation details |
| `GPO_BRANDING_DEPLOYMENT_GUIDE.md` | Branding-specific guide |
| `PSREMOTING_DEPLOYMENT_GUIDE_v2.md` | Remote deployment details |

---

## Support

### Common Commands

```powershell
# Check AD health
Get-ADDomainController -Filter * | Select Name, Site, IPv4Address

# Check replication
repadmin /replsummary

# Force GP update
Invoke-Command -ComputerName "workstation" -ScriptBlock { gpupdate /force }

# Check GPO application
Invoke-Command -ComputerName "workstation" -ScriptBlock { gpresult /r }

# List all computers
Get-ADComputer -Filter * | Measure-Object

# List all users
Get-ADUser -Filter * | Measure-Object
```

### Log Locations

| Log | Location |
|-----|----------|
| Deployment Log | `EXERCISES/CHILLED_ROCKET/deployment_log_*.txt` |
| DC Promotion | `C:\Windows\debug\dcpromo.log` |
| AD Events | Event Viewer → Directory Service |
| GPO Events | Event Viewer → Group Policy |

---

**Document Version:** 2.1  
**Author:** J.A.R.V.I.S.  
**Framework:** CDX-E  
**Exercise:** CHILLED_ROCKET  
**Status:** Production Ready

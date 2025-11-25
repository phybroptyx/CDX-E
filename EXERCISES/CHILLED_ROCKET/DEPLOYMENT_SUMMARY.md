# CHILLED_ROCKET - Proxmox VM ID Assignment Summary

**Exercise:** CHILLED_ROCKET (Stark Industries)  
**Generated:** 2025-11-24  
**Version:** 2.1  

## Overview

Complete infrastructure definition for 343 virtual machines with Proxmox VM IDs assigned according to your environment's resource grouping scheme.

## VM ID Allocation

### Servers: 5000-5999 Range (Defended/Target Resources)
- **Total Servers:** 48
- **VM ID Range:** 5001-5070
- **Distribution:**
  - Domain Controllers: 5001-5005 (5 systems)
  - HQ Servers: 5010-5019 (12 systems)
  - Dallas Servers: 5030-5035 (7 systems)
  - Malibu Servers: 5040-5048 (9 systems)
  - Nagasaki Servers: 5050-5056 (8 systems)
  - Amsterdam Servers: 5060-5070 (12 systems)

### Workstations: 6000-6999 Range (Defended/Target Resources)
- **Total Workstations:** 295
- **VM ID Range:** 6001-6458
- **Distribution:**
  - HQ: 6001-6092 (92 systems)
  - Dallas: 6100-6154 (55 systems)
  - Malibu: 6200-6220 (21 systems)
  - Nagasaki: 6300-6367 (68 systems)
  - Amsterdam: 6400-6458 (59 systems)

## Template Mapping

All systems will be cloned from the following Proxmox templates:

### Server Templates
- **2001:** Windows Server 2025 (5 systems)
- **2002:** Windows Server 2022 (15 systems)
- **2003:** Windows Server 2019 (25 systems)

### Workstation Templates
- **2009:** Windows 11 Professional (97 systems) - **All Win11 changed to Professional**
- **2010:** Windows 10 Enterprise (169 systems)
- **2011:** Windows 8.1 Enterprise (16 systems - 5.4%)
- **2012:** Windows 7 Enterprise (13 systems - 4.4%)

## Operating System Distribution

### Servers
- Windows Server 2025: 5 systems (10.4%)
- Windows Server 2022: 15 systems (31.3%)
- Windows Server 2019: 28 systems (58.3%)

### Workstations
- **Modern OS (90.2%):**
  - Windows 11 Professional: 97 systems (32.9%)
  - Windows 10 Enterprise: 169 systems (57.3%)
- **Legacy OS (9.8%):**
  - Windows 8.1 Enterprise: 16 systems (5.4%)
  - Windows 7 Enterprise: 13 systems (4.4%)

## VIP Systems

Three critical VIP workstations are marked in the configuration:

### 1. Tony Stark (CEO)
- **VM ID:** 6200
- **Hostname:** ML-DEV-W32805N
- **Location:** Malibu - Development
- **Model:** Dell Precision 7920 Tower
- **OS:** Windows 10 Enterprise (Template 2010)
- **MAC:** D4:AE:52:C4:2D:34

### 2. Pepper Potts (COO)
- **VM ID:** 6001
- **Hostname:** HQ-OPS-XAJI0Y6DPB
- **Location:** HQ - Operations
- **Model:** HP EliteDesk 800 G9
- **OS:** Windows 10 Enterprise (Template 2010)
- **MAC:** 00:1F:29:65:D6:70

### 3. Happy Hogan (COS - Chief of Security)
- **VM ID:** 6022
- **Hostname:** HQ-SUP-J2D54I3QK2
- **Location:** HQ - Ops-Support
- **Model:** HP EliteDesk 800 G8
- **OS:** Windows 11 Professional (Template 2009)
- **MAC:** 00:21:5A:CC:A8:8E

## Critical Infrastructure

### Domain Controllers (All marked as critical)
- **VM 5001:** STK-DC-01 (Primary DC - HQ)
- **VM 5002:** STK-DC-02 (Secondary DC - HQ)
- **VM 5003:** STK-DC-03 (DC - Dallas)
- **VM 5004:** STK-DC-04 (DC - Nagasaki)
- **VM 5005:** STK-DC-05 (DC - Amsterdam)

### Regional WSUS Servers
- **VM 5013:** HQ-WSU-01 (Americas region)
- **VM 5053:** NAG-WSU-01 (Asia-Pacific region)
- **VM 5063:** AMS-WSU-01 (Europe region)

## Site Breakdown

### HQ (New York) - 104 total systems
- **Servers:** 12 (VM 5001-5019)
  - 2 Domain Controllers
  - 2 File Servers
  - 1 Network Management Server
  - 1 WSUS Server
  - 2 Database Servers
  - 2 Web Servers
  - 2 Application Servers
- **Workstations:** 92 (VM 6001-6092)
  - 10 departments with full infrastructure

### Dallas (Texas) - 62 total systems
- **Servers:** 7 (VM 5003, 5030-5035)
  - 1 Domain Controller
  - 2 File Servers
  - 1 Network Management Server
  - 3 Database Servers
- **Workstations:** 55 (VM 6100-6154)
  - 7 departments (Operations, IT-Core, Ops-Support, Engineering, Engineering Development, QA, CAD)

### Malibu (California) - 30 total systems
- **Servers:** 9 (VM 5040-5048)
  - 2 File Servers
  - 1 Network Management Server (Server 2025)
  - 2 Database Servers
  - 2 Development Database Servers (Server 2025)
  - 2 Development Application Servers (Server 2025)
- **Workstations:** 21 (VM 6200-6220)
  - Primarily Development and Operations
  - Includes Tony Stark's VIP workstation

### Nagasaki (Japan) - 76 total systems
- **Servers:** 8 (VM 5004, 5050-5056)
  - 1 Domain Controller
  - 2 File Servers
  - 1 Network Management Server
  - 1 WSUS Server (Asia-Pacific)
  - 3 Database Servers
- **Workstations:** 68 (VM 6300-6367)
  - 6 departments with focus on Engineering and QA

### Amsterdam (Netherlands) - 71 total systems
- **Servers:** 12 (VM 5005, 5060-5070)
  - 1 Domain Controller
  - 2 File Servers
  - 1 Network Management Server
  - 1 WSUS Server (Europe)
  - 2 Database Servers
  - 2 Web Servers
  - 3 Application Servers
- **Workstations:** 59 (VM 6400-6458)
  - 6 departments with balanced distribution

## Hardware Models

### Servers (Dell PowerEdge)
- **R640:** Domain Controllers (5 systems)
- **R740xd:** File Servers (10 systems)
- **R650:** General purpose servers (13 systems)
- **R660:** Malibu advanced infrastructure (3 systems)
- **R750:** Database Servers (12 systems)
- **R760:** Malibu development databases (2 systems)

### Workstations

#### HP EliteDesk (Business/Admin - 153 systems)
- **800 G9:** Premium business workstation
- **805 G8:** AMD-based business workstation
- **600 G9:** Standard business workstation
- **800 G8:** Previous generation premium

#### Dell Precision (Engineering/Development - 142 systems)
- **7920 Tower:** High-end dual processor workstation
- **7865 Tower:** AMD Threadripper flagship
- **5820 Tower:** Mid-range professional workstation
- **3660 Tower:** Entry professional workstation
- **3650 Tower:** Standard professional workstation

## MAC Address Allocation

### HP EliteDesk Vendor Prefixes
- 00:1F:29:xx:xx:xx
- 00:21:5A:xx:xx:xx
- F4:CE:46:xx:xx:xx
- D4:85:64:xx:xx:xx
- 70:5A:0F:xx:xx:xx

### Dell Precision Vendor Prefixes
- D4:AE:52:xx:xx:xx
- B8:2A:72:xx:xx:xx
- F0:1F:AF:xx:xx:xx
- 00:14:22:xx:xx:xx

### Dell PowerEdge Server Prefix
- 14:18:77:xx:xx:xx

## Deployment Notes

### Pre-Deployment Checklist
1. ✓ All 10 Proxmox templates exist (2001-2012)
2. ✓ Sufficient storage for 343 VMs
3. ✓ Network configuration complete
4. ✓ VLAN assignments documented
5. ✓ Backup strategy in place

### Clone Strategy
1. **Phase 1:** Domain Controllers (5 VMs)
   - Critical infrastructure first
   - Verify AD replication before proceeding

2. **Phase 2:** Infrastructure Servers (43 VMs)
   - File, DB, Web, App, NMS, WSUS servers
   - Test services before workstation deployment

3. **Phase 3:** VIP Workstations (3 VMs)
   - Tony Stark, Pepper Potts, Happy Hogan
   - Test and verify before mass deployment

4. **Phase 4:** Standard Workstations (292 VMs)
   - Deploy by site to manage network load
   - Suggested order: HQ → Dallas → Nagasaki → Amsterdam → Malibu

### Post-Clone Actions
1. Set unique hostnames from JSON
2. Configure MAC addresses
3. Join to AD domain (stark.local)
4. Apply GPOs per OU structure
5. Verify WSUS assignment by region
6. Install site-specific software
7. Configure DHCP reservations for VIP systems

## File Structure

```json
{
  "_meta": { ... },
  "computers": [
    {
      "vmid": 5001,
      "name": "STK-DC-01",
      "ou": "OU=Servers,OU=Operations,OU=HQ,OU=Sites",
      "description": "Primary Domain Controller - HQ",
      "type": "Domain Controller",
      "os": "Windows Server 2019",
      "template": 2003,
      "manufacturer": "Dell",
      "model": "PowerEdge R640",
      "mac": "14:18:77:3A:2B:C1",
      "site": "HQ",
      "critical": true
    },
    ...
  ],
  "workstations": [
    {
      "vmid": 6001,
      "hostname": "HQ-OPS-XAJI0Y6DPB",
      "site": "HQ",
      "department": "Operations",
      "ou": "OU=Workstations,OU=Operations,OU=HQ,OU=Sites",
      "model": "HP EliteDesk 800 G9",
      "os": "Windows 10 Enterprise",
      "template": 2010,
      "mac": "00:1F:29:65:D6:70",
      "vip_user": "Pepper Potts (COO)",
      "notes": "VIP system - COO workstation"
    },
    ...
  ]
}
```

## Integration with ad_deploy.ps1

This `computers.json` file is ready to be used with the CDX-E deployment framework:

```powershell
# Deploy with auto-generation
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure

# The computers.json will be read to:
# 1. Pre-stage all computer accounts in AD
# 2. Create proper OU structure
# 3. Set computer descriptions
# 4. Configure proper group memberships
```

## Key Changes from Original

1. **✓ All Windows 11 systems changed to Professional edition**
2. **✓ VM IDs assigned per Proxmox grouping (5000-6999 for Defended/Target)**
3. **✓ Servers use 5000-5999 range**
4. **✓ Workstations use 6000-6999 range with 100-unit spacing per site**
5. **✓ Template field added for Proxmox cloning**
6. **✓ All 48 servers included (fixed missing 3)**
7. **✓ All 295 workstations generated with realistic distribution**
8. **✓ VIP systems properly marked**
9. **✓ Proper MAC addresses with correct vendor OUIs**

## Support Information

- **Exercise Repository:** https://github.com/phybroptyx/CDX-E
- **Framework:** CDX-E Active Directory Deployment Engine
- **Scenario:** CHILLED_ROCKET (Stark Industries)
- **Total Systems:** 343 VMs
- **Deployment Time Estimate:** 8-12 hours for full deployment

---

**File Generated:** 2025-11-24  
**File Size:** ~116 KB  
**Format:** JSON  
**Ready for:** Proxmox VM provisioning and AD deployment

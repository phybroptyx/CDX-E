# CHILLED_ROCKET Configuration Files - Index

## 📥 Download These Files

All files are ready for download and deployment to your Proxmox environment.

---

## 🎯 Primary Configuration File

### **[computers.json](computer:///mnt/user-data/outputs/computers.json)** (170 KB)

**THE MAIN FILE** - Complete infrastructure configuration for all 343 virtual machines.

**Contents:**
- ✅ 48 servers (VM IDs 5001-5070)
- ✅ 295 workstations (VM IDs 6001-6458)
- ✅ All Windows 11 systems set to Professional edition
- ✅ Proxmox template IDs for cloning
- ✅ MAC addresses for all systems
- ✅ **Network bridge assignments (stk100-stk140)**
- ✅ **Network segmentation configuration**
- ✅ VIP system markers

**Use this file for:**
- Automated VM provisioning
- Network configuration
- CDX-E deployment framework integration
- Documentation reference

---

## 📚 Documentation Files

### 1. **[DEPLOYMENT_SUMMARY.md](computer:///mnt/user-data/outputs/DEPLOYMENT_SUMMARY.md)** (9.3 KB)

Complete deployment guide with:
- VM ID allocation strategy
- Template mapping
- VIP system details
- Site-by-site breakdown
- Hardware specifications
- Pre/post deployment checklists
- Integration with ad_deploy.ps1

### 2. **[VM_ID_REFERENCE.md](computer:///mnt/user-data/outputs/VM_ID_REFERENCE.md)** (11 KB)

Quick lookup reference:
- Server VM IDs by site (5001-5070)
- Workstation VM IDs by site and department (6001-6458)
- VIP system quick reference
- Deployment priority order
- Proxmox command examples

### 3. **[NETWORK_BRIDGE_REFERENCE.md](computer:///mnt/user-data/outputs/NETWORK_BRIDGE_REFERENCE.md)** (14 KB)

**NEW** - Complete network architecture documentation:
- All 41 network bridges (stk100-stk140)
- Bridge-by-bridge system counts
- Security zone design
- IP address planning per site
- Firewall rule recommendations
- Traffic flow examples
- Troubleshooting guide
- Proxmox bridge creation commands

### 4. **[CHANGES_SUMMARY.md](computer:///mnt/user-data/outputs/CHANGES_SUMMARY.md)** (7.2 KB)

Update summary:
- Network configuration changes (v2.1 → v2.2)
- Bridge assignment logic
- Most utilized networks
- Validation results
- Next steps for deployment

---

## 📊 Configuration Summary

### Total Infrastructure
```
Total VMs:        343
├── Servers:      48 (14.0%)
└── Workstations: 295 (86.0%)

Network Bridges:  41 (stk100-stk140)
VIP Systems:      3 (marked in JSON)
```

### VM ID Allocation
```
Proxmox Resource Grouping:
├── 1-999      : CDX Management
├── 1000-1999  : Blue Team (SOC)
├── 2000-2999  : Templates (10 OS templates defined)
├── 3000-3999  : APT resources
├── 4000-4999  : CDX Internet (grey space)
└── 5000-6999  : Defended/Target ← CHILLED_ROCKET HERE
    ├── 5000-5999 : Servers (48 systems)
    └── 6000-6999 : Workstations (295 systems)
```

### Network Segmentation
```
Site            Bridges      Systems
──────────────────────────────────────
HQ              stk100-110   104
Malibu          stk111-115   30
Dallas          stk116-124   62
Nagasaki        stk125-132   76
Amsterdam       stk133-140   71
```

### Operating Systems
```
Servers:
├── Windows Server 2025:  5 systems (10.4%)
├── Windows Server 2022: 15 systems (31.3%)
└── Windows Server 2019: 28 systems (58.3%)

Workstations:
├── Windows 11 Pro:       97 systems (32.9%)
├── Windows 10 Ent:      169 systems (57.3%)
├── Windows 8.1 Ent:      16 systems (5.4%)
└── Windows 7 Ent:        13 systems (4.4%)
```

---

## 🚀 Quick Start Deployment

### Step 1: Download Configuration
Download **computers.json** (main file)

### Step 2: Create Proxmox Bridges
See NETWORK_BRIDGE_REFERENCE.md for commands:
```bash
# Example: HQ Core Servers
auto stk100
iface stk100 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

### Step 3: Clone VMs from Templates
```bash
# Example: Domain Controller
qm clone 2003 5001 --name STK-DC-01 --full
qm set 5001 --net0 virtio=14:18:77:3A:2B:C1,bridge=stk100,firewall=1
```

### Step 4: Deploy with CDX-E Framework
```powershell
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -GenerateStructure
```

---

## 🔐 VIP Systems

Three critical executive workstations are marked in the configuration:

| User | VM ID | Hostname | Network | MAC |
|------|-------|----------|---------|-----|
| **Tony Stark** (CEO) | 6200 | ML-DEV-W32805N | stk115 (Malibu Dev) | D4:AE:52:C4:2D:34 |
| **Pepper Potts** (COO) | 6001 | HQ-OPS-XAJI0Y6DPB | stk106 (HQ Ops) | 00:1F:29:65:D6:70 |
| **Happy Hogan** (COS) | 6022 | HQ-SUP-J2D54I3QK2 | stk103 (HQ Support) | 00:21:5A:CC:A8:8E |

---

## 🏢 Site Distribution

### HQ (New York) - 104 systems
- **Network:** 66.218.180.0/22
- **Bridges:** stk100-stk110 (11 networks)
- **Servers:** 12 (DCs, file, DB, web, app)
- **Departments:** 10 (Operations, IT, HR, Legal, Engineering, QA, CAD)

### Malibu (California) - 30 systems
- **Network:** 4.150.216.0/22
- **Bridges:** stk111-stk115 (5 networks)
- **Servers:** 9 (including Server 2025 dev infrastructure)
- **Focus:** Tony Stark's development operations

### Dallas (Texas) - 62 systems
- **Network:** 50.222.72.0/22
- **Bridges:** stk116-stk124 (9 networks)
- **Servers:** 7 (DC, file, DB, NMS)
- **Departments:** 7 (Operations, Engineering, QA, CAD)

### Nagasaki (Japan) - 76 systems
- **Network:** 14.206.0.0/22
- **Bridges:** stk125-stk132 (8 networks)
- **Servers:** 8 (DC, file, DB, NMS, WSUS-APAC)
- **Departments:** 6 (Operations, Engineering, QA)

### Amsterdam (Netherlands) - 71 systems
- **Network:** 37.74.124.0/22
- **Bridges:** stk133-stk140 (8 networks)
- **Servers:** 12 (DC, file, DB, web, app, WSUS-EU)
- **Departments:** 6 (Operations, Engineering, QA)

---

## 📋 Template Mapping

Proxmox templates for VM cloning:

| Template ID | Operating System | Usage |
|------------|------------------|-------|
| **2001** | Windows Server 2025 | 5 servers (Malibu advanced) |
| **2002** | Windows Server 2022 | 15 servers (NMS, WSUS, web, app) |
| **2003** | Windows Server 2019 | 28 servers (DCs, file, DB) |
| **2009** | Windows 11 Professional | 97 workstations |
| **2010** | Windows 10 Enterprise | 169 workstations |
| **2011** | Windows 8.1 Enterprise | 16 workstations (legacy) |
| **2012** | Windows 7 Enterprise | 13 workstations (legacy) |

---

## 🛡️ Security Features

### Network Segmentation
- ✅ Separate bridges for core servers, DMZ, and departments
- ✅ Firewall enabled on all 343 interfaces
- ✅ Site-level network isolation
- ✅ Department-level access control

### Zone Isolation
```
Internet → Boundary → DMZ → Core Servers → Departments
```

### Monitoring Points
- Per-bridge traffic monitoring
- Per-zone firewall logging
- VIP system enhanced monitoring
- Critical server alerting (DCs marked)

---

## 🔧 Integration with CDX-E

This configuration is designed to work seamlessly with the CDX-E Active Directory Deployment Framework:

**Repository:** https://github.com/phybroptyx/CDX-E

**Compatible Files:**
- ad_deploy.ps1 (master deployment script)
- generate_structure.ps1 (topology generator)
- computers.json (this file)
- services.json, users.json, gpo.json (from repository)

---

## 📝 Configuration Version History

| Version | Date | Changes |
|---------|------|---------|
| **2.2** | 2025-11-24 | Added network bridge configuration (41 bridges) |
| **2.1** | 2025-11-24 | Changed Windows 11 to Professional edition |
| **2.0** | 2025-11-24 | Initial release with VM IDs and templates |

---

## ✅ Validation Checklist

Before deployment, verify:

- [ ] All 10 Proxmox templates exist (2001, 2002, 2003, 2009-2012)
- [ ] All 41 network bridges created (stk100-stk140)
- [ ] Sufficient storage for 343 VMs
- [ ] Network subnets configured per site
- [ ] Firewall rules defined
- [ ] DHCP scopes configured (optional)
- [ ] Backup strategy in place
- [ ] AD domain ready (or new forest planned)

---

## 📞 Support & Resources

- **Framework:** CDX-E v2.0
- **Exercise:** CHILLED_ROCKET (Stark Industries)
- **Repository:** https://github.com/phybroptyx/CDX-E
- **Total VMs:** 343 systems across 5 global sites

---

## 🎯 Files Overview

| File | Size | Description |
|------|------|-------------|
| **computers.json** | 170 KB | ⭐ Main configuration file |
| DEPLOYMENT_SUMMARY.md | 9.3 KB | Deployment guide |
| VM_ID_REFERENCE.md | 11 KB | Quick VM ID lookup |
| NETWORK_BRIDGE_REFERENCE.md | 14 KB | Network documentation |
| CHANGES_SUMMARY.md | 7.2 KB | Update summary |

---

**Generated:** 2025-11-24  
**Configuration Version:** 2.2 (Network-Enabled)  
**Status:** ✅ Ready for Deployment

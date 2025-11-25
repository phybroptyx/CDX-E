# CHILLED_ROCKET - Quick VM ID Reference

## VM ID Ranges by Category

```
Proxmox Environment VM ID Allocation:
├── 1-999      : CDX Management resources
├── 1000-1999  : Blue Team (SOC) resources
├── 2000-2999  : Templates
│   ├── 2001 : Windows Server 2025
│   ├── 2002 : Windows Server 2022
│   ├── 2003 : Windows Server 2019
│   ├── 2004 : Windows Server 2016
│   ├── 2006 : Windows Server 2012 R2
│   ├── 2008 : Windows Server 2008 R2
│   ├── 2009 : Windows 11 Professional
│   ├── 2010 : Windows 10 Enterprise
│   ├── 2011 : Windows 8.1 Enterprise
│   └── 2012 : Windows 7 Enterprise
├── 3000-3999  : Advanced Persistent Threat (APT) resources
├── 4000-4999  : CDX Internet (grey space) resources
└── 5000-6999  : Defended/Target resources ← CHILLED_ROCKET DEPLOYED HERE
    ├── 5000-5999 : Servers (48 systems)
    └── 6000-6999 : Workstations (295 systems)
```

## CHILLED_ROCKET Server VM IDs (5001-5070)

### Domain Controllers
```
5001  STK-DC-01   HQ Primary DC          Windows Server 2019
5002  STK-DC-02   HQ Secondary DC        Windows Server 2019
5003  STK-DC-03   Dallas DC              Windows Server 2019
5004  STK-DC-04   Nagasaki DC            Windows Server 2019
5005  STK-DC-05   Amsterdam DC           Windows Server 2019
```

### HQ Servers (5010-5019)
```
5010  HQ-FS-01    File Server            Windows Server 2019
5011  HQ-FS-02    File Server            Windows Server 2019
5012  HQ-NMS-01   Network Management     Windows Server 2022
5013  HQ-WSU-01   WSUS (Americas)        Windows Server 2022
5014  HQ-DB-01    Database Server        Windows Server 2019
5015  HQ-DB-02    Database Server        Windows Server 2019
5016  HQ-WEB-01   Web Server             Windows Server 2022
5017  HQ-WEB-02   Web Server             Windows Server 2022
5018  HQ-APP-01   Application Server     Windows Server 2022
5019  HQ-APP-02   Application Server     Windows Server 2022
```

### Dallas Servers (5030-5035)
```
5030  DAL-FS-01   File Server            Windows Server 2019
5031  DAL-FS-02   File Server            Windows Server 2019
5032  DAL-NMS-01  Network Management     Windows Server 2022
5033  DAL-DB-01   Database Server        Windows Server 2019
5034  DAL-DB-02   Database Server        Windows Server 2019
5035  DAL-DB-03   Database Server        Windows Server 2019
```

### Malibu Servers (5040-5048)
```
5040  MAL-FS-01   File Server            Windows Server 2019
5041  MAL-FS-02   File Server            Windows Server 2019
5042  MAL-NMS-01  Network Management     Windows Server 2025 ⭐
5043  MAL-DB-01   Database Server        Windows Server 2019
5044  MAL-DB-02   Database Server        Windows Server 2019
5045  MAL-DB-03   Database Server (Dev)  Windows Server 2025 ⭐
5046  MAL-DB-04   Database Server (Dev)  Windows Server 2025 ⭐
5047  MAL-APP-01  App Server (Dev)       Windows Server 2025 ⭐
5048  MAL-APP-02  App Server (Dev)       Windows Server 2025 ⭐
```
⭐ = Advanced Server 2025 infrastructure for Tony Stark's operations

### Nagasaki Servers (5050-5056)
```
5050  NAG-FS-01   File Server            Windows Server 2019
5051  NAG-FS-02   File Server            Windows Server 2019
5052  NAG-NMS-01  Network Management     Windows Server 2022
5053  NAG-WSU-01  WSUS (Asia-Pacific)    Windows Server 2022
5054  NAG-DB-01   Database Server        Windows Server 2019
5055  NAG-DB-02   Database Server        Windows Server 2019
5056  NAG-DB-03   Database Server        Windows Server 2019
```

### Amsterdam Servers (5060-5070)
```
5060  AMS-FS-01   File Server            Windows Server 2019
5061  AMS-FS-02   File Server            Windows Server 2019
5062  AMS-NMS-01  Network Management     Windows Server 2022
5063  AMS-WSU-01  WSUS (Europe)          Windows Server 2022
5064  AMS-DB-01   Database Server        Windows Server 2019
5065  AMS-DB-02   Database Server        Windows Server 2019
5066  AMS-WEB-01  Web Server             Windows Server 2022
5067  AMS-WEB-02  Web Server             Windows Server 2022
5068  AMS-APP-01  Application Server     Windows Server 2022
5069  AMS-APP-02  Application Server     Windows Server 2022
5070  AMS-APP-03  Application Server     Windows Server 2022
```

## CHILLED_ROCKET Workstation VM IDs (6001-6458)

### HQ Workstations (6001-6092) - 92 systems
```
Department              VM ID Range    Count
─────────────────────────────────────────────
Operations              6001-6015      15
IT-Core                 6016-6021      6
Ops-Support             6022-6026      5
HR                      6027-6035      9
Legal                   6036-6043      8
Gov-Liaison             6044-6051      8
Engineering             6052-6058      7
Engineering Development 6059-6064      6
QA                      6065-6079      15
CAD                     6080-6092      13
```

**VIP Systems:**
- **6001** - HQ-OPS-XAJI0Y6DPB (Pepper Potts, COO)
- **6022** - HQ-SUP-J2D54I3QK2 (Happy Hogan, COS)

### Dallas Workstations (6100-6154) - 55 systems
```
Department              VM ID Range    Count
─────────────────────────────────────────────
Operations              6100-6109      10
IT-Core                 6110-6114      5
Ops-Support             6115-6119      5
Engineering             6120-6129      10
Engineering Development 6130-6139      10
QA                      6140-6149      10
CAD                     6150-6154      5
```

### Malibu Workstations (6200-6220) - 21 systems
```
Department              VM ID Range    Count
─────────────────────────────────────────────
Operations              6200-6204      5
Development             6205-6220      16
```

**VIP System:**
- **6200** - ML-DEV-W32805N (Tony Stark, CEO) ⭐

### Nagasaki Workstations (6300-6367) - 68 systems
```
Department              VM ID Range    Count
─────────────────────────────────────────────
Operations              6300-6314      15
IT-Core                 6315-6320      6
Ops-Support             6321-6325      5
Engineering             6326-6337      12
Engineering Development 6338-6349      12
QA                      6350-6367      18
```

### Amsterdam Workstations (6400-6458) - 59 systems
```
Department              VM ID Range    Count
─────────────────────────────────────────────
Operations              6400-6411      12
IT-Core                 6412-6416      5
Ops-Support             6417-6421      5
Engineering             6422-6431      10
Engineering Development 6432-6443      12
QA                      6444-6458      15
```

## Quick Stats

### By Type
- **Total VMs:** 343
- **Servers:** 48 (14.0%)
- **Workstations:** 295 (86.0%)

### By Site
```
Site         Servers  Workstations  Total  Percentage
──────────────────────────────────────────────────────
HQ           12       92            104    30.3%
Dallas       7        55            62     18.1%
Malibu       9        21            30     8.7%
Nagasaki     8        68            76     22.2%
Amsterdam    12       59            71     20.7%
```

### By OS Family
```
OS Family                Count   Percentage
─────────────────────────────────────────────
Windows Server 2019      28      8.2%
Windows Server 2022      15      4.4%
Windows Server 2025      5       1.5%
Windows 11 Professional  97      28.3%
Windows 10 Enterprise    169     49.3%
Windows 8.1 Enterprise   16      4.7%
Windows 7 Enterprise     13      3.8%
```

## Deployment Command Examples

### Clone a single VM
```bash
# Clone Domain Controller from template
qm clone 2003 5001 --name STK-DC-01 --full

# Clone VIP workstation (Tony Stark)
qm clone 2010 6200 --name ML-DEV-W32805N --full
```

### Clone entire site
```bash
# Script to clone all HQ servers (5001-5019)
for vmid in {5001..5019}; do
    # Logic to determine correct template and name from JSON
    echo "Cloning VM $vmid..."
done
```

### Set MAC address post-clone
```bash
# Set MAC for Domain Controller
qm set 5001 --net0 virtio=14:18:77:3A:2B:C1,bridge=vmbr0

# Set MAC for VIP workstation
qm set 6001 --net0 virtio=00:1F:29:65:D6:70,bridge=vmbr0
```

## Priority Deployment Order

### Phase 1: Critical Infrastructure (Priority 1)
1. Domain Controllers: 5001-5005
2. DNS/DHCP if separate from DCs
3. Verify AD replication

### Phase 2: Core Services (Priority 2)
4. WSUS Servers: 5013, 5053, 5063
5. File Servers: 5010-5011, 5030-5031, etc.
6. Network Management: 5012, 5032, 5042, 5052, 5062

### Phase 3: VIP Systems (Priority 3)
7. Tony Stark: 6200
8. Pepper Potts: 6001
9. Happy Hogan: 6022

### Phase 4: Application Infrastructure (Priority 4)
10. Database Servers: 5014-5015, 5033-5035, etc.
11. Web Servers: 5016-5017, 5066-5067
12. App Servers: 5018-5019, 5047-5048, 5068-5070

### Phase 5: Standard Workstations (Priority 5)
13. Deploy by site to manage load
14. Suggested order: HQ → Dallas → Nagasaki → Amsterdam → Malibu

## Notes

- All VM IDs are **statically assigned** - do not change
- **Gap spacing** between sites allows for future expansion
- **VIP systems** require special attention during deployment
- **Legacy OS** systems (Win 7/8.1) need security controls
- **Malibu** uses advanced Server 2025 for Tony's development work
- **WSUS servers** provide regional update management
- **Domain Controllers** should be deployed and verified first

## File Locations

- **Full Config:** `/mnt/user-data/outputs/computers.json`
- **Deployment Summary:** `/mnt/user-data/outputs/DEPLOYMENT_SUMMARY.md`
- **This Reference:** `/mnt/user-data/outputs/VM_ID_REFERENCE.md`

---
**Last Updated:** 2025-11-24  
**Framework:** CDX-E v2.0  
**Exercise:** CHILLED_ROCKET

# CDX-E Framework - VM ID Reference Guide

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
│   ├── 2007 : VyOS 2025
│   ├── 2008 : Windows Server 2008 R2
│   ├── 2009 : Windows 11 Professional
│   ├── 2010 : Windows 10 Enterprise
│   ├── 2011 : Windows 8.1 Enterprise
│   └── 2012 : Windows 7 Enterprise
├── 3000-3999  : Advanced Persistent Threat (APT) resources
│   ├── 3000-3199 : APT Infrastructure (routers/switches)
│   └── 3200-3999 : APT Systems (attack platforms, C2, etc.)
├── 4000-4999  : CDX Internet (grey space) resources
└── 5000-6999  : Defended/Target resources
    ├── 5000-5099 : Infrastructure Tier 1 (edge routers, primary devices)
    ├── 5100-5199 : Infrastructure Tier 2 (core switches, firewalls)
    ├── 5200-5299 : Domain Controllers
    ├── 5300-5399 : Critical Infrastructure (WSUS, NMS, DNS)
    ├── 5400-5499 : File Servers
    ├── 5500-5599 : Database Servers
    ├── 5600-5699 : Web Servers
    ├── 5700-5799 : Application Servers
    ├── 5800-5899 : Exchange Servers
    ├── 5900-5999 : Reserved for future expansion
    └── 6000-6999 : Workstations
```

---

## Template Definitions (2000-2999)

### Server Templates
```
VM ID  Template Name              Use Case
──────────────────────────────────────────────────────────────
2001   Windows Server 2025        Latest server OS
2002   Windows Server 2022        Modern server infrastructure
2003   Windows Server 2019        Standard enterprise servers
2004   Windows Server 2016        Legacy enterprise servers
2006   Windows Server 2012 R2     Legacy infrastructure
2008   Windows Server 2008 R2     End-of-life systems (attack surfaces)
```

### Network Templates
```
VM ID  Template Name              Use Case
──────────────────────────────────────────────────────────────
2007   VyOS 2025                  Routers, firewalls, VPN gateways
```

### Workstation Templates
```
VM ID  Template Name              Use Case
──────────────────────────────────────────────────────────────
2009   Windows 11 Professional    Modern workstations
2010   Windows 10 Enterprise      Standard enterprise desktops
2011   Windows 8.1 Enterprise     Legacy workstations
2012   Windows 7 Enterprise       End-of-life systems (attack surfaces)
```

---

## APT Resources (3000-3999)

### APT Infrastructure Devices (3000-3199)
Reserved for Red Team / APT network infrastructure:
- Routers for adversary networks
- VPN concentrators
- C2 redirectors
- Network pivoting infrastructure
- Adversary firewall/gateway devices

**Examples:**
```
3001-3050   : APT Tier 1 routers (primary infrastructure)
3051-3100   : APT Tier 2 routers (secondary infrastructure)
3101-3150   : C2 redirectors and proxy systems
3151-3199   : Reserved for future APT infrastructure
```

### APT Systems (3200-3999)
Reserved for adversary attack platforms and command systems:
- Command and Control (C2) servers
- Attack platforms (Kali, Parrot, Commando VM)
- Malware development systems
- Data exfiltration staging servers
- Adversary workstations

**Examples:**
```
3200-3299   : C2 servers and infrastructure
3300-3399   : Attack platforms and tooling
3400-3499   : Malware development environments
3500-3999   : Additional APT resources
```

---

## Defended/Target Resources (5000-6999)

### Defended Infrastructure Devices (5000-5199)
Reserved for enterprise network infrastructure:
- Edge routers
- Core switches
- Distribution layer routing
- Firewalls and security appliances
- VPN concentrators
- Load balancers

**Examples:**
```
5001-5050   : Site edge routers (HQ, regional offices)
5051-5100   : Core network switches and routing
5101-5150   : Firewalls and security appliances
5151-5199   : Reserved for additional infrastructure
```

---

## CHILLED_ROCKET Server VM IDs

### Domain Controllers (5200-5299)

#### HQ Domain Controllers
```
5200  STK-DC-01   HQ Primary DC          Windows Server 2012 R2 ⚠️
5201  STK-DC-02   HQ Secondary DC        Windows Server 2012 R2 ⚠️
5202  STK-DC-03   HQ Tertiary DC         Windows Server 2012 R2 ⚠️
5203  STK-DC-04   HQ Additional DC       Windows Server 2012 R2 ⚠️
```

#### Malibu Domain Controllers
```
5204  STK-DC-05   Malibu DC              Windows Server 2019
5205  STK-DC-06   Malibu DC              Windows Server 2019
5206  STK-DC-07   Malibu DC              Windows Server 2019
```

#### Dallas Domain Controllers
```
5207  STK-DC-08   Dallas DC              Windows Server 2008 R2 🔴 EOL
5208  STK-DC-09   Dallas DC              Windows Server 2008 R2 🔴 EOL
5209  STK-DC-10   Dallas DC              Windows Server 2019
5210  STK-DC-11   Dallas DC              Windows Server 2019
```

#### Nagasaki Domain Controllers
```
5211  STK-DC-12   Nagasaki DC            Windows Server 2016 ⚠️
5212  STK-DC-13   Nagasaki DC            Windows Server 2016 ⚠️
5213  STK-DC-14   Nagasaki DC            Windows Server 2016 ⚠️
```

#### Amsterdam Domain Controllers
```
5214  STK-DC-15   Amsterdam DC           Windows Server 2016 ⚠️
5215  STK-DC-16   Amsterdam DC           Windows Server 2016 ⚠️
5216  STK-DC-17   Amsterdam DC           Windows Server 2016 ⚠️
5217  STK-DC-18   Amsterdam DC           Windows Server 2012 R2 ⚠️
```

🔴 = End of Life (CRITICAL)  
⚠️ = Legacy OS (requires additional monitoring)

**Total Domain Controllers:** 17

---

### Critical Infrastructure Servers (5300-5399)

```
5300  HQ-NMS-01   Network Management     Windows Server 2019
5301  HQ-WSU-01   WSUS (Americas)        Windows Server 2019
5302  DL-NMS-01   Network Management     Windows Server 2019
5303  ML-NMS-01   Network Management     Windows Server 2019
5304  NG-NMS-01   Network Management     Windows Server 2019
5305  NG-WSU-01   WSUS (Asia-Pacific)    Windows Server 2019
5306  AM-NMS-01   Network Management     Windows Server 2019
5307  AM-WSU-01   WSUS (Europe)          Windows Server 2019
```

**Total Infrastructure Servers:** 8

---

### File Servers (5400-5499)

```
5400  HQ-FS-01    HQ File Server         Windows Server 2019
5401  HQ-FS-02    HQ File Server         Windows Server 2019
5402  DL-FS-01    Dallas File Server     Windows Server 2019
5403  ML-FS-01    Malibu File Server     Windows Server 2019
5404  ML-FS-02    Malibu File Server     Windows Server 2019
5405  NG-FS-01    Nagasaki File Server   Windows Server 2019
5406  NG-FS-02    Nagasaki File Server   Windows Server 2019
5407  AM-FS-01    Amsterdam File Server  Windows Server 2019
5408  AM-FS-02    Amsterdam File Server  Windows Server 2019
```

**Total File Servers:** 9

---

### Database Servers (5500-5599)

```
5500  HQ-SQL-01   HQ Database            Windows Server 2012 R2 ⚠️
5501  HQ-SQL-02   HQ Database            Windows Server 2012 R2 ⚠️
5502  DL-SQL-01   Dallas Database        Windows Server 2012 R2 ⚠️
5503  DL-SQL-02   Dallas Database        Windows Server 2012 R2 ⚠️
5504  DL-SQL-03   Dallas Database        Windows Server 2012 R2 ⚠️
5505  ML-SQL-01   Malibu Database        Windows Server 2012 R2 ⚠️
5506  ML-SQL-02   Malibu Database        Windows Server 2012 R2 ⚠️
5507  ML-SQL-03   Malibu Database        Windows Server 2019
5508  ML-SQL-04   Malibu Database        Windows Server 2019
5509  NG-SQL-01   Nagasaki Database      Windows Server 2012 R2 ⚠️
5510  NG-SQL-02   Nagasaki Database      Windows Server 2012 R2 ⚠️
5511  NG-SQL-03   Nagasaki Database      Windows Server 2012 R2 ⚠️
5512  AM-SQL-01   Amsterdam Database     Windows Server 2012 R2 ⚠️
5513  AM-SQL-02   Amsterdam Database     Windows Server 2012 R2 ⚠️
```

**Total Database Servers:** 14

---

### Web Servers (5600-5699)

```
5600  AM-WEB-01   Amsterdam Web Server   Windows Server 2019
5601  AM-WEB-02   Amsterdam Web Server   Windows Server 2012 R2 ⚠️
```

**Total Web Servers:** 2

---

### Application Servers (5700-5799)

```
5700  ML-APP-01   Malibu App Server      Windows Server 2016 ⚠️
5701  ML-APP-02   Malibu App Server      Windows Server 2016 ⚠️
5702  AM-APP-01   Amsterdam App Server   Windows Server 2019
5703  AM-APP-02   Amsterdam App Server   Windows Server 2012 R2 ⚠️
5704  AM-APP-03   Amsterdam App Server   Windows Server 2012 R2 ⚠️
5705  ML-APP-03   Malibu App Server      Windows Server 2016 ⚠️
5706  AM-APP-04   Amsterdam App Server   Windows Server 2016 ⚠️
```

**Total Application Servers:** 7

---

### Exchange Servers (5800-5899)

```
5800  HQ-EX-01    HQ Exchange            Windows Server 2012 R2 ⚠️
5801  HQ-EX-02    HQ Exchange            Windows Server 2012 R2 ⚠️
5802  HQ-EX-03    HQ Exchange            Windows Server 2012 R2 ⚠️
5803  DL-EX-01    Dallas Exchange        Windows Server 2012 R2 ⚠️
5804  DL-EX-02    Dallas Exchange        Windows Server 2012 R2 ⚠️
5805  DL-EX-03    Dallas Exchange        Windows Server 2012 R2 ⚠️
5806  ML-EX-01    Malibu Exchange        Windows Server 2012 R2 ⚠️
5807  ML-EX-02    Malibu Exchange        Windows Server 2012 R2 ⚠️
5808  NG-EX-01    Nagasaki Exchange      Windows Server 2012 R2 ⚠️
5809  NG-EX-02    Nagasaki Exchange      Windows Server 2012 R2 ⚠️
5810  NG-EX-03    Nagasaki Exchange      Windows Server 2012 R2 ⚠️
5811  AM-EX-01    Amsterdam Exchange     Windows Server 2012 R2 ⚠️
5812  AM-EX-02    Amsterdam Exchange     Windows Server 2012 R2 ⚠️
5813  AM-EX-03    Amsterdam Exchange     Windows Server 2012 R2 ⚠️
```

**Total Exchange Servers:** 14  
**Note:** All Exchange servers are Windows Server 2012 R2 (Legacy)

---

## CHILLED_ROCKET Workstation VM IDs (6000-6999)

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

---

## Quick Stats

### By Type
- **Total VMs (CHILLED_ROCKET):** 366
- **Servers:** 71 (19.4%)
- **Workstations:** 295 (80.6%)

### By Site
```
Site         Servers  Workstations  Total  Percentage
──────────────────────────────────────────────────────
HQ           13       92            105    28.7%
Dallas       11       55            66     18.0%
Malibu       13       21            34     9.3%
Nagasaki     13       68            81     22.1%
Amsterdam    21       59            80     21.9%
```

### By Server Function
```
Function                 Count   VM ID Range
──────────────────────────────────────────────
Domain Controllers       17      5200-5217
Critical Infrastructure  8       5300-5307
File Servers             9       5400-5408
Database Servers         14      5500-5513
Web Servers              2       5600-5601
Application Servers      7       5700-5706
Exchange Servers         14      5800-5813
```

### By OS Family
```
OS Family                Count   Percentage  Status
──────────────────────────────────────────────────────────
Windows Server 2008 R2   2       0.5%        🔴 CRITICAL EOL
Windows Server 2012 R2   28      7.7%        ⚠️  HIGH RISK
Windows Server 2016      7       1.9%        ⚠️  MEDIUM RISK
Windows Server 2019      34      9.3%        ✓  Modern
Windows 11 Professional  97      26.5%
Windows 10 Enterprise    169     46.2%
Windows 8.1 Enterprise   16      4.4%
Windows 7 Enterprise     13      3.6%
```

**Server Risk Summary:**
- **CRITICAL (EOL):** 2 servers (2.8% of servers) - Windows Server 2008 R2
- **HIGH RISK:** 28 servers (39.4% of servers) - Windows Server 2012 R2  
- **MEDIUM RISK:** 7 servers (9.9% of servers) - Windows Server 2016
- **MODERN:** 34 servers (47.9% of servers) - Windows Server 2019
- **Total Legacy:** 37 servers (52.1% of all servers)

---

## Deployment Command Examples

### Clone Infrastructure Device (VyOS Router)
```bash
# Clone VyOS template to create defended edge router
qm clone 2007 5001 --name STK-RTR-HQ-EDGE --full

# Clone VyOS template to create APT infrastructure
qm clone 2007 3001 --name APT-RTR-TIER1 --full
```

### Clone Domain Controller
```bash
# Clone Domain Controller to proper range
qm clone 2006 5200 --name STK-DC-01 --full

# Clone modern DC
qm clone 2003 5204 --name STK-DC-05 --full
```

### Clone File Server
```bash
# Clone file server to file server range
qm clone 2003 5400 --name HQ-FS-01 --full
```

### Clone Database Server
```bash
# Clone database server to database range
qm clone 2006 5500 --name HQ-SQL-01 --full
```

### Clone Exchange Server
```bash
# Clone Exchange server to Exchange range
qm clone 2006 5800 --name HQ-EX-01 --full
```

### Clone VIP Workstation
```bash
# Clone VIP workstation (Tony Stark)
qm clone 2010 6200 --name ML-DEV-W32805N --full
```

### Set Network Configuration
```bash
# Configure network for infrastructure device
qm set 5001 --net0 virtio=52:54:00:12:34:56,bridge=stk100,firewall=1

# Configure network for APT infrastructure
qm set 3001 --net0 virtio=52:54:00:AB:CD:EF,bridge=apt100,firewall=0

# Configure network for Domain Controller
qm set 5200 --net0 virtio=14:18:77:6B:A3:83,bridge=stk100,firewall=1

# Configure network for File Server
qm set 5400 --net0 virtio=14:18:77:68:64:4E,bridge=stk100,firewall=1
```

---

## Priority Deployment Order

### Phase 0: Infrastructure Preparation
1. Network infrastructure devices: 5000-5099 (edge routers)
2. Core network devices: 5100-5199 (switches, firewalls)
3. Verify routing and connectivity

### Phase 1: Critical Infrastructure (Priority 1)
4. Domain Controllers (5200-5217)
   - **Deploy modern DCs FIRST** (Windows Server 2019)
   - **STK-DC-08/09 (5207-5208)** should only be deployed for training scenarios
   - If deploying 2008 R2 DCs, isolate immediately with enhanced monitoring
   - Verify AD replication between each DC deployment
   - Wait 15 minutes between DC deployments

**🔴 EOL System Deployment Warning:**
```
CRITICAL SECURITY ADVISORY - VMs 5207-5208:
STK-DC-08 and STK-DC-09 are Windows Server 2008 R2 (End-of-Life)
- Deploy ONLY in isolated training environments
- NO production use under any circumstances  
- Enhanced security monitoring REQUIRED (SIEM integration mandatory)
- No direct internet connectivity
- Immediate replacement recommended within 30 days
```

### Phase 2: Core Services (Priority 2)
5. Infrastructure Servers (5300-5307)
   - Network Management Systems (NMS)
   - WSUS Servers (regional update management)
6. File Servers (5400-5408)

### Phase 3: VIP Systems (Priority 3)
7. Tony Stark: 6200 (ML-DEV-W32805N)
8. Pepper Potts: 6001 (HQ-OPS-XAJI0Y6DPB)
9. Happy Hogan: 6022 (HQ-SUP-J2D54I3QK2)

### Phase 4: Application Infrastructure (Priority 4)
10. Database Servers (5500-5513)
11. Web Servers (5600-5601)
12. Application Servers (5700-5706)
13. Exchange Servers (5800-5813)
    - **NOTE:** All Exchange servers are legacy Windows Server 2012 R2

### Phase 5: Standard Workstations (Priority 5)
14. Deploy by site to manage load
15. Suggested order: HQ → Dallas → Nagasaki → Amsterdam → Malibu

---

## APT Deployment Considerations

### Infrastructure First
When deploying Red Team/APT resources:
1. Deploy APT routers (3000-3199) before attack systems
2. Establish APT network segmentation
3. Configure C2 redirectors and proxy infrastructure
4. Verify isolation from defended networks

### Attack Platform Deployment
5. Deploy C2 servers (3200-3299)
6. Deploy attack platforms (3300-3399)
7. Configure persistence and staging infrastructure
8. Test connectivity through APT infrastructure

---

## Notes

- **Function-based allocation** organizes servers by role for easier management
- **Infrastructure carve-outs** (5000-5199) provide dedicated space for network devices
- **APT infrastructure isolation** (3000-3199) separates adversary network equipment
- **VyOS template (2007)** enables realistic routing scenarios
- **Range spacing** allows for expansion within each functional category
- **VIP systems** require special attention during deployment
- **Domain Controllers** should verify AD replication after each deployment
- **🔴 EOL SYSTEMS:** VMs 5207-5208 (Windows Server 2008 R2) are End-of-Life
  - Deploy ONLY in isolated training environments for Red Team scenarios
  - NO production use - security risk is CRITICAL
  - 1000+ known unpatched CVEs
  - Enhanced monitoring and compensating controls REQUIRED
- **⚠️ Exchange Servers:** All 14 Exchange servers run Windows Server 2012 R2 (legacy)
  - High-value targets for Red Team operations
  - Requires upgrade planning for production environments
- **Critical Services:** WSUS servers provide regional update management
  - Americas (HQ): 5301
  - Asia-Pacific (Nagasaki): 5305
  - Europe (Amsterdam): 5307

---

## File Locations

- **Full Config:** `computers.json` (within exercise directory)
- **This Reference:** `VM_ID_REFERENCE.md`
- **Network Documentation:** `NETWORK_BRIDGE_REFERENCE.md`
- **Deployment Guide:** `CHILLED_ROCKET_DEPLOYMENT_GUIDE.md`

---

**Last Updated:** 2025-12-07  
**Framework:** CDX-E v3.1  
**Exercise:** CHILLED_ROCKET  
**Total Systems:** 366 VMs (71 servers + 295 workstations)

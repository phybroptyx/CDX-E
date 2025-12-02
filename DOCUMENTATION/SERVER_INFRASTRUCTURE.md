# Stark Industries - Server Infrastructure Overview

## Executive Summary

This document details the complete server infrastructure for Stark Industries' Active Directory deployment across five global sites. The infrastructure follows a standardized naming convention and utilizes Dell PowerEdge 14th-15th generation servers for all server hardware.

---

## Naming Convention

**Server Format**: `{SITE}-{FUNCTION}-{NUMBER}`
- **SITE**: 2-3 letter site code (HQ, DAL, MAL, NAG, AMS)
- **FUNCTION**: 2-3 character function abbreviator
- **NUMBER**: 2-digit sequential identifier

**Exception**: Domain Controllers use prefix `STK-DC-##` regardless of location

### Function Abbreviations
- **DC**: Domain Controller (prefix STK only)
- **FS**: File Server
- **NMS**: Network Management Server
- **WSU**: WSUS (Windows Server Update Services)
- **DB**: Database Server
- **WEB**: Web Server
- **APP**: Application Server

---

## Infrastructure by Site

### Headquarters (HQ) - New York City
**Location**: Stark Tower, NYC, USA  
**Subnet**: 66.218.180.0/22

#### Servers (15 total)
| Hostname | Type | OS | Model | MAC Address | OU Path |
|----------|------|----|----|-------------|---------|
| STK-DC-01 | Domain Controller | Server 2019 | R640 | 14:18:77:3A:2B:C1 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| STK-DC-02 | Domain Controller | Server 2019 | R640 | 14:18:77:3A:2B:C2 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-FS-01 | File Server | Server 2019 | R740xd | 14:18:77:3A:5F:11 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-FS-02 | File Server | Server 2019 | R740xd | 14:18:77:3A:5F:12 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-NMS-01 | Network Management | Server 2022 | R650 | 14:18:77:3A:7C:31 | OU=Servers,OU=IT-Core,OU=HQ,OU=Sites |
| HQ-WSU-01 | WSUS (Americas) | Server 2022 | R650 | 14:18:77:3A:9D:51 | OU=Servers,OU=IT-Core,OU=HQ,OU=Sites |
| HQ-DB-01 | Database Server | Server 2019 | R750 | 14:18:77:3A:8B:21 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-DB-02 | Database Server | Server 2019 | R750 | 14:18:77:3A:8B:22 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-WEB-01 | Web Server | Server 2022 | R650 | 14:18:77:3A:4E:41 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-WEB-02 | Web Server | Server 2022 | R650 | 14:18:77:3A:4E:42 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-APP-01 | Application Server | Server 2022 | R650 | 14:18:77:3A:6D:61 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |
| HQ-APP-02 | Application Server | Server 2022 | R650 | 14:18:77:3A:6D:62 | OU=Servers,OU=Operations,OU=HQ,OU=Sites |

**Total HQ Servers**: 15 (2 DC, 2 FS, 1 NMS, 1 WSUS, 2 DB, 2 WEB, 2 APP)

---

### Dallas Branch (DAL) - Texas
**Location**: Dallas, TX, USA  
**Subnet**: 50.222.72.0/22

#### Servers (6 total)
| Hostname | Type | OS | Model | MAC Address | OU Path |
|----------|------|----|----|-------------|---------|
| STK-DC-03 | Domain Controller | Server 2019 | R640 | 14:18:77:4F:8E:D1 | OU=Servers,OU=Operations,OU=Dallas,OU=Sites |
| DAL-FS-01 | File Server | Server 2019 | R740xd | 14:18:77:4F:5A:11 | OU=Servers,OU=Operations,OU=Dallas,OU=Sites |
| DAL-FS-02 | File Server | Server 2019 | R740xd | 14:18:77:4F:5A:12 | OU=Servers,OU=Operations,OU=Dallas,OU=Sites |
| DAL-NMS-01 | Network Management | Server 2022 | R650 | 14:18:77:4F:7B:31 | OU=Servers,OU=IT-Core,OU=Dallas,OU=Sites |
| DAL-DB-01 | Database Server | Server 2019 | R750 | 14:18:77:4F:8C:21 | OU=Servers,OU=Operations,OU=Dallas,OU=Sites |
| DAL-DB-02 | Database Server | Server 2019 | R750 | 14:18:77:4F:8C:22 | OU=Servers,OU=Operations,OU=Dallas,OU=Sites |

**Total Dallas Servers**: 6 (1 DC, 2 FS, 1 NMS, 2 DB)

---

### Malibu Mansion (MAL) - California
**Location**: Malibu, CA, USA  
**Subnet**: 4.150.216.0/22

#### Servers (9 total)
| Hostname | Type | OS | Model | MAC Address | OU Path |
|----------|------|----|----|-------------|---------|
| MAL-FS-01 | File Server | Server 2019 | R740xd | 14:18:77:2C:5E:11 | OU=Servers,OU=Operations,OU=Malibu,OU=Sites |
| MAL-FS-02 | File Server | Server 2019 | R740xd | 14:18:77:2C:5E:12 | OU=Servers,OU=Operations,OU=Malibu,OU=Sites |
| MAL-NMS-01 | Network Management | Server 2025 | R660 | 14:18:77:2C:7A:31 | OU=Servers,OU=Operations,OU=Malibu,OU=Sites |
| MAL-DB-01 | Database Server | Server 2019 | R750 | 14:18:77:2C:8D:21 | OU=Servers,OU=Operations,OU=Malibu,OU=Sites |
| MAL-DB-02 | Database Server | Server 2019 | R750 | 14:18:77:2C:8D:22 | OU=Servers,OU=Operations,OU=Malibu,OU=Sites |
| MAL-DB-03 | Database Server (Dev) | Server 2025 | R760 | 14:18:77:2C:8D:23 | OU=Servers,OU=Development,OU=Malibu,OU=Sites |
| MAL-DB-04 | Database Server (Dev) | Server 2025 | R760 | 14:18:77:2C:8D:24 | OU=Servers,OU=Development,OU=Malibu,OU=Sites |
| MAL-APP-01 | Application Server | Server 2025 | R660 | 14:18:77:2C:6F:61 | OU=Servers,OU=Development,OU=Malibu,OU=Sites |
| MAL-APP-02 | Application Server | Server 2025 | R660 | 14:18:77:2C:6F:62 | OU=Servers,OU=Development,OU=Malibu,OU=Sites |

**Total Malibu Servers**: 9 (2 FS, 1 NMS, 4 DB, 2 APP)
**Note**: Malibu features Windows Server 2025 for newer infrastructure supporting Tony Stark's development work

---

### Nagasaki Facility (NAG) - Japan
**Location**: Nagasaki, Japan  
**Subnet**: 14.206.0.0/22

#### Servers (7 total)
| Hostname | Type | OS | Model | MAC Address | OU Path |
|----------|------|----|----|-------------|---------|
| STK-DC-04 | Domain Controller | Server 2019 | R640 | 14:18:77:6B:1C:A1 | OU=Servers,OU=Operations,OU=Nagasaki,OU=Sites |
| NAG-FS-01 | File Server | Server 2019 | R740xd | 14:18:77:6B:5C:11 | OU=Servers,OU=Operations,OU=Nagasaki,OU=Sites |
| NAG-FS-02 | File Server | Server 2019 | R740xd | 14:18:77:6B:5C:12 | OU=Servers,OU=Operations,OU=Nagasaki,OU=Sites |
| NAG-NMS-01 | Network Management | Server 2022 | R650 | 14:18:77:6B:7D:31 | OU=Servers,OU=IT-Core,OU=Nagasaki,OU=Sites |
| NAG-WSU-01 | WSUS (Asia-Pacific) | Server 2022 | R650 | 14:18:77:6B:9E:51 | OU=Servers,OU=IT-Core,OU=Nagasaki,OU=Sites |
| NAG-DB-01 | Database Server | Server 2019 | R750 | 14:18:77:6B:8E:21 | OU=Servers,OU=Operations,OU=Nagasaki,OU=Sites |
| NAG-DB-02 | Database Server | Server 2019 | R750 | 14:18:77:6B:8E:22 | OU=Servers,OU=Operations,OU=Nagasaki,OU=Sites |

**Total Nagasaki Servers**: 7 (1 DC, 2 FS, 1 NMS, 1 WSUS, 2 DB)

---

### Amsterdam Hub (AMS) - Netherlands
**Location**: Amsterdam, Netherlands  
**Subnet**: 37.74.124.0/22

#### Servers (11 total)
| Hostname | Type | OS | Model | MAC Address | OU Path |
|----------|------|----|----|-------------|---------|
| STK-DC-05 | Domain Controller | Server 2019 | R640 | 14:18:77:8A:4D:E1 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-FS-01 | File Server | Server 2019 | R740xd | 14:18:77:8A:5B:11 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-FS-02 | File Server | Server 2019 | R740xd | 14:18:77:8A:5B:12 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-NMS-01 | Network Management | Server 2022 | R650 | 14:18:77:8A:7E:31 | OU=Servers,OU=IT-Core,OU=Amsterdam,OU=Sites |
| AMS-WSU-01 | WSUS (Europe) | Server 2022 | R650 | 14:18:77:8A:9F:51 | OU=Servers,OU=IT-Core,OU=Amsterdam,OU=Sites |
| AMS-DB-01 | Database Server | Server 2019 | R750 | 14:18:77:8A:8F:21 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-DB-02 | Database Server | Server 2019 | R750 | 14:18:77:8A:8F:22 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-WEB-01 | Web Server | Server 2022 | R650 | 14:18:77:8A:4F:41 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-WEB-02 | Web Server | Server 2022 | R650 | 14:18:77:8A:4F:42 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-APP-01 | Application Server | Server 2022 | R650 | 14:18:77:8A:6E:61 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |
| AMS-APP-02 | Application Server | Server 2022 | R650 | 14:18:77:8A:6E:62 | OU=Servers,OU=Operations,OU=Amsterdam,OU=Sites |

**Total Amsterdam Servers**: 11 (1 DC, 2 FS, 1 NMS, 1 WSUS, 2 DB, 2 WEB, 2 APP)

---

## Global Server Summary

### By Server Type
- **Domain Controllers**: 5 (distributed across all sites)
- **File Servers**: 10 (2 per site)
- **Network Management**: 5 (1 per site)
- **WSUS Servers**: 3 (Americas at HQ, Europe at AMS, Asia-Pacific at NAG)
- **Database Servers**: 12 (2 per site, 4 at Malibu)
- **Web Servers**: 4 (2 at HQ, 2 at AMS)
- **Application Servers**: 6 (2 at HQ, 2 at Malibu, 2 at AMS)

**Total Server Count**: 48 servers

### By Operating System
- **Windows Server 2019**: 27 servers (Domain Controllers, File Servers, Database Servers)
- **Windows Server 2022**: 16 servers (Network Management, WSUS, Web, Application)
- **Windows Server 2025**: 5 servers (Malibu advanced infrastructure)

### By Dell PowerEdge Model
- **R640**: 5 (Domain Controllers)
- **R740xd**: 10 (File Servers - high-capacity storage)
- **R650**: 16 (Network Management, WSUS, Web, Application - standard compute)
- **R660**: 3 (Malibu Server 2025 infrastructure)
- **R750**: 12 (Database Servers - high-performance)
- **R760**: 2 (Malibu development databases)

---

## Regional Distribution

### Americas (3 sites, 30 servers)
- **HQ (New York)**: 15 servers + Regional WSUS
- **Dallas**: 6 servers
- **Malibu**: 9 servers

### Europe (1 site, 11 servers)
- **Amsterdam**: 11 servers + Regional WSUS

### Asia-Pacific (1 site, 7 servers)
- **Nagasaki**: 7 servers + Regional WSUS

---

## Infrastructure Highlights

### High Availability Features
- **Dual File Servers**: Each site has 2 file servers for redundancy
- **Database Redundancy**: All sites have at least 2 database servers
- **Web/App Tiers**: HQ and Amsterdam have full 3-tier architecture (Web/App/DB)
- **Multiple Domain Controllers**: 5 DCs distributed globally for AD resilience

### Patch Management Strategy
- **3 WSUS Servers**: Continental distribution reduces WAN bandwidth for updates
  - HQ-WSU-01: Serves Americas (HQ, Dallas, Malibu)
  - AMS-WSU-01: Serves Europe (Amsterdam)
  - NAG-WSU-01: Serves Asia-Pacific (Nagasaki)

### Network Management
- **5 NMS Servers**: One per site for localized monitoring and management
- Enables site-specific network monitoring without cross-WAN dependencies

### Special Considerations
- **Malibu Development Environment**: 
  - Advanced Server 2025 infrastructure
  - 4 database servers (2 production, 2 development)
  - 2 dedicated application servers for Tony Stark's projects
  - Latest PowerEdge R660/R760 hardware

---

## Hardware Specifications Reference

### Dell PowerEdge Models Used

#### R640 (1U Rack Server - Domain Controllers)
- **Form Factor**: 1U
- **Use Case**: Domain Controllers
- **Features**: Compact, efficient, ideal for AD DS workloads

#### R740xd (2U Rack Server - File Servers)
- **Form Factor**: 2U
- **Use Case**: File Servers
- **Features**: High storage density (up to 32 drives), ideal for file services

#### R650 (1U Rack Server - General Purpose)
- **Form Factor**: 1U
- **Use Case**: Network Management, WSUS, Web, Application Servers
- **Features**: 3rd Gen Intel Xeon Scalable, versatile workload support

#### R660 (1U Rack Server - Next Generation)
- **Form Factor**: 1U
- **Use Case**: Malibu Server 2025 infrastructure
- **Features**: Latest generation, enhanced performance and efficiency

#### R750 (2U Rack Server - Database Servers)
- **Form Factor**: 2U
- **Use Case**: Database Servers
- **Features**: High-performance computing, ideal for SQL Server workloads

#### R760 (2U Rack Server - Next Generation Databases)
- **Form Factor**: 2U
- **Use Case**: Malibu development databases
- **Features**: Latest generation, maximum performance for development workloads

---

## Workstation Summary

**Total Workstations**: 90 (WS-001 through WS-090)

### By Site
- **HQ**: 35 workstations (WS-001 to WS-035)
- **Dallas**: 20 workstations (WS-036 to WS-055)
- **Malibu**: 5 workstations (WS-056 to WS-060)
- **Nagasaki**: 15 workstations (WS-061 to WS-075)
- **Amsterdam**: 15 workstations (WS-076 to WS-090)

### By Department Type
- **HR**: 5 (HQ only)
- **Legal**: 5 (HQ only)
- **Gov-Liaison**: 5 (HQ only)
- **Engineering**: 25 (distributed across HQ, Dallas, Nagasaki, Amsterdam)
- **Engineering Development**: 25 (distributed across HQ, Dallas, Nagasaki, Amsterdam)
- **QA**: 20 (distributed across HQ, Dallas, Nagasaki, Amsterdam)
- **CAD**: 10 (HQ and Dallas only)
- **Development**: 5 (Malibu only)

---

## Deployment Notes

### Prerequisite Steps
1. Ensure all OUs exist (created via `structure.json` and `generate_structure.ps1`)
2. Verify network connectivity to all sites
3. Confirm Dell hardware has been physically installed and connected
4. Validate MAC addresses match physical hardware labels

### Deployment Command
```powershell
.\ad_deploy.ps1 -ExerciseName "CHILLED_ROCKET" -ExercisesRoot ".\EXERCISES"
```

### Post-Deployment Verification
1. Verify all 48 servers appear in correct OUs
2. Check computer account descriptions include hardware details
3. Confirm domain controllers have replicated successfully
4. Validate WSUS servers can reach their respective regional clients
5. Test file server accessibility from workstations in same site
6. Verify application/web server tiers at HQ and Amsterdam

---

## Future Considerations

### Scalability
- Infrastructure supports adding additional regional file servers
- WSUS architecture allows for additional continental distribution if needed
- Database server pairs can be expanded for high-availability clustering

### Disaster Recovery
- Consider geographic pairing for DR (HQ↔Dallas, Amsterdam↔Nagasaki)
- File server replication between site pairs
- Database mirroring or Always-On availability groups

### Monitoring
- NMS servers at each site ready for deployment of monitoring solutions
- Consider centralized logging aggregation at HQ
- Implement cross-site health monitoring dashboards

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Author**: Stark Industries IT Operations  
**Classification**: Internal Use Only

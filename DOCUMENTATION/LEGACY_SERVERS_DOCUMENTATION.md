# CHILLED_ROCKET - Legacy Servers Documentation

## Purpose of Legacy Systems

The CHILLED_ROCKET exercise includes **28 legacy servers** (from the original configuration) running older Windows Server operating systems. These systems provide:

1. **Diverse Attack Surfaces:** Different OS versions with varying security postures
2. **Realistic Environment:** Reflects actual enterprise environments with legacy systems
3. **Security Training:** Practice identifying and securing vulnerable systems
4. **Patch Management:** Test update strategies for end-of-life systems
5. **Compensating Controls:** Learn to secure systems that can't be upgraded

---

## Legacy Server Inventory

### Total Legacy Servers: 28 (77.8% of all servers)

## Windows Server 2008 R2 (2 servers) - **END OF LIFE**

| VM ID | Hostname | Site | Type | Hardware | Status |
|-------|----------|------|------|----------|--------|
| **5026** | STK-DC-08 | Dallas | Domain Controller | PowerEdge R610 | **CRITICAL - EOL** |
| **5027** | STK-DC-09 | Dallas | Domain Controller | PowerEdge R610 | **CRITICAL - EOL** |

- **Released:** 2009
- **EOL Date:** January 14, 2020
- **Security:** No longer receives updates (except ESU)
- **Risk Level:** CRITICAL

**Attack Surface:**
- Known unpatched vulnerabilities (1000+ CVEs)
- SMBv1 enabled by default
- Weak cryptography (RC4, 3DES)
- No modern security features
- Missing Windows Defender updates
- No support for modern authentication

**Training Scenarios:**
- Exploit known CVEs (EternalBlue MS17-010, BlueKeep CVE-2019-0708)
- Privilege escalation attacks
- Lateral movement from compromised legacy DCs
- Golden Ticket attacks on vulnerable DCs
- Network segmentation testing

---

## Windows Server 2012 R2 (19 servers) - Extended Support Ended

### Domain Controllers (3 servers)
| VM ID | Hostname | Site | Hardware |
|-------|----------|------|----------|
| **5001** | STK-DC-01 | HQ | PowerEdge R720 |
| **5020** | STK-DC-02 | HQ | PowerEdge R720 |
| **5021** | STK-DC-03 | HQ | PowerEdge R720 |

### Exchange Servers (14 servers)
| VM ID | Hostname | Site | Hardware |
|-------|----------|------|----------|
| **5006** | HQ-EX-01 | HQ | PowerEdge R720 |
| **5007** | HQ-EX-02 | HQ | PowerEdge R720 |
| **5008** | HQ-EX-03 | HQ | PowerEdge R720 |
| **5009** | DL-EX-01 | Dallas | PowerEdge R720 |
| **5010** | DL-EX-02 | Dallas | PowerEdge R720 |
| **5011** | DL-EX-03 | Dallas | PowerEdge R720 |
| **5012** | AM-EX-01 | Amsterdam | PowerEdge R720 |
| **5013** | AM-EX-02 | Amsterdam | PowerEdge R720 |
| **5014** | AM-EX-03 | Amsterdam | PowerEdge R720 |
| **5015** | ML-EX-01 | Malibu | PowerEdge R720 |
| **5016** | ML-EX-02 | Malibu | PowerEdge R720 |
| **5017** | NG-EX-01 | Nagasaki | PowerEdge R720 |
| **5018** | NG-EX-02 | Nagasaki | PowerEdge R720 |
| **5019** | NG-EX-03 | Nagasaki | PowerEdge R720 |

### Database Servers (2 servers)
| VM ID | Hostname | Site | Hardware |
|-------|----------|------|----------|
| **5004** | HQ-SQL-01 | HQ | PowerEdge R720 |
| **5005** | HQ-SQL-02 | HQ | PowerEdge R720 |

- **Released:** 2013
- **Mainstream Support Ended:** October 9, 2018
- **Extended Support Ended:** October 10, 2023
- **Security:** Extended support ended, ESU may be available
- **Risk Level:** HIGH
- **Hardware:** Dell PowerEdge R720 (12th generation, 2012-2014)

**Attack Surface:**
- Limited security updates (500+ known CVEs)
- Legacy authentication protocols (NTLM, weak Kerberos)
- Older .NET framework versions
- Missing modern hardening features
- PowerShell 4.0 (vulnerable to various attacks)
- Weak TLS/SSL configurations by default
- Exchange 2013 on 2012 R2 (multiple vulnerabilities)

**Training Scenarios:**
- Exchange ProxyLogon/ProxyShell exploitation
- SQL Server exploitation (xp_cmdshell, linked servers)
- SMB relay attacks
- Credential harvesting from legacy DCs
- NTLM relay attacks
- Kerberoasting on legacy domains
- Pass-the-Hash attacks

---

## Windows Server 2016 (7 servers) - Mainstream Support Ended

### Domain Controllers - All in Nagasaki & Amsterdam
| VM ID | Hostname | Site | Hardware |
|-------|----------|------|----------|
| **5030** | STK-DC-12 | Nagasaki | PowerEdge R730 |
| **5031** | STK-DC-13 | Nagasaki | PowerEdge R730 |
| **5032** | STK-DC-14 | Nagasaki | PowerEdge R730 |
| **5033** | STK-DC-15 | Amsterdam | PowerEdge R730 |
| **5034** | STK-DC-16 | Amsterdam | PowerEdge R730 |
| **5035** | STK-DC-17 | Amsterdam | PowerEdge R730 |
| **5036** | STK-DC-18 | Amsterdam | PowerEdge R730 |

- **Released:** 2016
- **Mainstream Support Ended:** January 11, 2022
- **Extended Support Ends:** January 12, 2027
- **Security:** Still receives security updates (in extended support)
- **Risk Level:** MEDIUM
- **Hardware:** Dell PowerEdge R730 (13th generation, 2014-2017)

**Attack Surface:**
- Some missing modern security features (100+ known CVEs)
- Legacy protocol support still enabled
- Known vulnerabilities in older builds
- Limited AI/ML security protections
- Weaker Credential Guard implementation

**Training Scenarios:**
- Zerologon (CVE-2020-1472) exploitation
- PrintNightmare attacks
- PetitPotam relay attacks
- Privilege escalation via known CVEs
- Pass-the-hash attacks
- DCSync attacks

---

## Hardware Platform Details

### Dell PowerEdge R610 (11th Gen - 2009-2013)
**Used for:** Windows Server 2008 R2 Domain Controllers  
**Quantity:** 2 servers (STK-DC-08, STK-DC-09)  
**Specifications:**
- Processor: Intel Xeon 5500/5600 series
- Memory: Up to 192 GB DDR3
- Form Factor: 1U rackmount
- Status: **End of Service Life (EOSL)**

**Security Concerns:**
- No firmware updates available
- Older BIOS/UEFI versions with known vulnerabilities
- Missing hardware security features (no TPM 2.0)
- Potential hardware-level vulnerabilities (Spectre/Meltdown limited mitigation)
- No secure boot support

---

### Dell PowerEdge R720 (12th Gen - 2012-2014)
**Used for:** Windows Server 2012 R2 systems  
**Quantity:** 19 servers (DCs, Exchange, SQL)  
**Specifications:**
- Processor: Intel Xeon E5-2600 series
- Memory: Up to 768 GB DDR3
- Form Factor: 2U rackmount
- Status: **End of Service Life (EOSL)**

**Security Concerns:**
- Limited firmware updates
- Missing newer CPU security features
- Older RAID controllers with potential vulnerabilities
- TPM 1.2 only (not 2.0)
- Limited Spectre/Meltdown mitigations

---

### Dell PowerEdge R730 (13th Gen - 2014-2017)
**Used for:** Windows Server 2016 Domain Controllers  
**Quantity:** 7 servers (All Nagasaki & Amsterdam DCs)  
**Specifications:**
- Processor: Intel Xeon E5-2600 v3/v4 series
- Memory: Up to 768 GB DDR4
- Form Factor: 2U rackmount
- Status: Extended support available

**Security Features:**
- TPM 2.0 available
- Secure Boot support
- Better Spectre/Meltdown mitigations
- iDRAC 8 with encryption
- Better BIOS security

---

## Geographic Distribution of Legacy Servers

### Americas (cdx-pve-01) - 16 legacy servers
**HQ (12 servers):**
- 3 x Domain Controllers (2012 R2) - STK-DC-01, STK-DC-02, STK-DC-03
- 3 x Exchange Servers (2012 R2) - HQ-EX-01, HQ-EX-02, HQ-EX-03
- 2 x Database Servers (2012 R2) - HQ-SQL-01, HQ-SQL-02
- 2 x File Servers (2019) - **MODERN** (not legacy)

**Dallas (5 servers):**
- 2 x Domain Controllers (2008 R2) - STK-DC-08, STK-DC-09 **CRITICAL - EOL**
- 3 x Exchange Servers (2012 R2) - DL-EX-01, DL-EX-02, DL-EX-03
- 2 x Domain Controllers (2019) - **MODERN** (not legacy)

**Malibu (2 servers):**
- 2 x Exchange Servers (2012 R2) - ML-EX-01, ML-EX-02
- 3 x Domain Controllers (2019) - **MODERN** (not legacy)

### Europe-Africa (cdx-pve-02) - 7 legacy servers
**Amsterdam (7 servers):**
- 4 x Domain Controllers (2016) - STK-DC-15, STK-DC-16, STK-DC-17, STK-DC-18
- 3 x Exchange Servers (2012 R2) - AM-EX-01, AM-EX-02, AM-EX-03

### Asia-Pacific (cdx-pve-03) - 6 legacy servers
**Nagasaki (6 servers):**
- 3 x Domain Controllers (2016) - STK-DC-12, STK-DC-13, STK-DC-14
- 3 x Exchange Servers (2012 R2) - NG-EX-01, NG-EX-02, NG-EX-03

---

## Critical Infrastructure at Risk

### Domain Controllers (12 total, 10 legacy)
**CRITICAL - EOL (2 servers):**
- STK-DC-08, STK-DC-09 (Dallas) - Windows Server 2008 R2

**HIGH RISK (3 servers):**
- STK-DC-01, STK-DC-02, STK-DC-03 (HQ) - Windows Server 2012 R2

**MEDIUM RISK (7 servers):**
- STK-DC-12, STK-DC-13, STK-DC-14 (Nagasaki) - Windows Server 2016
- STK-DC-15, STK-DC-16, STK-DC-17, STK-DC-18 (Amsterdam) - Windows Server 2016

**Modern (6 servers):**
- STK-DC-04 (HQ), STK-DC-05/06/07 (Malibu), STK-DC-10/11 (Dallas) - Windows Server 2019

### Exchange Servers (14 total, ALL legacy)
**All running Windows Server 2012 R2 (HIGH RISK):**
- HQ: HQ-EX-01, HQ-EX-02, HQ-EX-03
- Dallas: DL-EX-01, DL-EX-02, DL-EX-03
- Malibu: ML-EX-01, ML-EX-02
- Nagasaki: NG-EX-01, NG-EX-02, NG-EX-03
- Amsterdam: AM-EX-01, AM-EX-02, AM-EX-03

**Note:** ALL Exchange servers are on legacy OS - **immediate upgrade path required**

### Database Servers (2 total, ALL legacy)
**All running Windows Server 2012 R2 (HIGH RISK):**
- HQ-SQL-01, HQ-SQL-02 (HQ)

---

## Security Posture Analysis

### Attack Surface Comparison

| OS Version | Servers | Unpatched CVEs | SMBv1 | Modern Auth | Defender | Risk Level |
|------------|---------|----------------|-------|-------------|----------|------------|
| **2008 R2** | 2 (5.6%) | 1000+ | Yes (default) | Limited | No | **CRITICAL** |
| **2012 R2** | 19 (52.8%) | 500+ | Yes | Partial | Limited | **HIGH** |
| **2016** | 7 (19.4%) | 100+ | Optional | Yes | Yes | MEDIUM |
| **2019** | 8 (22.2%) | <50 | No | Yes | Advanced | LOW |

**Critical Finding:** 77.8% of all servers are running legacy operating systems!

---

## Deployment Configuration

### Template Requirements

**Legacy OS Templates (3 required):**
- **Template 2004:** Windows Server 2016 (7 servers)
- **Template 2006:** Windows Server 2012 R2 (19 servers)
- **Template 2008:** Windows Server 2008 R2 (2 servers)

**Modern OS Templates:**
- **Template 2003:** Windows Server 2019 (8 servers)

### Clone Commands by OS

```bash
# Windows Server 2008 R2 (PowerEdge R610) - CRITICAL EOL
qm clone 2008 5026 --name STK-DC-08 --full 0 --target cdx-pve-01 --storage raid
qm set 5026 --net0 virtio=<MAC>,bridge=stk118,firewall=1
qm clone 2008 5027 --name STK-DC-09 --full 0 --target cdx-pve-01 --storage raid
qm set 5027 --net0 virtio=<MAC>,bridge=stk118,firewall=1

# Windows Server 2012 R2 (PowerEdge R720) - HIGH RISK
# Domain Controllers
qm clone 2006 5001 --name STK-DC-01 --full 0 --target cdx-pve-01 --storage raid
qm clone 2006 5020 --name STK-DC-02 --full 0 --target cdx-pve-01 --storage raid
qm clone 2006 5021 --name STK-DC-03 --full 0 --target cdx-pve-01 --storage raid

# Exchange Servers (14 total)
qm clone 2006 5006 --name HQ-EX-01 --full 0 --target cdx-pve-01 --storage raid
qm clone 2006 5007 --name HQ-EX-02 --full 0 --target cdx-pve-01 --storage raid
qm clone 2006 5008 --name HQ-EX-03 --full 0 --target cdx-pve-01 --storage raid
# ... (repeat for all Exchange servers)

# Database Servers
qm clone 2006 5004 --name HQ-SQL-01 --full 0 --target cdx-pve-01 --storage raid
qm clone 2006 5005 --name HQ-SQL-02 --full 0 --target cdx-pve-01 --storage raid

# Windows Server 2016 (PowerEdge R730) - MEDIUM RISK
# Nagasaki Domain Controllers
qm clone 2004 5030 --name STK-DC-12 --full 0 --target cdx-pve-03 --storage raid
qm clone 2004 5031 --name STK-DC-13 --full 0 --target cdx-pve-03 --storage raid
qm clone 2004 5032 --name STK-DC-14 --full 0 --target cdx-pve-03 --storage raid

# Amsterdam Domain Controllers
qm clone 2004 5033 --name STK-DC-15 --full 0 --target cdx-pve-02 --storage raid
qm clone 2004 5034 --name STK-DC-16 --full 0 --target cdx-pve-02 --storage raid
qm clone 2004 5035 --name STK-DC-17 --full 0 --target cdx-pve-02 --storage raid
qm clone 2004 5036 --name STK-DC-18 --full 0 --target cdx-pve-02 --storage raid
```

---

## Security Recommendations

### 1. Immediate Actions (Priority 1)

**EOL Domain Controllers (CRITICAL):**
- **STK-DC-08, STK-DC-09 (2008 R2):** Isolate immediately
- Air-gap from production if possible
- No direct internet connectivity
- Enhanced monitoring with SIEM
- Automated isolation on suspicious activity
- Plan immediate replacement

**Action Items:**
```
1. Deploy new 2019/2022 DCs in Dallas
2. Transfer FSMO roles to modern DCs
3. Test domain functionality
4. Demote STK-DC-08 and STK-DC-09
5. Decommission within 30 days
```

### 2. Short-Term Actions (Priority 2 - 90 days)

**All Exchange Servers (2012 R2 - HIGH RISK):**
- All 14 Exchange servers are vulnerable
- Plan migration to Exchange 2019/Office 365
- Apply all available CUs and patches
- Enhanced logging and monitoring
- Email filtering at perimeter

**2012 R2 Domain Controllers:**
- STK-DC-01, STK-DC-02, STK-DC-03 at HQ
- Plan upgrade to 2019/2022
- Test new DCs in parallel
- Gradual migration plan

**Database Servers:**
- HQ-SQL-01, HQ-SQL-02 require immediate patching
- Plan migration to SQL Server 2019/2022
- Test application compatibility

### 3. Medium-Term Actions (Priority 3 - 6-12 months)

**2016 Domain Controllers:**
- 7 DCs in Nagasaki and Amsterdam
- Still in extended support until 2027
- Plan upgrade path to 2022/2025
- Not immediately critical but should be planned

### 4. Compensating Controls

**For All Legacy Systems:**

**Network Segmentation:**
- Separate VLAN for legacy systems
- Strict firewall rules
- No direct internet access
- Limited lateral movement paths

**Monitoring:**
- Enhanced SIEM alerts for legacy systems
- File Integrity Monitoring (FIM)
- Process monitoring
- Network traffic analysis
- Assume breach mentality

**Access Control:**
- Just-In-Time (JIT) administrative access
- LAPS for local admin passwords
- MFA for all access to legacy systems
- Privileged Access Workstations (PAW)

**Hardening:**
- Disable SMBv1 at network level
- Enforce strong authentication
- Remove unnecessary services
- Application whitelisting
- Regular vulnerability scanning

---

## Training Scenarios

### Scenario 1: Exploiting EOL Domain Controllers
**Target:** STK-DC-08, STK-DC-09 (Windows Server 2008 R2)  
**Objective:** Demonstrate critical risk of EOL domain controllers  
**Skills:**
- EternalBlue (MS17-010) exploitation
- BlueKeep (CVE-2019-0708) exploitation
- Domain admin compromise
- Golden Ticket creation
- DCSync attacks
- Lateral movement to other DCs

### Scenario 2: Exchange Server Compromise
**Target:** All 14 Exchange servers (Windows Server 2012 R2)  
**Objective:** Exploit legacy Exchange vulnerabilities  
**Skills:**
- ProxyLogon/ProxyShell exploitation
- Email harvesting
- Credential dumping from Exchange
- Privilege escalation
- Lateral movement to DCs

### Scenario 3: Legacy Domain Attacks
**Target:** All 2012 R2 Domain Controllers  
**Objective:** Kerberos and NTLM attacks  
**Skills:**
- Kerberoasting
- AS-REP Roasting
- Pass-the-Hash
- Pass-the-Ticket
- Golden/Silver Ticket creation
- NTLM relay attacks

### Scenario 4: Database Exploitation
**Target:** HQ-SQL-01, HQ-SQL-02 (Windows Server 2012 R2)  
**Objective:** SQL Server attacks  
**Skills:**
- SQL injection
- xp_cmdshell exploitation
- Linked server abuse
- Credential harvesting
- Privilege escalation to domain admin

### Scenario 5: Defense Exercise
**Target:** All legacy systems  
**Objective:** Implement comprehensive defense  
**Skills:**
- Network segmentation design
- SIEM rule creation
- Firewall policy implementation
- Incident response procedures
- Compensating control deployment

---

## Migration Planning

### Recommended Upgrade Path

**Phase 1 - Immediate (30 days):**
- STK-DC-08, STK-DC-09 (2008 R2) → Decommission after deploying new 2019/2022 DCs
- **Reason:** EOL, critical security risk, vulnerable DCs

**Phase 2 - Short-term (90 days):**
- All 14 Exchange servers (2012 R2) → Exchange 2019 or Office 365
- **Reason:** Multiple critical vulnerabilities, high-value target

**Phase 3 - Medium-term (6 months):**
- STK-DC-01, STK-DC-02, STK-DC-03 (2012 R2) → Windows Server 2022
- HQ-SQL-01, HQ-SQL-02 (2012 R2) → SQL Server 2019/2022
- **Reason:** Extended support ended, high risk

**Phase 4 - Long-term (12-18 months):**
- All 2016 Domain Controllers → Windows Server 2025
- **Reason:** Plan for extended support end (2027)

---

## Summary Statistics

### Total Infrastructure: 36 Servers + 295 Workstations = 331 VMs

**Server Distribution:**
- Modern (2019): 8 servers (22.2%)
- **Legacy Total: 28 servers (77.8%)**
  - Windows Server 2016: 7 servers (19.4%) - Medium risk
  - Windows Server 2012 R2: 19 servers (52.8%) - High risk
  - Windows Server 2008 R2: 2 servers (5.6%) - **CRITICAL - EOL**

**Critical Infrastructure Risk:**
- **10 of 12 Domain Controllers** are legacy (83.3%)
- **ALL 14 Exchange Servers** are legacy (100%)
- **ALL 2 Database Servers** are legacy (100%)
- **2 Domain Controllers are EOL** (CRITICAL)

**Risk Distribution:**
- Critical Risk (EOL): 2 servers (5.6%) - **Immediate action required**
- High Risk (2012 R2): 19 servers (52.8%) - **Short-term action required**
- Medium Risk (2016): 7 servers (19.4%) - Plan for future upgrade
- Low Risk (2019): 8 servers (22.2%)

---

**Last Updated:** 2025-11-24  
**Configuration Version:** 2.4 (Original Legacy Servers)  
**Framework:** CDX-E v2.0  
**Exercise:** CHILLED_ROCKET  
**Source:** Based on actual original computers.json configuration

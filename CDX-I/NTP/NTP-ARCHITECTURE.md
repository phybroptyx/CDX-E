# CDX-I NTP Infrastructure Architecture

**Date:** December 10, 2024  
**Version:** 1.0  
**Stack Name:** cdx-ntp

---

## Overview

Geographic distribution of NTP services across CDX-I Internet infrastructure to provide accurate time synchronization for the CHILLED_ROCKET exercise environment.

---

## Architecture Design

### Stratum Hierarchy

```
Stratum 0 (External Reference - Public Internet)
├── pool.ntp.org
├── time.nist.gov
└── time.windows.com

Stratum 1 (Simulated - CDX-I Tier-0)
└── 103.140.210.1 (Tier-0 router - external reference simulation)

Stratum 2 (CDX-I Regional NTP Servers)
├── Americas
│   ├── 192.5.5.100 (EQIX4 Seattle)
│   └── 198.41.0.100 (EQIX5 Toronto)
├── Europe
│   ├── 46.244.164.88 (EQIX6 Frankfurt) ⭐ EXISTING
│   └── 37.74.100.100 (EQIX2 Amsterdam)
└── Asia-Pacific
    └── 202.12.27.101 (EQIX10 Seoul)

Stratum 3+ (Clients)
└── All Stark Industries systems, routers, servers, workstations
```

---

## Geographic Distribution

### Docker Host 1 (Americas) - 2 NTP Servers

**ntp-seattle (EQIX4):**
- Container: cdx-ntp-seattle
- IP: 192.5.5.100
- Network: eqix4
- Upstream: 103.140.210.1 (Tier-0 simulation)
- Role: Primary Americas NTP

**ntp-toronto (EQIX5):**
- Container: cdx-ntp-toronto
- IP: 198.41.0.100
- Network: eqix5
- Upstream: 103.140.210.1 (Tier-0 simulation)
- Role: Secondary Americas NTP

### Docker Host 2 (Europe) - 2 NTP Servers

**ntp-frankfurt (EQIX6):**
- Container: cdx-ntp-frankfurt
- IP: 46.244.164.88 ⭐ EXISTING DNS ENTRY
- Network: eqix6
- Upstream: 103.140.210.1 (Tier-0 simulation)
- Role: Primary Europe NTP

**ntp-amsterdam (EQIX2):**
- Container: cdx-ntp-amsterdam
- IP: 37.74.100.100
- Network: eqix2
- Upstream: 103.140.210.1 (Tier-0 simulation)
- Role: Secondary Europe NTP

### Docker Host 3 (Asia-Pacific) - 1 NTP Server

**ntp-seoul (EQIX10):**
- Container: cdx-ntp-seoul
- IP: 202.12.27.101
- Network: eqix10
- Upstream: 103.140.210.1 (Tier-0 simulation)
- Role: Primary Asia-Pacific NTP

---

## Technical Implementation

### Container Technology

**Base Image:** `cturra/ntp:latest` (Alpine-based chrony container)
- Lightweight (~10MB)
- Production-grade chrony implementation
- Supports Stratum 2 operation
- Easy configuration via environment variables

**Alternative:** Custom Alpine + chrony build if needed

---

## DNS Integration

### Existing Entry (Already Configured)

```
ntp.nist.gov.  IN  A  46.244.164.88
```

✅ This entry is already in your DNS zones and will continue to work.

### Additional DNS Entries (Recommended)

**Generic Regional Entries:**
```
# Americas
ntp.americas.cdx.lab.  IN  A  192.5.5.100
ntp.americas.cdx.lab.  IN  A  198.41.0.100

# Europe
ntp.europe.cdx.lab.    IN  A  46.244.164.88
ntp.europe.cdx.lab.    IN  A  37.74.100.100

# Asia-Pacific
ntp.apac.cdx.lab.      IN  A  202.12.27.101

# Global pool (anycast-style)
ntp.cdx.lab.           IN  A  192.5.5.100
ntp.cdx.lab.           IN  A  198.41.0.100
ntp.cdx.lab.           IN  A  46.244.164.88
ntp.cdx.lab.           IN  A  37.74.100.100
ntp.cdx.lab.           IN  A  202.12.27.101
```

**Site-Specific Entries:**
```
# EQIX zone-specific
ntp.eqix4.cdx.lab.     IN  A  192.5.5.100     # Seattle
ntp.eqix5.cdx.lab.     IN  A  198.41.0.100    # Toronto
ntp.eqix2.cdx.lab.     IN  A  37.74.100.100   # Amsterdam
ntp.eqix6.cdx.lab.     IN  A  46.244.164.88   # Frankfurt
ntp.eqix10.cdx.lab.    IN  A  202.12.27.101   # Seoul
```

---

## Client Configuration Strategy

### VyOS Routers (Already Configured)

**Current:**
```
set service ntp server '46.244.164.88'
```

**Enhanced (Recommended):**
```
# Primary regional server + backup
set service ntp server '46.244.164.88'      # Frankfurt (current)
set service ntp server '37.74.100.100'      # Amsterdam (backup)
```

**Americas Routers:**
```
set service ntp server '192.5.5.100'
set service ntp server '198.41.0.100'
```

**Asia-Pacific Routers:**
```
set service ntp server '202.12.27.101'
set service ntp server '46.244.164.88'      # Fallback to Europe
```

### Windows Domain Controllers

**Primary Site DCs:**
```powershell
# Configure regional NTP based on site location
w32tm /config /manualpeerlist:"192.5.5.100,198.41.0.100" /syncfromflags:manual /reliable:yes /update
net stop w32time && net start w32time
w32tm /resync
```

### DHCP Option 42 (NTP Servers)

Add to DHCP scopes in services.json:
```json
{
  "name": "HQ-Core-Services",
  "ntpServers": ["192.5.5.100", "198.41.0.100"]
}
```

---

## Network Requirements

### Firewall Rules (UDP 123)

**Allow Inbound:**
- From: 0.0.0.0/0
- To: Each NTP server IP
- Port: UDP/123
- Protocol: NTP

**Allow Outbound:**
- From: Each NTP server IP
- To: 103.140.210.1 (Tier-0 upstream)
- Port: UDP/123
- Protocol: NTP

### Routing Verification

All NTP server IPs must be routed via CDX-I Tier-1 gateways:
```
192.5.5.0/24     → EQIX4 Seattle
198.41.0.0/24    → EQIX5 Toronto
37.74.0.0/16     → EQIX2 Amsterdam
46.244.164.0/22  → EQIX6 Frankfurt
202.12.27.0/24   → EQIX10 Seoul
```

✅ All verified in CDX-I routing tables.

---

## Monitoring & Validation

### Health Checks

**From any client:**
```bash
# Query NTP server status
ntpdate -q 46.244.164.88
ntpdate -q 192.5.5.100
ntpdate -q 202.12.27.101

# Check stratum and offset
ntpq -p 46.244.164.88

# Chrony-specific
chronyc tracking
chronyc sources
```

**Expected Output:**
```
     remote           refid      st t when poll reach   delay   offset  jitter
==============================================================================
*103.140.210.1   .GPS.            1 u   64  128  377    0.123    0.045   0.012
```

### Container Health

```bash
# Check if chrony is running
docker exec cdx-ntp-frankfurt chronyc tracking

# View logs
docker logs cdx-ntp-frankfurt

# Check connectivity to upstream
docker exec cdx-ntp-frankfurt ping -c 3 103.140.210.1
```

---

## Failure Scenarios

### Single Server Failure

**Americas Primary Down (192.5.5.100):**
- Clients fail over to 198.41.0.100 (Toronto)
- No service interruption

**Europe Primary Down (46.244.164.88):**
- Critical: This is ntp.nist.gov
- Clients fail over to 37.74.100.100 (Amsterdam)
- VyOS routers need manual reconfiguration if single-server

**Asia-Pacific Down (202.12.27.101):**
- Clients fail over to Europe servers
- Higher latency but functional

### Regional Outage

**Docker Host 1 Failure:**
- Americas loses both NTP servers
- Clients fail over to Europe (46.244.164.88)
- Acceptable for exercise scenario

**Docker Host 2 Failure:**
- Europe loses both NTP servers
- Critical if Frankfurt (46.244.164.88) is down
- Clients fail over to Americas or Asia-Pacific

**Docker Host 3 Failure:**
- Asia-Pacific loses NTP
- Clients use Americas or Europe servers

---

## Training Scenarios

### Scenario 1: NTP Amplification Attack Simulation

**Target:** 46.244.164.88 (Frankfurt NTP)  
**Objective:** Detect and mitigate NTP amplification  
**Skills:**
- Traffic analysis (large NTP responses)
- Rate limiting implementation
- Source IP validation
- DDoS mitigation

### Scenario 2: Time Manipulation Attack

**Target:** Compromise NTP servers to cause time drift  
**Objective:** Blue Team detects time inconsistencies  
**Skills:**
- NTP authentication validation
- Time source verification
- Log correlation across time zones
- Incident response when time is unreliable

### Scenario 3: Stratum Poisoning

**Target:** Inject rogue NTP with Stratum 0/1 claim  
**Objective:** Blue Team identifies and blocks rogue source  
**Skills:**
- NTP peer validation
- Network traffic inspection
- Time source auditing
- Remediation procedures

---

## Benefits of Geographic Distribution

1. **Reduced Latency:** Clients query nearest regional server
2. **Redundancy:** Multiple servers per region
3. **Realistic Training:** Mirrors real-world NTP infrastructure
4. **Load Distribution:** Spreads queries across 5 servers
5. **Failure Tolerance:** Regional outages don't affect global time
6. **Attack Surface:** Multiple targets for Red Team scenarios

---

## Summary

**Total NTP Servers:** 5 (2 Americas + 2 Europe + 1 Asia-Pacific)  
**Docker Hosts:** 3  
**Stack Name:** cdx-ntp  
**Primary Service:** 46.244.164.88 (Frankfurt) - ntp.nist.gov  
**Stratum Level:** 2 (peers with simulated Stratum 1)  
**Protocol:** NTPv4 via chrony  
**Container Base:** Alpine Linux + chrony

**Deployment Time:** ~15 minutes per host  
**Resource Usage:** ~10MB RAM per container  
**Network Ports:** UDP/123 inbound/outbound

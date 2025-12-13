# CDX-E DNS Infrastructure - Geographic Distribution
## Version 3.0 - True Physical Geographic Separation

**Date:** December 10, 2024  
**Architecture:** Geographic distribution across 3 Docker hosts  
**Total Containers:** 30 (19 + 9 + 2)

---

## Executive Summary

This deployment creates a **geographically distributed** DNS infrastructure where each Docker host represents a different global region. Unlike the previous version where all containers were on one host with logical IP-based geography, this architecture provides **true physical separation** across three continents.

### Key Innovation

**Physical Geography Mapping:**
- **Docker Host 1** = **Americas** (EQIX4 Seattle, EQIX5 Toronto)
- **Docker Host 2** = **Europe** (EQIX1 London, EQIX6 Frankfurt)
- **Docker Host 3** = **Asia-Pacific** (EQIX10 Seoul)

This enables realistic training scenarios like:
- "Americas DNS infrastructure is down - how does global resolution work?"
- "European TLD secondaries can't reach Americas primaries - what breaks?"
- "Asia-Pacific root server is sole responder - latency impact?"

---

## Architecture Overview

### Docker Host 1: Americas (19 containers)

**Location Simulation:** EQIX4 Seattle, EQIX5 Toronto  
**Role:** Primary DNS infrastructure hub

**Root Servers (9):**
- a-root (198.41.0.4) - EQIX5 Toronto
- b-root (199.9.14.201) - EQIX4 Seattle
- c-root (192.33.4.12) - EQIX5 Toronto
- d-root (199.7.91.13) - EQIX5 Toronto
- e-root (192.203.230.10) - EQIX4 Seattle
- f-root (192.5.5.241) - EQIX4 Seattle
- g-root (192.112.36.4) - EQIX5 Toronto
- h-root (198.97.190.53) - EQIX5 Toronto
- l-root (199.7.83.42) - EQIX4 Seattle

**TLD Primary Servers (8):**
- com-tld-primary (192.5.5.50)
- net-tld-primary (192.5.5.51)
- org-tld-primary (192.5.5.52)
- edu-tld-primary (192.5.5.54)
- io-tld-primary (192.5.5.53)
- gov-tld-primary (192.5.5.55)
- mil-tld-primary (192.5.5.56)
- mrvl-tld-primary (192.5.5.57)

**TLD Secondary Servers (2):**
- com-tld-secondary (198.41.0.50)
- net-tld-secondary (198.41.0.51)

**Zone Files Included:**
- root-zone/db.root
- tld-zones/ (all 8 TLD zone files)

**Criticality:** HIGH - Hosts all TLD primary servers

---

### Docker Host 2: Europe (9 containers)

**Location Simulation:** EQIX1 London, EQIX6 Frankfurt  
**Role:** European DNS hub, TLD replication

**Root Servers (3):**
- i-root (192.36.148.17) - EQIX6 Frankfurt
- j-root (192.58.128.30) - EQIX1 London
- k-root (193.0.14.129) - EQIX1 London

**TLD Secondary Servers (6):**
- org-tld-secondary (198.41.0.52)
- edu-tld-secondary (198.41.0.54)
- io-tld-secondary (198.41.0.53)
- gov-tld-secondary (198.41.0.55)
- mil-tld-secondary (198.41.0.56)
- mrvl-tld-secondary (198.41.0.57)

**Zone Files Included:**
- root-zone/db.root (root zone only)

**Dependencies:** 
- TLD secondaries fetch zones from Host 1 primaries via AXFR
- Requires network connectivity to Host 1

**Criticality:** MEDIUM - Provides redundancy and European coverage

---

### Docker Host 3: Asia-Pacific (2 containers)

**Location Simulation:** EQIX10 Seoul  
**Role:** Asia-Pacific presence, monitoring/control

**Root Server (1):**
- m-root (202.12.27.33) - EQIX10 Seoul

**Control/Monitoring (1):**
- cdx-dns-control (monitoring placeholder)

**Zone Files Included:**
- root-zone/db.root

**Special Purpose:**
- M-root demonstrates anycast (same IP can be deployed at EQIX6)
- Control container monitors entire global infrastructure
- Lightweight deployment for Asia-Pacific presence

**Criticality:** LOW - Minimal infrastructure, primarily observational

---

## Geographic Distribution Benefits

### 1. Realistic Failure Scenarios

**Americas Outage (Host 1 down):**
- ✅ European roots (i,j,k) still serve root zone
- ✅ Asian root (m) still serves root zone
- ❌ TLD primaries unavailable
- ❌ TLD secondaries can't refresh zones
- **Training Value:** Demonstrates importance of secondary servers

**Europe Outage (Host 2 down):**
- ✅ Americas roots still function (9 of 13)
- ✅ TLD primaries unaffected
- ✅ European users can use Americas TLD secondaries (.com, .net)
- ⚠️ Other TLD secondaries (.org, .edu, etc.) unavailable
- **Training Value:** Shows DNS redundancy in action

**Asia-Pacific Outage (Host 3 down):**
- ✅ 12 of 13 root servers still operational
- ✅ All TLD services unaffected
- ⚠️ Monitoring/control lost
- **Training Value:** Minimal impact, demonstrates anycast backup

### 2. Geographic Query Patterns

**Realistic Latency Simulation:**
- CHILLED_ROCKET workstations in Malibu (Area 4) query Americas roots first
- European queries routed to Host 2 roots (lower latency)
- Asian queries hit Host 3 M-root

**Training Exercises:**
- Monitor query distribution across geographic regions
- Identify unusual query patterns (e.g., Malibu querying Seoul root)
- Practice latency-based DNS forensics

### 3. Zone Transfer Dependencies

**Americas → Europe:**
- Host 2 secondaries depend on Host 1 primaries
- AXFR traffic flows west-to-east across "Atlantic"
- Demonstrates primary/secondary relationship

**Detection Opportunities:**
- Monitor zone transfer traffic between hosts
- Identify failed transfers (network issues)
- Track zone serial number propagation delays

### 4. Cascade Failure Training

**Scenario: Americas Primary Unreachable**
- TLD primaries on Host 1 become unreachable
- European secondaries can't refresh zones
- Zones expire after 7 days (SOA expire value)
- Secondaries stop responding authoritatively

**Blue Team Challenge:**
- Detect increasing zone serial age on secondaries
- Identify network partition between hosts
- Implement emergency procedures

---

## Deployment Procedure

### Phase 1: Extract Archives by Region

**On Docker Host 1 (Americas):**
```bash
cd /opt/docker-stacks/cdx-dns/bind/
tar -xzf cdx-dns-bind-docker-1-GEOGRAPHIC.tar.gz
# Creates: host1/ directory with 19 container configs
```

**On Docker Host 2 (Europe):**
```bash
cd /opt/docker-stacks/cdx-dns/bind/
tar -xzf cdx-dns-bind-docker-2-GEOGRAPHIC.tar.gz
# Creates: host2/ directory with 9 container configs
```

**On Docker Host 3 (Asia-Pacific):**
```bash
cd /opt/docker-stacks/cdx-dns/bind/
tar -xzf cdx-dns-bind-docker-3-GEOGRAPHIC.tar.gz
# Creates: host3/ directory with 2 container configs
```

### Phase 2: Directory Structure Verification

**Expected structure on each host:**

```
Host 1:
/opt/docker-stacks/cdx-dns/bind/host1/
├── root-zone/
│   └── db.root
├── tld-zones/
│   ├── db.com, db.net, db.org, db.edu
│   └── db.io, db.gov, db.mil, db.mrvl
├── [9 root server directories]
├── [8 TLD primary directories]
└── [2 TLD secondary directories]

Host 2:
/opt/docker-stacks/cdx-dns/bind/host2/
├── root-zone/
│   └── db.root
├── [3 root server directories]
└── [6 TLD secondary directories]

Host 3:
/opt/docker-stacks/cdx-dns/bind/host3/
├── root-zone/
│   └── db.root
├── m-root/
└── cdx-dns-control/
```

### Phase 3: Docker Compose Configuration

You'll need to create docker-compose.yml files for each host. Here are region-specific examples:

**Docker Host 1 (Americas) - Sample docker-compose.yml:**

```yaml
version: '3.8'

services:
  # Americas Root Servers (9)
  a-root:
    image: ubuntu/bind9:latest
    container_name: cdx-dns-a-root
    hostname: a-root
    networks:
      cdx-i-core:
        ipv4_address: 198.41.0.4
    volumes:
      - ./host1/root-zone/db.root:/etc/bind/db.root:ro
      - ./host1/a-root/named.conf.local:/etc/bind/named.conf.local:ro
      - ./host1/a-root/named.conf.options:/etc/bind/named.conf.options:ro
      - ./host1/a-root/db.empty:/etc/bind/db.empty:ro
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    dns:
      - 127.0.0.1

  # ... (repeat for b,c,d,e,f,g,h,l roots)

  # TLD Primary Servers (8)
  com-tld-primary:
    image: ubuntu/bind9:latest
    container_name: cdx-dns-com-primary
    hostname: com-tld-primary
    networks:
      cdx-i-core:
        ipv4_address: 192.5.5.50
    volumes:
      - ./host1/tld-zones/db.com:/etc/bind/db.com:ro
      - ./host1/com-primary/named.conf.local:/etc/bind/named.conf.local:ro
      - ./host1/com-primary/named.conf.options:/etc/bind/named.conf.options:ro
      - ./host1/com-primary/db.empty:/etc/bind/db.empty:ro
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    dns:
      - 127.0.0.1

  # ... (repeat for other TLD primaries)

  # TLD Secondary Servers (2)
  com-tld-secondary:
    image: ubuntu/bind9:latest
    container_name: cdx-dns-com-secondary
    hostname: com-tld-secondary
    networks:
      cdx-i-core:
        ipv4_address: 198.41.0.50
    volumes:
      - ./host1/com-secondary/named.conf.local:/etc/bind/named.conf.local:ro
      - ./host1/com-secondary/named.conf.options:/etc/bind/named.conf.options:ro
      - ./host1/com-secondary/db.empty:/etc/bind/db.empty:ro
      - com-secondary-cache:/var/cache/bind
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    dns:
      - 127.0.0.1

  # ... (net-secondary)

volumes:
  com-secondary-cache:
  net-secondary-cache:

networks:
  cdx-i-core:
    driver: macvlan
    driver_opts:
      parent: eth1  # Adjust to your interface
    ipam:
      config:
        - subnet: 198.41.0.0/24
          gateway: 198.41.0.1
        - subnet: 192.5.5.0/24
          gateway: 192.5.5.1
        # ... (add all required subnets)
```

**Docker Host 2 (Europe) - Sample docker-compose.yml:**

```yaml
version: '3.8'

services:
  # European Root Servers (3)
  i-root:
    image: ubuntu/bind9:latest
    container_name: cdx-dns-i-root
    hostname: i-root
    networks:
      cdx-i-core:
        ipv4_address: 192.36.148.17
    volumes:
      - ./host2/root-zone/db.root:/etc/bind/db.root:ro
      - ./host2/i-root/named.conf.local:/etc/bind/named.conf.local:ro
      - ./host2/i-root/named.conf.options:/etc/bind/named.conf.options:ro
      - ./host2/i-root/db.empty:/etc/bind/db.empty:ro
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    dns:
      - 127.0.0.1

  # ... (j-root, k-root)

  # TLD Secondary Servers (6)
  org-tld-secondary:
    image: ubuntu/bind9:latest
    container_name: cdx-dns-org-secondary
    hostname: org-tld-secondary
    networks:
      cdx-i-core:
        ipv4_address: 198.41.0.52
    volumes:
      - ./host2/org-secondary/named.conf.local:/etc/bind/named.conf.local:ro
      - ./host2/org-secondary/named.conf.options:/etc/bind/named.conf.options:ro
      - ./host2/org-secondary/db.empty:/etc/bind/db.empty:ro
      - org-secondary-cache:/var/cache/bind
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    dns:
      - 127.0.0.1

  # ... (other secondaries)

volumes:
  org-secondary-cache:
  edu-secondary-cache:
  io-secondary-cache:
  gov-secondary-cache:
  mil-secondary-cache:
  mrvl-secondary-cache:

networks:
  cdx-i-core:
    driver: macvlan
    driver_opts:
      parent: eth1
    ipam:
      config:
        - subnet: 192.36.148.0/24
        - subnet: 192.58.128.0/24
        - subnet: 193.0.14.0/24
        - subnet: 198.41.0.0/24
```

**Docker Host 3 (Asia-Pacific) - Sample docker-compose.yml:**

```yaml
version: '3.8'

services:
  # Asian Root Server (1)
  m-root:
    image: ubuntu/bind9:latest
    container_name: cdx-dns-m-root
    hostname: m-root
    networks:
      cdx-i-core:
        ipv4_address: 202.12.27.33
    volumes:
      - ./host3/root-zone/db.root:/etc/bind/db.root:ro
      - ./host3/m-root/named.conf.local:/etc/bind/named.conf.local:ro
      - ./host3/m-root/named.conf.options:/etc/bind/named.conf.options:ro
      - ./host3/m-root/db.empty:/etc/bind/db.empty:ro
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    dns:
      - 127.0.0.1

  # Control/Monitoring Container (1)
  cdx-dns-control:
    image: alpine:latest
    container_name: cdx-dns-control
    hostname: cdx-dns-control
    command: /bin/sh -c "while true; do sleep 3600; done"
    networks:
      cdx-i-core:
        ipv4_address: 202.12.27.100
    restart: unless-stopped

networks:
  cdx-i-core:
    driver: macvlan
    driver_opts:
      parent: eth1
    ipam:
      config:
        - subnet: 202.12.27.0/24
```

### Phase 4: Set Permissions

**On all Docker hosts:**

```bash
cd /opt/docker-stacks/cdx-dns/bind/
sudo chown -R root:root host*/
sudo chmod -R 755 host*/
sudo chmod 644 host*/root-zone/* host*/tld-zones/* host*/*-root/* host*/*-primary/* host*/*-secondary/*
```

### Phase 5: Deploy Containers

**On each Docker host:**

```bash
cd /opt/docker-stacks/cdx-dns/bind/
docker compose up -d

# Verify
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## Verification & Testing

### Phase 1: Container Health (Per Host)

**On Docker Host 1:**
```bash
docker ps | grep cdx-dns | wc -l
# Should return: 19

# Check specific containers
docker exec cdx-dns-a-root rndc status
docker exec cdx-dns-com-primary rndc status
```

**On Docker Host 2:**
```bash
docker ps | grep cdx-dns | wc -l
# Should return: 9

docker exec cdx-dns-i-root rndc status
docker exec cdx-dns-org-secondary rndc status
```

**On Docker Host 3:**
```bash
docker ps | grep cdx-dns | wc -l
# Should return: 2

docker exec cdx-dns-m-root rndc status
```

### Phase 2: Root DNS Resolution

Test root servers from each region:

```bash
# Americas roots (from any CHILLED_ROCKET workstation)
dig @198.41.0.4 . NS        # a-root (Toronto)
dig @199.9.14.201 . NS      # b-root (Seattle)
dig @192.5.5.241 . NS       # f-root (Seattle)

# European roots
dig @192.36.148.17 . NS     # i-root (Frankfurt)
dig @192.58.128.30 . NS     # j-root (London)
dig @193.0.14.129 . NS      # k-root (London)

# Asian root
dig @202.12.27.33 . NS      # m-root (Seoul)
```

### Phase 3: TLD Resolution

Test TLD primaries (all on Host 1):

```bash
dig @192.5.5.50 com. NS
dig @192.5.5.51 net. NS
dig @192.5.5.52 org. NS
```

### Phase 4: Zone Transfer Verification

Verify Host 2 secondaries received zones from Host 1 primaries:

```bash
# On Docker Host 2
docker exec cdx-dns-org-secondary ls -la /var/cache/bind/
# Should see: db.org file

# Check zone serial matches primary
docker exec cdx-dns-org-secondary rndc status
docker exec cdx-dns-org-secondary cat /var/cache/bind/db.org | grep Serial

# Compare to primary (from Host 1)
# Serial should be: 2024121002
```

### Phase 5: Inter-Host Connectivity

Test that containers on different hosts can reach each other:

```bash
# From Host 2 container, ping Host 1 primary
docker exec cdx-dns-org-secondary ping -c 3 192.5.5.52

# Should succeed - proves inter-host routing works
```

### Phase 6: Website Resolution

Test website resolution through the full stack:

```bash
# Query root, get TLD referral
dig @198.41.0.4 google.com

# Query TLD primary
dig @192.5.5.50 google.com A
# Should return: 104.215.95.10

# Verify IP is reachable
ping -c 3 104.215.95.10
# Should route via EQIX4 Seattle
```

---

## Training Scenarios

### Scenario 1: Americas Outage

**Setup:**
```bash
# On Docker Host 1
docker compose down
```

**Expected Behavior:**
- ✅ European roots (i,j,k) still serve root zone
- ✅ Asian root (m) still serves root zone
- ❌ TLD primaries unavailable
- ⚠️ TLD secondaries on Host 2 can't refresh zones

**Blue Team Tasks:**
1. Detect that 9 of 13 root servers are unreachable
2. Identify TLD primary servers are down
3. Determine zone refresh will fail
4. Calculate time until secondaries expire (7 days from last refresh)
5. Monitor for DNS resolution failures

**Recovery:**
```bash
# On Docker Host 1
docker compose up -d
```

### Scenario 2: Transatlantic Network Partition

**Setup:**
```bash
# Block traffic between Host 1 and Host 2
# (Requires firewall rules or network manipulation)
```

**Expected Behavior:**
- ✅ All root servers operational (isolated)
- ✅ TLD primaries operational (Host 1)
- ⚠️ TLD secondaries on Host 2 can't transfer zones
- ⚠️ Zone serial numbers diverge

**Blue Team Tasks:**
1. Detect zone transfer failures
2. Monitor zone serial staleness
3. Identify network partition
4. Determine impact on European users
5. Calculate time to zone expiration

### Scenario 3: Europe Under Attack

**Setup:**
```bash
# Generate high query volume to Host 2 containers
# Simulate DDoS against European DNS infrastructure
```

**Expected Behavior:**
- ⚠️ European roots (i,j,k) slow to respond
- ⚠️ European secondaries overloaded
- ✅ Americas infrastructure unaffected
- ⚠️ European users experience degraded service

**Blue Team Tasks:**
1. Detect abnormal query rates to Host 2
2. Identify source of attack traffic
3. Monitor response times
4. Verify Americas infrastructure unaffected
5. Implement rate limiting or blocking

### Scenario 4: Anycast Demonstration

**Setup:**
```bash
# Deploy second M-root at EQIX6 Frankfurt (on Host 2)
# Both use IP 202.12.27.33 (anycast)
```

**Expected Behavior:**
- ✅ Queries to 202.12.27.33 route to nearest instance
- ✅ European queries hit Frankfurt M-root
- ✅ Asian queries hit Seoul M-root
- ✅ Load distribution and redundancy

**Blue Team Tasks:**
1. Monitor which M-root instance answers queries
2. Test failover (shut down one instance)
3. Observe BGP routing changes
4. Measure latency differences

---

## Geographic Failure Domains

### Critical Dependencies

**Americas (Host 1):**
- **Depends on:** Nothing (self-sufficient)
- **Provides to:** 
  - Host 2 TLD secondaries (zone transfers)
  - Global root DNS coverage (9 of 13 roots)
- **Failure Impact:** CRITICAL - TLD primaries lost, zone transfers stop

**Europe (Host 2):**
- **Depends on:** Host 1 TLD primaries (for zone transfers)
- **Provides to:**
  - European query coverage
  - TLD redundancy (6 secondaries)
- **Failure Impact:** MEDIUM - European roots lost, some TLD secondaries lost

**Asia-Pacific (Host 3):**
- **Depends on:** Nothing (observational)
- **Provides to:**
  - Asian query coverage
  - Monitoring/control functions
- **Failure Impact:** LOW - 1 root lost, monitoring lost

### Cascading Failure Scenarios

**Host 1 Failure → 24 hours:**
- Host 2 secondaries can't refresh zones
- Logs show failed zone transfer attempts
- Zones remain valid (7-day expiration)

**Host 1 Failure → 7 days:**
- Host 2 secondaries' zones expire
- Secondaries stop serving expired zones
- .org, .edu, .io, .gov, .mil, .mrvl resolution fails in Europe

**Host 1 + Host 2 Failure:**
- Only 1 of 13 root servers operational (m-root on Host 3)
- All TLD infrastructure lost
- Complete DNS resolution failure for websites

---

## Monitoring & Maintenance

### Container Health Monitoring

**Create monitoring script:**

```bash
#!/bin/bash
# /opt/cdx-dns-monitor.sh

REGION=$(hostname | grep -q 'host1' && echo "Americas" || (hostname | grep -q 'host2' && echo "Europe" || echo "Asia-Pacific"))

echo "[$REGION] DNS Container Health Check - $(date)"
echo "================================================"

for container in $(docker ps --filter "name=cdx-dns" --format '{{.Names}}'); do
    status=$(docker exec $container rndc status 2>&1 | grep -q "server is up" && echo "UP" || echo "DOWN")
    echo "$container: $status"
done

echo ""
echo "Zone Transfer Status (Secondaries only):"
for container in $(docker ps --filter "name=secondary" --format '{{.Names}}'); do
    docker exec $container tail -5 /var/log/syslog 2>/dev/null | grep -i "transfer of"
done
```

### Zone Serial Monitoring

**Track zone freshness:**

```bash
#!/bin/bash
# Check if secondaries are up to date

PRIMARY_SERIAL=$(docker exec cdx-dns-com-primary grep Serial /etc/bind/db.com | awk '{print $1}')
SECONDARY_SERIAL=$(docker exec cdx-dns-com-secondary grep Serial /var/cache/bind/db.com 2>/dev/null | awk '{print $1}')

if [ "$PRIMARY_SERIAL" != "$SECONDARY_SERIAL" ]; then
    echo "WARNING: Zone serial mismatch detected"
    echo "Primary: $PRIMARY_SERIAL, Secondary: $SECONDARY_SERIAL"
fi
```

### Inter-Host Connectivity Tests

**Verify network paths:**

```bash
#!/bin/bash
# Test connectivity from Host 2 to Host 1 primaries

for primary in 192.5.5.50 192.5.5.51 192.5.5.52 192.5.5.53 192.5.5.54 192.5.5.55 192.5.5.56 192.5.5.57; do
    if ping -c 1 -W 1 $primary >/dev/null 2>&1; then
        echo "✓ $primary reachable"
    else
        echo "✗ $primary UNREACHABLE"
    fi
done
```

---

## Troubleshooting by Region

### Americas (Host 1) Issues

**Problem:** TLD primary won't start
```bash
docker logs cdx-dns-com-primary
# Check for zone file errors
docker exec cdx-dns-com-primary named-checkzone com /etc/bind/db.com
```

**Problem:** Root server not responding
```bash
# Verify BIND is running
docker exec cdx-dns-a-root ps aux | grep named

# Check zone
docker exec cdx-dns-a-root named-checkzone . /etc/bind/db.root
```

### Europe (Host 2) Issues

**Problem:** Secondaries not receiving zones
```bash
# Check network connectivity to primaries
docker exec cdx-dns-org-secondary ping -c 3 192.5.5.52

# Check BIND logs for transfer errors
docker exec cdx-dns-org-secondary tail -f /var/log/syslog
```

**Problem:** Zone transfer denied
```bash
# Verify primary allows transfers
docker exec cdx-dns-org-primary grep allow-transfer /etc/bind/named.conf.local
# Should show: allow-transfer { any; };
```

### Asia-Pacific (Host 3) Issues

**Problem:** M-root isolated
```bash
# Test connectivity to other roots
docker exec cdx-dns-m-root ping -c 3 198.41.0.4

# Verify routing
ip route show
```

---

## Appendix A: Container Distribution Matrix

```
┌─────────────┬──────────────────────────┬───────┬────────┐
│ Docker Host │ Geographic Region        │ Roots │ TLDs   │
├─────────────┼──────────────────────────┼───────┼────────┤
│ Host 1      │ Americas (Seattle/Toronto│   9   │ 8P+2S  │
│ Host 2      │ Europe (London/Frankfurt)│   3   │ 6S     │
│ Host 3      │ Asia-Pacific (Seoul)     │   1   │ 0      │
└─────────────┴──────────────────────────┴───────┴────────┘

P = Primary, S = Secondary
Total: 13 Roots + 8 Primaries + 8 Secondaries = 29 DNS + 1 Control = 30
```

---

## Appendix B: IP Address Reference

**Root Servers by Host:**

Host 1 (Americas):
- 198.41.0.4, 192.33.4.12, 199.7.91.13, 192.112.36.4, 198.97.190.53 (Toronto)
- 199.9.14.201, 192.203.230.10, 192.5.5.241, 199.7.83.42 (Seattle)

Host 2 (Europe):
- 192.36.148.17 (Frankfurt)
- 192.58.128.30, 193.0.14.129 (London)

Host 3 (Asia):
- 202.12.27.33 (Seoul)

**TLD Servers by Host:**

Host 1 (Americas):
- Primaries: 192.5.5.50-57 (all 8)
- Secondaries: 198.41.0.50-51 (.com, .net)

Host 2 (Europe):
- Secondaries: 198.41.0.52-57 (.org, .edu, .io, .gov, .mil, .mrvl)

---

**This architecture provides true geographic separation for realistic DNS infrastructure training.**

**Deploy across three continents. Train for real-world scenarios. Master DNS forensics.**

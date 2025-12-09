# BIND9 Zone Files and Configuration Deployment Guide

**Date:** December 9, 2024  
**Environment:** CDX-I Internet Infrastructure  
**Purpose:** Deploy authoritative DNS configurations for root and TLD servers

---

## Overview

This guide covers deployment of BIND9 zone files and configuration files to the 25 DNS containers deployed across three Docker hosts.

### Files Included

#### Zone Files (7 files)
1. **db.root** - Root zone (.) with all 13 root servers and TLD delegations
2. **db.com** - .com TLD zone
3. **db.net** - .net TLD zone
4. **db.org** - .org TLD zone
5. **db.gov** - .gov TLD zone (US Government)
6. **db.mil** - .mil TLD zone (US Military)
7. **db.mrvl** - .mrvl TLD zone (Marvel Universe scenario)

#### Configuration Files (5 files)
1. **root-server-named.conf.local** - Configuration for all 13 root servers
2. **com-primary-named.conf.local** - .com primary TLD server
3. **com-secondary-named.conf.local** - .com secondary TLD server
4. **tld-servers-templates.conf.local** - Templates for all other TLD servers
5. **named.conf.options** - Common options for all DNS servers

---

## Deployment Architecture

### Root Servers (13 containers)
**Zone:** Root (.)  
**Zone File:** db.root  
**Configuration:** root-server-named.conf.local  
**Servers:**
- a.root-servers.net (EQIX5)
- b.root-servers.net (EQIX4)
- c.root-servers.net (EQIX5)
- d.root-servers.net (EQIX5)
- e.root-servers.net (EQIX4)
- f.root-servers.net (EQIX4)
- g.root-servers.net (EQIX5)
- h.root-servers.net (EQIX5)
- i.root-servers.net (EQIX6)
- j.root-servers.net (EQIX1)
- k.root-servers.net (EQIX1)
- l.root-servers.net (EQIX4)
- m.root-servers.net (EQIX6 + EQIX10)

### TLD Servers (12 containers)
**Zones:** com, net, org, gov, mil, mrvl  
**Zone Files:** db.com, db.net, db.org, db.gov, db.mil, db.mrvl  
**Configuration:** Individual named.conf.local per server

---

## Pre-Deployment Steps

### 1. Create Directory Structure on Each Docker Host

```bash
# On cdx-inet-docker-1
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/{root-zone,tld-zones}
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/{a,b,c,d,e,f,g,h,l}-root
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/com-{primary,secondary}
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/net-primary
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/org-primary
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/gov-{primary,secondary}
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/mil-{primary,secondary}
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/mrvl-{primary,secondary}

# On cdx-inet-docker-2
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/{root-zone,tld-zones}
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/{i,j,k,m}-root
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/net-secondary
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/org-secondary

# On cdx-inet-docker-3
sudo mkdir -p /opt/docker-stacks/cdx-dns/bind/{root-zone,m-root}
```

### 2. Set Proper Permissions

```bash
# On all Docker hosts
sudo chown -R root:bind /opt/docker-stacks/cdx-dns/bind
sudo chmod -R 755 /opt/docker-stacks/cdx-dns/bind
```

---

## Deployment Procedure

### Phase 1: Deploy Root Zone File (All Hosts)

The root zone file is identical on all root servers.

```bash
# On cdx-inet-docker-1
sudo cp db.root /opt/docker-stacks/cdx-dns/bind/root-zone/
sudo chmod 644 /opt/docker-stacks/cdx-dns/bind/root-zone/db.root

# Repeat for docker-2 and docker-3
```

### Phase 2: Deploy TLD Zone Files

#### On cdx-inet-docker-1:
```bash
cd /opt/docker-stacks/cdx-dns/bind/tld-zones/
sudo cp db.com db.net db.org db.gov db.mil db.mrvl .
sudo chmod 644 db.*
```

#### On cdx-inet-docker-2:
```bash
cd /opt/docker-stacks/cdx-dns/bind/tld-zones/
sudo cp db.net db.org .
sudo chmod 644 db.*
```

### Phase 3: Deploy named.conf.local Files

#### Root Servers (All 13):
```bash
# Example for a.root-servers.net
sudo cp root-server-named.conf.local \
    /opt/docker-stacks/cdx-dns/bind/a-root/named.conf.local

# Repeat for all root servers: b, c, d, e, f, g, h, i, j, k, l, m
```

#### TLD Servers:

```bash
# .com primary (docker-1)
sudo cp com-primary-named.conf.local \
    /opt/docker-stacks/cdx-dns/bind/com-primary/named.conf.local

# .com secondary (docker-1)
sudo cp com-secondary-named.conf.local \
    /opt/docker-stacks/cdx-dns/bind/com-secondary/named.conf.local

# For other TLD servers, extract appropriate sections from tld-servers-templates.conf.local
```

### Phase 4: Deploy named.conf.options

This file is the SAME for all DNS servers.

```bash
# On all Docker hosts, for each DNS container directory
sudo cp named.conf.options /opt/docker-stacks/cdx-dns/bind/{server-dir}/
```

### Phase 5: Create Empty Zone File for RFC1918

```bash
# On all Docker hosts
cat > /tmp/db.empty << 'EOF'
$TTL 86400
@   IN  SOA  localhost. root.localhost. (
                1       ; Serial
                3600    ; Refresh
                1800    ; Retry
                604800  ; Expire
                86400 ) ; Minimum TTL
@   IN  NS   localhost.
EOF

# Copy to each container's /etc/bind/
sudo cp /tmp/db.empty /opt/docker-stacks/cdx-dns/bind/a-root/
# Repeat for all containers
```

---

## Configuration File Mapping

### Root Servers - File Locations

Each root server needs:
- `/etc/bind/zones/db.root` (zone file)
- `/etc/bind/named.conf.local` (configuration)
- `/etc/bind/named.conf.options` (options)
- `/etc/bind/db.empty` (RFC1918 empty zones)

**Docker volume mounts in stack:**
```yaml
volumes:
  - ./bind/root-zone:/etc/bind/zones:ro
  - ./bind/a-root/named.conf.local:/etc/bind/named.conf.local:ro
```

### TLD Servers - File Locations

Each TLD server needs:
- `/etc/bind/zones/db.{tld}` (zone file - primary only)
- `/etc/bind/named.conf.local` (configuration)
- `/etc/bind/named.conf.options` (options)
- `/var/cache/bind/` (writable for secondary zones)

**Docker volume mounts for TLD servers:**
```yaml
volumes:
  - ./bind/tld-zones:/etc/bind/zones:ro
  - ./bind/com-primary/named.conf.local:/etc/bind/named.conf.local:ro
```

---

## Verification Steps

### 1. Check Zone File Syntax

```bash
# On Docker host, before container deployment
named-checkzone . /opt/docker-stacks/cdx-dns/bind/root-zone/db.root
named-checkzone com /opt/docker-stacks/cdx-dns/bind/tld-zones/db.com
named-checkzone net /opt/docker-stacks/cdx-dns/bind/tld-zones/db.net
# etc.
```

Expected output: `OK` for each zone

### 2. Check Configuration Syntax

```bash
# After containers are running
docker exec a.root-servers.net named-checkconf
docker exec com-tld-primary.cdx.lab named-checkconf
```

Expected output: No errors (silent success)

### 3. Test DNS Queries

#### Root Server Queries:
```bash
# Query root zone from A-Root
dig @198.41.0.4 . NS

# Expected: List of all 13 root servers

# Query for .com delegation
dig @198.41.0.4 com. NS

# Expected: com-tld-primary and com-tld-secondary
```

#### TLD Server Queries:
```bash
# Query .com TLD for nameservers
dig @192.5.5.50 com. NS

# Expected: com-tld-primary and com-tld-secondary

# Query .com for non-existent domain (should return NXDOMAIN)
dig @192.5.5.50 nonexistent.com A

# Expected: NXDOMAIN status
```

#### Full Resolution Path Test:
```bash
# Simulate full DNS resolution
# Step 1: Query root for .com delegation
dig @198.41.0.4 com. NS +norecurse

# Step 2: Query .com TLD (once you add authoritative servers)
# dig @192.5.5.50 microsoft.com NS +norecurse
```

### 4. Check Zone Transfers

```bash
# On primary server, check if secondary can transfer
docker exec com-tld-primary.cdx.lab tail -f /var/log/named/com-tld-xfers.log

# On secondary, trigger zone transfer
docker exec com-tld-secondary.cdx.lab rndc retransfer com

# Check secondary received the zone
docker exec com-tld-secondary.cdx.lab cat /var/cache/bind/db.com.slave
```

### 5. Monitor Query Logs

```bash
# Watch root server queries in real-time
docker exec a.root-servers.net tail -f /var/log/named/query.log

# Watch TLD server queries
docker exec com-tld-primary.cdx.lab tail -f /var/log/named/com-tld-queries.log
```

---

## Common Issues and Troubleshooting

### Issue 1: Zone File Syntax Errors

**Symptoms:** BIND fails to start, errors in logs about zone loading

**Resolution:**
```bash
# Check zone syntax
named-checkzone . /etc/bind/zones/db.root

# Common errors:
# - Missing trailing dots on FQDNs (e.g., "com" instead of "com.")
# - Invalid SOA serial number format
# - Mismatched parentheses in SOA record
```

### Issue 2: Permission Denied on Zone Files

**Symptoms:** BIND can't read zone files

**Resolution:**
```bash
# Fix ownership
sudo chown root:bind /opt/docker-stacks/cdx-dns/bind/root-zone/db.root

# Fix permissions
sudo chmod 644 /opt/docker-stacks/cdx-dns/bind/root-zone/db.root
```

### Issue 3: Secondary Can't Transfer Zone

**Symptoms:** Secondary shows empty zone or outdated data

**Resolution:**
```bash
# Check primary allows transfers
docker exec com-tld-primary.cdx.lab rndc status

# Check firewall rules (shouldn't be needed with MACVLAN)
# Manually trigger transfer on secondary
docker exec com-tld-secondary.cdx.lab rndc retransfer com

# Check logs
docker logs com-tld-secondary.cdx.lab
```

### Issue 4: Queries Return SERVFAIL

**Symptoms:** DNS queries fail with SERVFAIL status

**Resolution:**
```bash
# Check BIND is running
docker exec a.root-servers.net rndc status

# Check zone is loaded
docker exec a.root-servers.net rndc zonestatus .

# Check for config errors
docker exec a.root-servers.net named-checkconf

# Review logs
docker logs a.root-servers.net
```

---

## Adding New Domains to TLDs

### Example: Adding microsoft.com to .com TLD

1. **Edit db.com zone file:**
```bash
sudo nano /opt/docker-stacks/cdx-dns/bind/tld-zones/db.com
```

2. **Add delegation:**
```
microsoft.com.  IN  NS  ns1.microsoft.com.
microsoft.com.  IN  NS  ns2.microsoft.com.

; Glue records
ns1.microsoft.com.  IN  A  104.215.95.10
ns2.microsoft.com.  IN  A  52.164.206.10
```

3. **Increment SOA serial:**
```
2024120901  →  2024120902
```

4. **Reload zone:**
```bash
docker exec com-tld-primary.cdx.lab rndc reload com
```

5. **Verify:**
```bash
dig @192.5.5.50 microsoft.com NS
```

---

## Serial Number Management

### SOA Serial Format: YYYYMMDDNN

- **YYYY** = Year (2024)
- **MM** = Month (12)
- **DD** = Day (09)
- **NN** = Revision number (01-99)

**Rules:**
- Increment serial EVERY time you modify a zone
- Serial must increase (BIND uses serial arithmetic)
- Rollover after 99 revisions in one day: next day starts at 01

**Example progression:**
```
2024120901  (First version on Dec 9, 2024)
2024120902  (Second update same day)
2024120903  (Third update same day)
2024121001  (First version on Dec 10, 2024)
```

---

## Maintenance Tasks

### Daily
- Monitor query logs for unusual patterns
- Check for failed zone transfers
- Verify all containers are running

### Weekly
- Review and rotate logs
- Check disk space on Docker hosts
- Test zone transfers manually

### Monthly
- Update zone serial numbers even if no changes (best practice)
- Review and update domain delegations
- Backup all zone files

---

## Next Steps

1. **Deploy Authoritative Nameservers**
   - Create zones for microsoft.com, google.com, etc.
   - Deploy containers for these authoritative servers
   - Update TLD zones with delegations

2. **Deploy Recursive Resolvers**
   - Set up 8.8.8.8 (Google DNS)
   - Set up 1.1.1.1 (Cloudflare DNS)
   - Configure to use your root servers

3. **Implement DNSSEC**
   - Sign root zone with KSK/ZSK
   - Sign TLD zones
   - Enable validation on recursive resolvers

4. **Add Monitoring**
   - Prometheus exporters for BIND stats
   - Grafana dashboards for DNS metrics
   - Alerting for zone transfer failures

---

## File Directory Structure Summary

```
/opt/docker-stacks/cdx-dns/bind/
├── root-zone/
│   └── db.root                          (All root servers)
├── tld-zones/
│   ├── db.com                           (Primary servers only)
│   ├── db.net
│   ├── db.org
│   ├── db.gov
│   ├── db.mil
│   └── db.mrvl
├── a-root/
│   ├── named.conf.local
│   ├── named.conf.options
│   └── db.empty
├── b-root/
│   ├── named.conf.local
│   ├── named.conf.options
│   └── db.empty
[... repeat for c through m-root ...]
├── com-primary/
│   ├── named.conf.local
│   ├── named.conf.options
│   └── db.empty
├── com-secondary/
│   ├── named.conf.local
│   ├── named.conf.options
│   └── db.empty
[... repeat for all TLD servers ...]
```

---

**Document Version:** 1.0  
**Last Modified:** December 9, 2024  
**Author:** Tony Stark

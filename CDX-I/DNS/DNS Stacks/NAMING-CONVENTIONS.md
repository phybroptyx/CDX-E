# CDX-DNS Container Naming Conventions

**Updated:** December 10, 2024  
**Version:** Final (Realistic Internet Naming)

---

## Container Naming Philosophy

All DNS containers use **realistic Internet naming conventions** to maximize training value and provide authentic operational experience.

---

## Root Server Naming

Root servers use the **actual Internet root server naming convention**: `[letter].root-servers.net`

### Host 1 (Americas) - 9 Root Servers

| Container Name | IP Address | EQIX Zone | Actual Internet Operator |
|----------------|------------|-----------|--------------------------|
| a.root-servers.net | 198.41.0.4 | EQIX5 Toronto | VeriSign |
| b.root-servers.net | 199.9.14.201 | EQIX4 Seattle | USC-ISI |
| c.root-servers.net | 192.33.4.12 | EQIX5 Toronto | Cogent |
| d.root-servers.net | 199.7.91.13 | EQIX5 Toronto | University of Maryland |
| e.root-servers.net | 192.203.230.10 | EQIX4 Seattle | NASA |
| f.root-servers.net | 192.5.5.241 | EQIX4 Seattle | ISC |
| g.root-servers.net | 192.112.36.4 | EQIX5 Toronto | US DoD |
| h.root-servers.net | 198.97.190.53 | EQIX5 Toronto | US Army |
| l.root-servers.net | 199.7.83.42 | EQIX4 Seattle | ICANN |

### Host 2 (Europe) - 3 Root Servers

| Container Name | IP Address | EQIX Zone | Actual Internet Operator |
|----------------|------------|-----------|--------------------------|
| i.root-servers.net | 192.36.148.17 | EQIX6 Frankfurt | Netnod |
| j.root-servers.net | 192.58.128.30 | EQIX1 London | VeriSign |
| k.root-servers.net | 193.0.14.129 | EQIX1 London | RIPE NCC |

### Host 3 (Asia-Pacific) - 1 Root Server

| Container Name | IP Address | EQIX Zone | Actual Internet Operator |
|----------------|------------|-----------|--------------------------|
| m.root-servers.net | 202.12.27.33 | EQIX10 Seoul | WIDE Project |

---

## TLD Server Naming

TLD servers use descriptive naming: `[tld]-tld-[role]` with FQDN hostname `[tld]-tld-[role].cdx.lab`

### Host 1 - TLD Primary Servers (8 containers)

| Container Name | Hostname | IP Address | TLD |
|----------------|----------|------------|-----|
| com-tld-primary | com-tld-primary.cdx.lab | 192.5.5.50 | .com |
| net-tld-primary | net-tld-primary.cdx.lab | 192.5.5.51 | .net |
| org-tld-primary | org-tld-primary.cdx.lab | 192.5.5.52 | .org |
| io-tld-primary | io-tld-primary.cdx.lab | 192.5.5.53 | .io |
| edu-tld-primary | edu-tld-primary.cdx.lab | 192.5.5.54 | .edu |
| gov-tld-primary | gov-tld-primary.cdx.lab | 192.5.5.55 | .gov |
| mil-tld-primary | mil-tld-primary.cdx.lab | 192.5.5.56 | .mil |
| mrvl-tld-primary | mrvl-tld-primary.cdx.lab | 192.5.5.57 | .mrvl |

### Host 1 - TLD Secondary Servers (2 containers)

| Container Name | Hostname | IP Address | TLD |
|----------------|----------|------------|-----|
| com-tld-secondary | com-tld-secondary.cdx.lab | 198.41.0.50 | .com |
| net-tld-secondary | net-tld-secondary.cdx.lab | 198.41.0.51 | .net |

### Host 2 - TLD Secondary Servers (6 containers)

| Container Name | Hostname | IP Address | TLD |
|----------------|----------|------------|-----|
| org-tld-secondary | org-tld-secondary.cdx.lab | 198.41.0.52 | .org |
| io-tld-secondary | io-tld-secondary.cdx.lab | 198.41.0.53 | .io |
| edu-tld-secondary | edu-tld-secondary.cdx.lab | 198.41.0.54 | .edu |
| gov-tld-secondary | gov-tld-secondary.cdx.lab | 198.41.0.55 | .gov |
| mil-tld-secondary | mil-tld-secondary.cdx.lab | 198.41.0.56 | .mil |
| mrvl-tld-secondary | mrvl-tld-secondary.cdx.lab | 198.41.0.57 | .mrvl |

---

## Control Container Naming

| Container Name | Hostname | IP Address | Purpose |
|----------------|----------|------------|---------|
| cdx-dns-control | cdx-dns-control.cdx.lab | 202.12.27.100 | Monitoring/Control |

---

## Docker Command Examples

### Using Realistic Root Server Names

**Before (generic):**
```bash
docker exec cdx-dns-a-root rndc status
docker logs cdx-dns-j-root
```

**After (realistic):**
```bash
docker exec a.root-servers.net rndc status
docker logs j.root-servers.net
```

### Using TLD Server Names

```bash
# TLD primaries
docker exec com-tld-primary rndc status
docker exec org-tld-primary rndc reload org

# TLD secondaries
docker exec org-tld-secondary rndc refresh org
docker logs edu-tld-secondary
```

### Control Container

```bash
docker exec cdx-dns-control dig @198.41.0.4 . NS
docker exec cdx-dns-control sh
```

---

## Filtering Containers

### By Type

```bash
# All root servers
docker ps --filter "name=root-servers.net"

# All TLD primaries
docker ps --filter "name=tld-primary"

# All TLD secondaries
docker ps --filter "name=tld-secondary"
```

### By Host

```bash
# Host 1 (Americas)
docker ps --filter "name=.root-servers.net" --filter "name=tld-"
# Returns: 19 containers

# Host 2 (Europe)
docker ps --filter "name=.root-servers.net"
# Returns: 3 containers (i, j, k)

# Host 3 (Asia-Pacific)
docker ps --filter "name=m.root-servers.net"
# Returns: 1 container
```

---

## Training Value

### Realistic Operations

**Authentic Commands:**
- `dig @a.root-servers.net . NS`
- `docker exec i.root-servers.net rndc status`
- `docker logs k.root-servers.net`

**Realistic Scenarios:**
- "a.root-servers.net is responding slowly"
- "Zone transfer from com-tld-primary to com-tld-secondary failed"
- "j.root-servers.net in London is unreachable"

### Blue Team Training Benefits

1. **Familiar Naming**: Trainees recognize real Internet infrastructure patterns
2. **Authentic Monitoring**: Learn to monitor actual root server names
3. **Incident Response**: Practice with realistic server identifiers
4. **Documentation**: Logs and outputs use production-style naming

---

## Portainer Display

When viewing stacks in Portainer, containers appear with realistic names:

**Stack: cdx-dns (Host 1)**
```
✓ a.root-servers.net
✓ b.root-servers.net
✓ c.root-servers.net
...
✓ com-tld-primary
✓ net-tld-primary
...
```

**Stack: cdx-dns (Host 2)**
```
✓ i.root-servers.net
✓ j.root-servers.net
✓ k.root-servers.net
✓ org-tld-secondary
...
```

---

## Verification Commands

### Check All Root Servers

```bash
for letter in a b c d e f g h i j k l m; do
    echo -n "Testing $letter.root-servers.net: "
    docker exec $letter.root-servers.net rndc status 2>&1 | grep -q "server is up" && echo "UP" || echo "DOWN"
done
```

### Check All TLD Primaries

```bash
for tld in com net org edu io gov mil mrvl; do
    echo -n "Testing $tld-tld-primary: "
    docker exec $tld-tld-primary rndc status 2>&1 | grep -q "server is up" && echo "UP" || echo "DOWN"
done
```

### Check All TLD Secondaries

```bash
for tld in com net org edu io gov mil mrvl; do
    echo -n "Testing $tld-tld-secondary: "
    docker exec $tld-tld-secondary rndc status 2>&1 | grep -q "server is up" && echo "UP" || echo "DOWN"
done
```

---

## Comparison with Previous Naming

| Old Name | New Name | Notes |
|----------|----------|-------|
| cdx-dns-a-root | a.root-servers.net | Matches real Internet |
| cdx-dns-com-primary | com-tld-primary | Cleaner, more professional |
| cdx-dns-org-secondary | org-tld-secondary | Consistent role naming |

---

## Summary

**Root Servers:** Use Internet standard `[letter].root-servers.net`  
**TLD Servers:** Use descriptive `[tld]-tld-[primary/secondary]`  
**Control:** Use `cdx-dns-control` for monitoring

**Result:** Maximum realism, professional appearance, excellent training value.

---

**All container names now match production Internet infrastructure conventions.**

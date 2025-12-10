# CDX-NTP Deployment Guide

**Stack Name:** cdx-ntp  
**Total Servers:** 5 (2 + 2 + 1)  
**Deployment Time:** ~15 minutes total

---

## Prerequisites

### Network Dependency

**IMPORTANT:** NTP stacks reuse networks from DNS deployment:
- `cdx-dns_eqix4`, `cdx-dns_eqix5` (Host 1)
- `cdx-dns_eqix2`, `cdx-dns_eqix6` (Host 2)
- `cdx-dns_eqix10` (Host 3)

**Deploy DNS stacks FIRST** before deploying NTP stacks.

---

## Portainer Deployment

### Docker Host 1 (Americas) - 2 Servers

1. **Log into Portainer** on Docker Host 1
2. **Navigate to:** Stacks → Add Stack
3. **Stack Name:** `cdx-ntp`
4. **Build Method:** Web editor
5. **Copy/Paste:** Contents of `portainer-stack-host1.yml`
6. **Deploy the stack**
7. **Verify:** 2 containers running

**Expected Containers:**
- cdx-ntp-seattle (192.5.5.100)
- cdx-ntp-toronto (198.41.0.100)

---

### Docker Host 2 (Europe) - 2 Servers

1. **Log into Portainer** on Docker Host 2
2. **Navigate to:** Stacks → Add Stack
3. **Stack Name:** `cdx-ntp`
4. **Build Method:** Web editor
5. **Copy/Paste:** Contents of `portainer-stack-host2.yml`
6. **Deploy the stack**
7. **Verify:** 2 containers running

**Expected Containers:**
- cdx-ntp-frankfurt (46.244.164.88) ⭐ ntp.nist.gov
- cdx-ntp-amsterdam (37.74.100.100)

---

### Docker Host 3 (Asia-Pacific) - 1 Server

1. **Log into Portainer** on Docker Host 3
2. **Navigate to:** Stacks → Add Stack
3. **Stack Name:** `cdx-ntp`
4. **Build Method:** Web editor
5. **Copy/Paste:** Contents of `portainer-stack-host3.yml`
6. **Deploy the stack**
7. **Verify:** 1 container running

**Expected Container:**
- cdx-ntp-seoul (202.12.27.101)

---

## Post-Deployment Verification

### Phase 1: Container Status Check

**On each Docker host:**

```bash
docker ps --filter "name=cdx-ntp"
```

**Expected output:**
```
CONTAINER ID   IMAGE              STATUS         PORTS     NAMES
abc123def456   cturra/ntp:latest  Up 2 minutes   123/udp   cdx-ntp-seattle
def456abc789   cturra/ntp:latest  Up 2 minutes   123/udp   cdx-ntp-toronto
```

### Phase 2: Chrony Status Check

**Test each NTP server:**

```bash
# Frankfurt (primary)
docker exec cdx-ntp-frankfurt chronyc tracking

# Seattle
docker exec cdx-ntp-seattle chronyc tracking

# Toronto
docker exec cdx-ntp-toronto chronyc tracking

# Amsterdam
docker exec cdx-ntp-amsterdam chronyc tracking

# Seoul
docker exec cdx-ntp-seoul chronyc tracking
```

**Expected output:**
```
Reference ID    : 67680D01 (103.140.210.1)
Stratum         : 2
Ref time (UTC)  : Tue Dec 10 12:00:00 2024
System time     : 0.000000045 seconds fast of NTP time
Last offset     : +0.000000123 seconds
RMS offset      : 0.000000234 seconds
Frequency       : 5.432 ppm slow
Residual freq   : +0.001 ppm
Skew            : 0.123 ppm
Root delay      : 0.000123456 seconds
Root dispersion : 0.000234567 seconds
Update interval : 64.5 seconds
Leap status     : Normal
```

**Key Indicators:**
- ✅ Reference ID shows `103.140.210.1` (Tier-0 upstream)
- ✅ Stratum = 2 (correct level)
- ✅ Leap status = Normal
- ✅ Root delay < 1 second

### Phase 3: Source Verification

**Check upstream synchronization:**

```bash
docker exec cdx-ntp-frankfurt chronyc sources
```

**Expected output:**
```
MS Name/IP address         Stratum Poll Reach LastRx Last sample               
===============================================================================
^* 103.140.210.1                 1   6   377    34    +45us[  +67us] +/-  123us
```

**Key Indicators:**
- ✅ `^*` = Currently selected source
- ✅ Stratum 1 upstream
- ✅ Reach = 377 (all 8 recent polls successful)
- ✅ Last sample offset < 1ms

### Phase 4: Client Query Test

**From any CHILLED_ROCKET workstation or server:**

```bash
# Test Frankfurt (ntp.nist.gov)
ntpdate -q 46.244.164.88

# Test Seattle
ntpdate -q 192.5.5.100

# Test Seoul
ntpdate -q 202.12.27.101
```

**Expected output:**
```
server 46.244.164.88, stratum 2, offset 0.000123, delay 0.02345
10 Dec 12:00:00 ntpdate[12345]: adjust time server 46.244.164.88 offset 0.000123 sec
```

**Key Indicators:**
- ✅ Stratum 2
- ✅ Offset < 10ms (ideally < 1ms)
- ✅ Delay < 100ms

### Phase 5: DNS Resolution Test

**Verify ntp.nist.gov resolves:**

```bash
# Should return 46.244.164.88
dig @192.5.5.50 ntp.nist.gov A +short
nslookup ntp.nist.gov 192.5.5.50
```

**Expected:** `46.244.164.88`

### Phase 6: VyOS Router Test

**From any VyOS router:**

```bash
show ntp
```

**Expected output:**
```
NTP server: 46.244.164.88
status: synchronized
stratum: 3
offset: 0.123ms
```

---

## Troubleshooting

### Issue: Container Won't Start

**Check logs:**
```bash
docker logs cdx-ntp-frankfurt
```

**Common causes:**
- Network not found (deploy DNS stack first)
- IP address conflict
- SYS_TIME capability missing

**Solution:**
```bash
# Verify network exists
docker network ls | grep eqix6

# Check for IP conflicts
docker network inspect cdx-dns_eqix6 | grep -A 5 "46.244.164.88"
```

### Issue: "Reference ID: 00000000"

**Symptom:** chronyc tracking shows no reference

**Check connectivity to upstream:**
```bash
docker exec cdx-ntp-frankfurt ping -c 3 103.140.210.1
```

**Common causes:**
- Upstream (103.140.210.1) not reachable
- Firewall blocking UDP/123
- Routing issue

**Solution:**
```bash
# Verify routing
ip route get 103.140.210.1

# Check firewall rules
iptables -L -n | grep 123
```

### Issue: High Offset/Jitter

**Symptom:** Large time offset reported

**Check source quality:**
```bash
docker exec cdx-ntp-frankfurt chronyc sourcestats
```

**Common causes:**
- Network congestion
- Virtualization timer issues
- Upstream source problems

**Solution:**
```bash
# Force immediate sync
docker exec cdx-ntp-frankfurt chronyc makestep

# Monitor over time
watch -n 5 'docker exec cdx-ntp-frankfurt chronyc tracking'
```

### Issue: Clients Can't Query NTP Server

**Test basic connectivity:**
```bash
# From client
nc -u 46.244.164.88 123 -v
```

**Check firewall on Docker host:**
```bash
# UFW
ufw status | grep 123

# iptables
iptables -L INPUT -n | grep 123
```

**Solution:**
```bash
# Allow NTP (UDP/123)
ufw allow 123/udp

# Or iptables
iptables -A INPUT -p udp --dport 123 -j ACCEPT
```

---

## Client Configuration

### Update VyOS Routers

**Americas Routers (EQIX4/EQIX5 connected):**

```bash
configure
delete service ntp server 46.244.164.88
set service ntp server 192.5.5.100
set service ntp server 198.41.0.100
commit
save
```

**Europe Routers (EQIX1/EQIX2/EQIX6 connected):**

```bash
configure
set service ntp server 46.244.164.88
set service ntp server 37.74.100.100
commit
save
```

**Asia-Pacific Routers (EQIX10 connected):**

```bash
configure
delete service ntp server 46.244.164.88
set service ntp server 202.12.27.101
set service ntp server 46.244.164.88      # Fallback to Europe
commit
save
```

### Update Windows Domain Controllers

**STK-DC-01 (HQ Primary):**

```powershell
# Configure as authoritative time source for domain
w32tm /config /manualpeerlist:"192.5.5.100,198.41.0.100" /syncfromflags:manual /reliable:yes /update

# Restart service
net stop w32time
net start w32time

# Force sync
w32tm /resync /rediscover

# Verify
w32tm /query /status
w32tm /query /peers
```

**Expected output:**
```
Leap Indicator: 0(no warning)
Stratum: 3 (secondary reference - syncd by (S)NTP)
Precision: -6 (15.625ms per tick)
Source: 192.5.5.100
Poll Interval: 10 (1024s)
```

**Other DCs (Auto-sync from STK-DC-01):**

```powershell
# Configure to sync from domain hierarchy
w32tm /config /syncfromflags:domhier /update

# Restart and sync
net stop w32time
net start w32time
w32tm /resync

# Verify syncing from STK-DC-01
w32tm /query /status
```

### Update DHCP Scopes (Optional)

**Add NTP servers to DHCP Option 42:**

```powershell
# On DHCP server (STK-DC-01)
Set-DhcpServerv4OptionValue -OptionId 42 -Value @("192.5.5.100", "198.41.0.100")

# Verify
Get-DhcpServerv4OptionValue -OptionId 42
```

**Clients will receive NTP servers via DHCP and auto-configure.**

---

## Monitoring

### Create Health Check Script

```bash
#!/bin/bash
# /opt/cdx-ntp-monitor.sh

REGION=$(hostname | grep -q 'host1' && echo "Americas" || (hostname | grep -q 'host2' && echo "Europe" || echo "Asia-Pacific"))

echo "[$REGION] NTP Server Health Check - $(date)"
echo "================================================"

for container in $(docker ps --filter "name=cdx-ntp" --format '{{.Names}}'); do
    echo ""
    echo "=== $container ==="
    
    # Check if running
    status=$(docker inspect -f '{{.State.Status}}' $container)
    echo "Status: $status"
    
    if [ "$status" = "running" ]; then
        # Get tracking info
        docker exec $container chronyc tracking 2>&1 | grep -E "Reference|Stratum|System time|Leap"
        
        # Get source status
        echo ""
        docker exec $container chronyc sources 2>&1 | head -3
    fi
done
```

**Run via cron:**
```bash
chmod +x /opt/cdx-ntp-monitor.sh
crontab -e
# Add: */5 * * * * /opt/cdx-ntp-monitor.sh >> /var/log/cdx-ntp-health.log 2>&1
```

### Prometheus Metrics (Advanced)

**chrony_exporter** can be added for metrics:

```yaml
  chrony-exporter:
    image: superq/chrony-exporter:latest
    container_name: cdx-ntp-frankfurt-exporter
    command:
      - '--chrony.address=cdx-ntp-frankfurt:323'
    networks:
      - eqix6
    ports:
      - "9123:9123"
```

---

## DNS Zone Updates (Recommended)

### Add Regional NTP Entries

Update your DNS zone files to include regional NTP entries:

**db.com (or create db.cdx.lab):**

```bind
; Regional NTP servers
ntp.americas.cdx.lab.  IN  A  192.5.5.100
ntp.americas.cdx.lab.  IN  A  198.41.0.100
ntp.europe.cdx.lab.    IN  A  46.244.164.88
ntp.europe.cdx.lab.    IN  A  37.74.100.100
ntp.apac.cdx.lab.      IN  A  202.12.27.101

; Global NTP pool
ntp.cdx.lab.           IN  A  192.5.5.100
ntp.cdx.lab.           IN  A  198.41.0.100
ntp.cdx.lab.           IN  A  46.244.164.88
ntp.cdx.lab.           IN  A  37.74.100.100
ntp.cdx.lab.           IN  A  202.12.27.101

; EQIX-specific
ntp.eqix4.cdx.lab.     IN  A  192.5.5.100
ntp.eqix5.cdx.lab.     IN  A  198.41.0.100
ntp.eqix2.cdx.lab.     IN  A  37.74.100.100
ntp.eqix6.cdx.lab.     IN  A  46.244.164.88
ntp.eqix10.cdx.lab.    IN  A  202.12.27.101
```

**Increment zone serial and reload:**

```bash
# On DNS primary server container
docker exec com-tld-primary rndc reload com
```

---

## Stack Management

### View Status in Portainer

**Navigate to:** Stacks → cdx-ntp

**Should show:**
- Host 1: 2 services (seattle, toronto)
- Host 2: 2 services (frankfurt, amsterdam)
- Host 3: 1 service (seoul)

### Restart All NTP Servers

```bash
# Via Portainer: Stacks → cdx-ntp → Restart

# Or via CLI:
docker restart $(docker ps --filter "name=cdx-ntp" -q)
```

### Update Stack Configuration

1. Portainer → Stacks → cdx-ntp → Editor
2. Modify YAML (e.g., change upstream server)
3. Update the stack
4. Containers recreate automatically

### Remove Stack

```bash
# Via Portainer: Stacks → cdx-ntp → Delete

# Or via CLI:
docker stack rm cdx-ntp
```

---

## Success Criteria

✅ **Deployment successful when:**
- All 5 containers running (2 + 2 + 1)
- All show Stratum 2
- All synchronized to 103.140.210.1
- ntp.nist.gov (46.244.164.88) responds to queries
- VyOS routers successfully sync
- Domain controllers successfully sync
- Client queries return accurate time (offset < 10ms)

**Test command:**
```bash
ntpdate -q 46.244.164.88 && echo "✓ NTP operational"
```

---

**Your CDX-NTP infrastructure is ready for deployment!**

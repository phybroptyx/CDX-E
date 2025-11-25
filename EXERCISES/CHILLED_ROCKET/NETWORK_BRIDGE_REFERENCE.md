# CHILLED_ROCKET - Network Bridge Configuration Reference

## Overview

The CHILLED_ROCKET exercise uses **41 dedicated network bridges** to provide proper network segmentation across 5 global sites. Each bridge represents a specific network segment organized by site, function, and security zone.

**Total Systems:** 343 VMs across 41 network bridges  
**Bridge Naming Convention:** `stk###` (Stark Industries network bridges)  
**Bridge Range:** stk100 - stk140  

## Network Architecture Philosophy

### Segmentation Strategy
1. **Geographic Isolation:** Each site has its own set of bridges
2. **Functional Separation:** Servers, departments, and functions are isolated
3. **Security Zones:** Core, DMZ, and Boundary networks for defense in depth
4. **Department VLANs:** Individual networks per department for access control

### Security Zones
- **Core Servers:** Domain controllers, file servers, databases (high trust)
- **DMZ:** Web and application servers (public-facing, restricted)
- **Boundary:** Edge/gateway systems (external interface)
- **Department Networks:** Workstation segments (user access)

## Complete Bridge Listing

### HQ Networks (stk100-stk110) - 11 bridges

| Bridge | Network Name | Purpose | Systems |
|--------|-------------|---------|---------|
| **stk100** | HQ Core Servers | DCs, File Servers, DB Servers, NMS, WSUS | 8 systems |
| **stk101** | HQ Boundary | Edge/Gateway systems | 0 systems |
| **stk102** | HQ DMZ | Web and Application Servers (public) | 4 systems |
| **stk103** | HQ Operations Support | Ops-Support department workstations | 5 systems |
| **stk104** | HQ Human Resources | HR department workstations | 9 systems |
| **stk105** | HQ Legal | Legal department workstations | 8 systems |
| **stk106** | HQ Operations | Operations, IT-Core, Gov-Liaison | 29 systems |
| **stk107** | HQ Engineering Servers | Engineering infrastructure servers | 0 systems |
| **stk108** | HQ Engineering Workstations | Engineering & Eng Dev workstations | 13 systems |
| **stk109** | HQ Quality Assurance | QA department workstations | 15 systems |
| **stk110** | HQ CAD | CAD department workstations | 13 systems |

**HQ Total:** 104 systems

### Malibu Networks (stk111-stk115) - 5 bridges

| Bridge | Network Name | Purpose | Systems |
|--------|-------------|---------|---------|
| **stk111** | Malibu Boundary | Edge/Gateway systems | 0 systems |
| **stk112** | Malibu Core Servers | DCs, File Servers, DB Servers, NMS | 7 systems |
| **stk113** | Malibu DMZ | Application Servers (Tony's dev environment) | 2 systems |
| **stk114** | Malibu Operations | Operations department workstations | 5 systems |
| **stk115** | Malibu Development | Development workstations (includes Tony Stark) | 16 systems |

**Malibu Total:** 30 systems

### Dallas Networks (stk116-stk124) - 9 bridges

| Bridge | Network Name | Purpose | Systems |
|--------|-------------|---------|---------|
| **stk116** | Dallas Boundary | Edge/Gateway systems | 0 systems |
| **stk117** | Dallas DMZ | Public-facing services | 0 systems |
| **stk118** | Dallas Core Servers | DCs, File Servers, DB Servers, NMS | 7 systems |
| **stk119** | Dallas Operations | Operations & IT-Core workstations | 15 systems |
| **stk120** | Dallas Operations Support | Ops-Support department workstations | 5 systems |
| **stk121** | Dallas Engineering | Engineering department workstations | 10 systems |
| **stk122** | Dallas Engineering Development | Engineering Development workstations | 10 systems |
| **stk123** | Dallas Quality Assurance | QA department workstations | 10 systems |
| **stk124** | Dallas CAD | CAD department workstations | 5 systems |

**Dallas Total:** 62 systems

### Nagasaki Networks (stk125-stk132) - 8 bridges

| Bridge | Network Name | Purpose | Systems |
|--------|-------------|---------|---------|
| **stk125** | Nagasaki Boundary | Edge/Gateway systems | 0 systems |
| **stk126** | Nagasaki DMZ | Public-facing services | 0 systems |
| **stk127** | Nagasaki Core Servers | DCs, File Servers, DB Servers, NMS, WSUS | 8 systems |
| **stk128** | Nagasaki Operations | Operations & IT-Core workstations | 21 systems |
| **stk129** | Nagasaki Operations Support | Ops-Support department workstations | 5 systems |
| **stk130** | Nagasaki Engineering | Engineering department workstations | 12 systems |
| **stk131** | Nagasaki Engineering Development | Engineering Development workstations | 12 systems |
| **stk132** | Nagasaki Quality Assurance | QA department workstations | 18 systems |

**Nagasaki Total:** 76 systems

### Amsterdam Networks (stk133-stk140) - 8 bridges

| Bridge | Network Name | Purpose | Systems |
|--------|-------------|---------|---------|
| **stk133** | Amsterdam Boundary | Edge/Gateway systems | 0 systems |
| **stk134** | Amsterdam DMZ | Web and Application Servers (public) | 5 systems |
| **stk135** | Amsterdam Core Servers | DCs, File Servers, DB Servers, NMS, WSUS | 7 systems |
| **stk136** | Amsterdam Operations | Operations & IT-Core workstations | 17 systems |
| **stk137** | Amsterdam Operations Support | Ops-Support department workstations | 5 systems |
| **stk138** | Amsterdam Engineering | Engineering department workstations | 10 systems |
| **stk139** | Amsterdam Engineering Development | Engineering Development workstations | 12 systems |
| **stk140** | Amsterdam Quality Assurance | QA department workstations | 15 systems |

**Amsterdam Total:** 71 systems

## Network Configuration Details

### Bridge Properties
All network interfaces are configured with:
```json
{
  "network": {
    "bridge": "stk###",
    "model": "virtio",
    "firewall": true,
    "description": "Human-readable network name"
  }
}
```

**Model:** `virtio` - Paravirtualized network adapter for best performance  
**Firewall:** `true` - Proxmox firewall enabled on all interfaces  

### Server-to-Bridge Mapping Logic

#### Core Server Networks (stk100, stk112, stk118, stk127, stk135)
**Assigned to:**
- Domain Controllers
- File Servers
- Database Servers
- Network Management Servers
- WSUS Servers

**Rationale:** Critical infrastructure requiring highest security and isolation

#### DMZ Networks (stk102, stk113, stk117, stk126, stk134)
**Assigned to:**
- Web Servers
- Application Servers (public-facing)

**Rationale:** Internet-facing services require DMZ isolation for security

#### Department Networks (stk103-stk106, stk108-stk110, etc.)
**Assigned to:**
- Workstations organized by department
- Department-specific resources

**Rationale:** Access control and traffic segmentation by business function

## Network Security Considerations

### Zone Isolation
```
Internet
    ↓
[Boundary] stk101, stk111, stk116, stk125, stk133 (unused/reserved)
    ↓
[DMZ] stk102, stk113, stk117, stk126, stk134 (Web/App servers)
    ↓
[Core Servers] stk100, stk112, stk118, stk127, stk135 (Critical infrastructure)
    ↓
[Department VLANs] stk103-stk110, stk114-stk115, stk119-stk124, etc. (Workstations)
```

### Firewall Rules (Recommended)

#### Core Server Networks
```
Allow: AD replication (TCP/UDP 389, 636, 3268, 88, 53, 445, 135, 49152-65535)
Allow: File sharing from department networks (SMB: TCP 445, 139)
Allow: Database connections from DMZ/departments (TCP 1433, 3306, 5432)
Deny: Direct internet access
```

#### DMZ Networks
```
Allow: Inbound HTTP/HTTPS (TCP 80, 443)
Allow: Outbound to core servers (DB, file access)
Deny: Direct access to department networks
Deny: Unrestricted core server access
```

#### Department Networks
```
Allow: Outbound to core servers (file, DNS, AD)
Allow: Outbound to DMZ (web services)
Allow: Outbound internet access (controlled)
Deny: Cross-department traffic (except IT-Core)
```

### VIP System Network Placement

| VIP User | VM ID | Network | Bridge | Rationale |
|----------|-------|---------|--------|-----------|
| **Tony Stark (CEO)** | 6200 | Malibu Development | stk115 | Isolated development environment |
| **Pepper Potts (COO)** | 6001 | HQ Operations | stk106 | Executive operations network |
| **Happy Hogan (COS)** | 6022 | HQ Ops-Support | stk103 | Security operations network |

**Security Note:** VIP systems should have additional monitoring, enhanced firewall rules, and possibly dedicated VLANs for maximum security.

## Deployment Configuration

### Proxmox Network Bridge Setup

#### Example: Creating HQ Core Servers Bridge
```bash
# On Proxmox host
cat >> /etc/network/interfaces << EOF

auto stk100
iface stk100 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # HQ Core Servers - 66.218.180.0/22
EOF

systemctl restart networking
```

### Assigning Bridge to VM (CLI)
```bash
# Set network for Domain Controller
qm set 5001 --net0 virtio=14:18:77:3A:2B:C1,bridge=stk100,firewall=1

# Set network for VIP workstation (Tony Stark)
qm set 6200 --net0 virtio=D4:AE:52:C4:2D:34,bridge=stk115,firewall=1
```

### Assigning Bridge to VM (GUI)
1. Select VM in Proxmox web interface
2. Navigate to: Hardware → Network Device
3. Edit network device:
   - **Bridge:** Select appropriate stk### bridge
   - **Model:** virtio
   - **MAC Address:** Use MAC from JSON
   - **Firewall:** Enable

## VLAN Mapping (If Using VLANs)

If implementing with VLAN tags instead of separate bridges:

| Bridge Range | VLAN Range | Site |
|-------------|------------|------|
| stk100-stk110 | VLAN 100-110 | HQ |
| stk111-stk115 | VLAN 111-115 | Malibu |
| stk116-stk124 | VLAN 116-124 | Dallas |
| stk125-stk132 | VLAN 125-132 | Nagasaki |
| stk133-stk140 | VLAN 133-140 | Amsterdam |

**Implementation:**
```bash
# Example: stk100 as VLAN 100 on physical interface
auto stk100
iface stk100 inet manual
    vlan-raw-device eth0
    bridge-ports eth0.100
    bridge-stp off
    bridge-fd 0
```

## IP Address Planning

Based on the CDX-E documentation, these are the subnet allocations:

### HQ (New York) - 66.218.180.0/22
```
Core Servers (stk100):       66.218.180.0/24
DMZ (stk102):                66.218.181.0/24
Operations (stk106):         66.218.182.0/24
Engineering/Dept (stk108+):  66.218.183.0/24
```

### Malibu (California) - 4.150.216.0/22
```
Core Servers (stk112):       4.150.216.0/24
DMZ (stk113):                4.150.217.0/24
Operations (stk114):         4.150.218.0/24
Development (stk115):        4.150.219.0/24
```

### Dallas (Texas) - 50.222.72.0/22
```
Core Servers (stk118):       50.222.72.0/24
Operations (stk119):         50.222.73.0/24
Engineering (stk121-122):    50.222.74.0/24
QA/CAD (stk123-124):         50.222.75.0/24
```

### Nagasaki (Japan) - 14.206.0.0/22
```
Core Servers (stk127):       14.206.0.0/24
Operations (stk128):         14.206.1.0/24
Engineering (stk130-131):    14.206.2.0/24
QA (stk132):                 14.206.3.0/24
```

### Amsterdam (Netherlands) - 37.74.124.0/22
```
Core Servers (stk135):       37.74.124.0/24
Operations (stk136):         37.74.125.0/24
Engineering (stk138-139):    37.74.126.0/24
QA/DMZ (stk140/134):         37.74.127.0/24
```

## Network Traffic Flow Examples

### User Authentication (Workstation → DC)
```
Workstation (stk106) → Core Servers (stk100)
Protocols: Kerberos (88), LDAP (389, 636), DNS (53)
```

### Web Access (Internet → Web Server → Database)
```
Internet → DMZ (stk102) → Core Servers (stk100)
Protocols: HTTPS (443), SQL (1433)
```

### File Access (Workstation → File Server)
```
Workstation (stk108) → Core Servers (stk100)
Protocols: SMB (445, 139), NFS (2049)
```

### Tony Stark Development Workflow
```
Development Workstation (stk115) ↔ Dev Servers (stk113/stk112)
Protocols: SSH (22), RDP (3389), SQL (1433), HTTP/S (80/443)
```

## Monitoring and Management

### Per-Bridge Statistics
Monitor traffic per bridge using Proxmox:
```bash
# View bridge statistics
cat /proc/net/dev | grep stk

# Monitor specific bridge traffic
iftop -i stk100
```

### Firewall Logging
```bash
# Enable firewall logging for a bridge
# In Proxmox: Datacenter → Firewall → Options
# Set log_level_in: info
# Set log_level_out: info

# View firewall logs
tail -f /var/log/pve-firewall.log | grep stk100
```

## Troubleshooting

### Common Issues

#### VM Cannot Communicate
```bash
# 1. Verify bridge exists
brctl show stk100

# 2. Check VM network config
qm config 5001 | grep net0

# 3. Verify firewall rules
pct firewall get 5001

# 4. Test connectivity from VM console
# Login to VM and test:
ping <gateway>
nslookup <domain>
```

#### Bridge Not Forwarding Traffic
```bash
# 1. Check bridge is up
ip link show stk100

# 2. Verify STP is off (should be)
brctl showstp stk100

# 3. Check if bridge has any ports
brctl show stk100
```

## Integration with CDX-E Deployment

The `computers.json` file includes network configurations that can be used during VM provisioning:

```powershell
# Example: Deploy VM with network config from JSON
$vm = $computersData.computers | Where-Object { $_.vmid -eq 5001 }

qm clone $vm.template $vm.vmid --name $vm.name --full
qm set $vm.vmid --net0 "virtio=$($vm.mac),bridge=$($vm.network.bridge),firewall=1"
```

## Quick Reference

### Bridge Assignment by VM ID Range
```
5001-5005:  Domain Controllers → Core Server bridges
5010-5070:  Infrastructure Servers → Core/DMZ bridges
6001-6092:  HQ Workstations → stk103-stk110
6100-6154:  Dallas Workstations → stk119-stk124
6200-6220:  Malibu Workstations → stk114-stk115
6300-6367:  Nagasaki Workstations → stk128-stk132
6400-6458:  Amsterdam Workstations → stk136-stk140
```

### Emergency Network Isolation
```bash
# Isolate entire site (example: HQ)
for i in {100..110}; do
    ifdown stk$i
done

# Re-enable
for i in {100..110}; do
    ifup stk$i
done
```

---

**Last Updated:** 2025-11-24  
**Framework:** CDX-E v2.0  
**Exercise:** CHILLED_ROCKET  
**Total Bridges:** 41 (stk100-stk140)  
**Total Systems:** 343 VMs

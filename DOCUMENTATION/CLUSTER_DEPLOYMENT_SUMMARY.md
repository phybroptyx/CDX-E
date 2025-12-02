# CHILLED_ROCKET - Cluster Deployment Update

## Configuration Version 2.3 (Cluster-Enabled)

### What's New

Your CHILLED_ROCKET configuration now includes **Proxmox 3-node cluster deployment** specifications with geographic distribution.

---

## Cluster Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared NAS Storage                        │
│              (Templates: 2001-2012)                          │
└───────────────┬──────────────────┬──────────────────────────┘
                │                  │                  │
     ┌──────────▼─────────┐ ┌─────▼──────────┐ ┌───▼──────────┐
     │   cdx-pve-01       │ │  cdx-pve-02    │ │ cdx-pve-03   │
     │   (Americas)       │ │  (Europe-AF)   │ │ (Asia-PAC)   │
     │   ─────────────    │ │  ────────────  │ │ ──────────   │
     │   196 VMs          │ │  71 VMs        │ │ 76 VMs       │
     │   ─────────────    │ │  ────────────  │ │ ──────────   │
     │   Sites:           │ │  Sites:        │ │ Sites:       │
     │   • HQ (104)       │ │  • Amsterdam   │ │  • Nagasaki  │
     │   • Dallas (62)    │ │    (71)        │ │    (76)      │
     │   • Malibu (30)    │ │                │ │              │
     │   ─────────────    │ │  ────────────  │ │ ──────────   │
     │   Storage: raid    │ │  Storage: raid │ │ Storage: raid│
     └────────────────────┘ └────────────────┘ └──────────────┘
```

---

## Node Distribution

### cdx-pve-01 (Americas) - 196 VMs

**Geographic Coverage:**
- New York, USA (HQ)
- Dallas, TX, USA
- Malibu, CA, USA

**VM Breakdown:**
- 28 servers
- 168 workstations

**Critical Systems:**
- STK-DC-01, STK-DC-02, STK-DC-03 (3 Domain Controllers)
- WSUS-Americas (HQ-WSU-01)
- VIP Systems: Tony Stark, Pepper Potts, Happy Hogan

**Storage:** Local `raid` storage for all VM disks

---

### cdx-pve-02 (Europe-Africa) - 71 VMs

**Geographic Coverage:**
- Amsterdam, Netherlands

**VM Breakdown:**
- 12 servers
- 59 workstations

**Critical Systems:**
- STK-DC-05 (Domain Controller)
- WSUS-Europe (AMS-WSU-01)
- Amsterdam web and application servers

**Storage:** Local `raid` storage for all VM disks

---

### cdx-pve-03 (Asia-Pacific) - 76 VMs

**Geographic Coverage:**
- Nagasaki, Japan

**VM Breakdown:**
- 8 servers
- 68 workstations

**Critical Systems:**
- STK-DC-04 (Domain Controller)
- WSUS-Asia-Pacific (NAG-WSU-01)
- Nagasaki infrastructure

**Storage:** Local `raid` storage for all VM disks

---

## Storage Configuration

### Template Storage (Shared)
```
Storage: NAS
Type: Network-attached (NFS/iSCSI)
Access: All nodes
Contents: 10 OS templates (VM IDs 2001-2012)
Size: ~200 GB
```

### VM Disk Storage (Local per Node)
```
Storage: raid
Type: Local RAID array
Access: Node-local only
Contents: VM disks (linked clones)
```

### Clone Strategy
```
Type: Linked clones (--full 0)
Source: NAS templates
Destination: Local raid storage
Benefits:
  • Space-efficient
  • Fast provisioning
  • Centralized template management
  • Only stores differences from template
```

---

## Sample Deployment Commands

### Linked Clone on Specific Node
```bash
# Create linked clone on cdx-pve-01 with local storage
qm clone 2003 5001 --name STK-DC-01 --full 0 --target cdx-pve-01 --storage raid

# Configure network
qm set 5001 --net0 virtio=14:18:77:3A:2B:C1,bridge=stk100,firewall=1

# Start VM
qm start 5001
```

### Deploy VIP Workstation (Tony Stark)
```bash
# Clone Tony's workstation to cdx-pve-01
qm clone 2010 6200 --name ML-DEV-W32805N --full 0 --target cdx-pve-01 --storage raid
qm set 6200 --net0 virtio=D4:AE:52:C4:2D:34,bridge=stk115,firewall=1
qm start 6200
```

### Deploy All VMs on a Node (Batch)
```bash
# Deploy all cdx-pve-01 VMs from JSON
jq -r '.computers[] | select(.proxmox.node=="cdx-pve-01") | 
  "\(.vmid)|\(.name)|\(.template)|\(.mac)|\(.network.bridge)"' computers.json | \
while IFS='|' read -r vmid name template mac bridge; do
    qm clone $template $vmid --name $name --full 0 --target cdx-pve-01 --storage raid
    qm set $vmid --net0 virtio=$mac,bridge=$bridge,firewall=1
done
```

---

## JSON Configuration Structure

Each VM now includes:

```json
{
  "vmid": 5001,
  "name": "STK-DC-01",
  "template": 2003,
  "mac": "14:18:77:3A:2B:C1",
  "network": {
    "bridge": "stk100",
    "model": "virtio",
    "firewall": true,
    "description": "HQ Core Servers"
  },
  "proxmox": {
    "node": "cdx-pve-01",
    "storage": "raid",
    "clone_type": "linked",
    "template_storage": "NAS"
  },
  "geographic": {
    "region": "Americas",
    "location": "New York, USA"
  }
}
```

---

## Deployment Workflow

### 1. Pre-Deployment Checks
```bash
# Verify cluster status
pvecm status

# Verify templates on NAS
pvesm list NAS | grep -E "2001|2002|2003|2009|2010|2011|2012"

# Verify storage on each node
pvesm status --storage raid --node cdx-pve-01
pvesm status --storage raid --node cdx-pve-02
pvesm status --storage raid --node cdx-pve-03

# Verify network bridges exist
for node in cdx-pve-01 cdx-pve-02 cdx-pve-03; do
    echo "=== $node ==="
    ssh root@$node "brctl show" | grep stk
done
```

### 2. Deploy Critical Infrastructure
```bash
# Deploy all Domain Controllers first
qm clone 2003 5001 --name STK-DC-01 --full 0 --target cdx-pve-01 --storage raid
qm clone 2003 5002 --name STK-DC-02 --full 0 --target cdx-pve-01 --storage raid
qm clone 2003 5003 --name STK-DC-03 --full 0 --target cdx-pve-01 --storage raid
qm clone 2003 5004 --name STK-DC-04 --full 0 --target cdx-pve-03 --storage raid
qm clone 2003 5005 --name STK-DC-05 --full 0 --target cdx-pve-02 --storage raid

# Configure networks for all DCs
qm set 5001 --net0 virtio=14:18:77:3A:2B:C1,bridge=stk100,firewall=1
qm set 5002 --net0 virtio=14:18:77:3A:2B:C2,bridge=stk100,firewall=1
qm set 5003 --net0 virtio=14:18:77:4F:8E:D1,bridge=stk118,firewall=1
qm set 5004 --net0 virtio=14:18:77:6B:1C:A1,bridge=stk127,firewall=1
qm set 5005 --net0 virtio=14:18:77:8A:4D:E1,bridge=stk135,firewall=1

# Start all DCs
for dc in 5001 5002 5003 5004 5005; do
    qm start $dc
done

# Wait and verify AD replication before continuing
```

### 3. Deploy Infrastructure Servers
Deploy file servers, WSUS, database servers, web/app servers per node.

### 4. Deploy VIP Workstations
Deploy the 3 VIP systems first for testing.

### 5. Deploy Standard Workstations
Deploy remaining 292 workstations across nodes.

---

## Storage Estimates

### Linked Clone Overhead
Each linked clone stores only differences from template:
- Initial: 2-5 GB per VM
- After 30 days: 5-10 GB per VM
- After 90 days: 10-20 GB per VM

### Total Storage Requirements

**cdx-pve-01 (196 VMs):**
- Initial: ~400-1000 GB
- 90-day: ~2-4 TB
- Recommendation: **5 TB RAID array**

**cdx-pve-02 (71 VMs):**
- Initial: ~150-350 GB
- 90-day: ~700-1400 GB
- Recommendation: **2 TB RAID array**

**cdx-pve-03 (76 VMs):**
- Initial: ~150-380 GB
- 90-day: ~750-1500 GB
- Recommendation: **2 TB RAID array**

**NAS Templates:**
- All templates: ~200 GB
- Recommendation: **500 GB allocation**

---

## High Availability Considerations

### Node Failure Impact

| Node Fails | VMs Lost | % of Total | Sites Affected | Critical Services |
|------------|----------|------------|----------------|-------------------|
| cdx-pve-01 | 196 | 57% | HQ, Dallas, Malibu | 3 DCs, WSUS-Americas |
| cdx-pve-02 | 71 | 21% | Amsterdam | 1 DC, WSUS-Europe |
| cdx-pve-03 | 76 | 22% | Nagasaki | 1 DC, WSUS-Asia |

### Mitigation Strategies
1. **Regular Backups:** Use Proxmox Backup Server
2. **AD Redundancy:** 5 DCs across 3 nodes ensures domain continuity
3. **Documentation:** Keep recovery procedures up-to-date
4. **Testing:** Regularly test node failure scenarios

### Migration Limitations
- **Live migration:** NOT possible (local storage)
- **Cold migration:** Possible but requires downtime
- **Backup/Restore:** Primary recovery method

---

## Network Segmentation per Node

### cdx-pve-01 Bridges Required
```
stk100-stk110  (HQ: 11 bridges)
stk111-stk115  (Malibu: 5 bridges)
stk116-stk124  (Dallas: 9 bridges)
Total: 25 bridges
```

### cdx-pve-02 Bridges Required
```
stk133-stk140  (Amsterdam: 8 bridges)
Total: 8 bridges
```

### cdx-pve-03 Bridges Required
```
stk125-stk132  (Nagasaki: 8 bridges)
Total: 8 bridges
```

---

## Benefits of Geographic Distribution

### Realistic Simulation
- **Network Latency:** Inter-site communication simulates real WAN links
- **Site Isolation:** Each region can be isolated for testing
- **Regional Services:** WSUS servers per region
- **Disaster Recovery:** Test cross-region failover

### Training Scenarios
- Multi-site AD replication
- Regional network outages
- Cross-region attack propagation
- Distributed denial of service (DDoS)
- Incident response coordination

### Resource Management
- **Load Balancing:** VMs distributed across hardware
- **Storage Efficiency:** Linked clones reduce duplication
- **Performance:** Local storage for high I/O
- **Scalability:** Can add nodes for additional regions

---

## Files Updated

### computers.json (Now 195 KB)
**New fields added:**
```json
"proxmox": {
  "node": "cdx-pve-01",
  "storage": "raid", 
  "clone_type": "linked",
  "template_storage": "NAS"
},
"geographic": {
  "region": "Americas",
  "location": "New York, USA"
}
```

### New Documentation
- **PROXMOX_CLUSTER_GUIDE.md** (25 KB)
  - Complete cluster deployment guide
  - Automated deployment scripts
  - Troubleshooting procedures
  - Disaster recovery plans

---

## Quick Start

1. **Download** computers.json (updated with cluster config)
2. **Verify** NAS templates accessible from all nodes
3. **Create** network bridges on required nodes
4. **Deploy** Domain Controllers first (5 VMs)
5. **Verify** AD replication working
6. **Deploy** remaining infrastructure in phases
7. **Test** inter-site connectivity

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| **Total VMs** | 343 |
| **Cluster Nodes** | 3 |
| **Geographic Regions** | 3 |
| **Network Bridges** | 41 |
| **Templates** | 10 |
| **Clone Type** | Linked |
| **Storage Type** | Local RAID + Shared NAS |

### Load Distribution
- **cdx-pve-01:** 57% (196 VMs)
- **cdx-pve-02:** 21% (71 VMs)
- **cdx-pve-03:** 22% (76 VMs)

---

**Configuration Version:** 2.3 (Cluster-Enabled)  
**Last Updated:** 2025-11-24  
**Framework:** CDX-E v2.0  
**Exercise:** CHILLED_ROCKET

---

## Next Steps

1. Review **PROXMOX_CLUSTER_GUIDE.md** for detailed deployment procedures
2. Test cluster communication with `pvecm status`
3. Verify template availability on NAS storage
4. Create required network bridges on each node
5. Begin phased deployment starting with Domain Controllers

**All files ready for download!**

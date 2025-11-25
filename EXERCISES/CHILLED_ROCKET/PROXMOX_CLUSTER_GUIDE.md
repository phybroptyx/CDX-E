# CHILLED_ROCKET - Proxmox Cluster Deployment Guide

## Cluster Overview

The CHILLED_ROCKET exercise is deployed across a **3-node Proxmox cluster** with geographic distribution to simulate realistic network latency and site separation.

### Cluster Nodes

| Node | Region | Sites | VMs | Storage |
|------|--------|-------|-----|---------|
| **cdx-pve-01** | Americas | HQ, Dallas, Malibu | 196 | raid |
| **cdx-pve-02** | Europe-Africa | Amsterdam | 71 | raid |
| **cdx-pve-03** | Asia-Pacific | Nagasaki | 76 | raid |

**Total:** 343 VMs across 3 nodes

---

## Storage Architecture

### Template Storage (Shared)
- **Storage Name:** `NAS`
- **Type:** Network-attached storage (NFS/iSCSI)
- **Access:** All 3 nodes can access
- **Contents:** 10 OS templates (VM IDs 2001-2012)
- **Purpose:** Source templates for linked clones

### VM Disk Storage (Local)
- **Storage Name:** `raid` (on each node)
- **Type:** Local RAID storage
- **Access:** Node-local only
- **Contents:** VM disk images (linked clones)
- **Purpose:** High-performance local storage for running VMs

### Clone Strategy
- **Type:** **Linked clones** (not full clones)
- **Benefits:**
  - Space-efficient (only stores differences from template)
  - Faster clone operation
  - Reduced storage footprint
  - Easy template updates
- **Template Source:** NAS storage
- **Clone Destination:** Local `raid` storage on each node

---

## Geographic Distribution

### cdx-pve-01 (Americas) - 196 VMs

#### HQ (New York) - 104 VMs
**Servers (12):**
- 2 Domain Controllers (STK-DC-01, STK-DC-02)
- 2 File Servers
- 1 Network Management Server
- 1 WSUS Server (Americas)
- 2 Database Servers
- 2 Web Servers
- 2 Application Servers

**Workstations (92):**
- Operations: 15 (includes Pepper Potts - COO)
- IT-Core: 6
- Ops-Support: 5 (includes Happy Hogan - COS)
- HR: 9
- Legal: 8
- Gov-Liaison: 8
- Engineering: 7
- Engineering Development: 6
- QA: 15
- CAD: 13

**Network Bridges:** stk100-stk110

#### Dallas (Texas) - 62 VMs
**Servers (7):**
- 1 Domain Controller (STK-DC-03)
- 2 File Servers
- 1 Network Management Server
- 3 Database Servers

**Workstations (55):**
- Operations: 10
- IT-Core: 5
- Ops-Support: 5
- Engineering: 10
- Engineering Development: 10
- QA: 10
- CAD: 5

**Network Bridges:** stk116-stk124

#### Malibu (California) - 30 VMs
**Servers (9):**
- 2 File Servers
- 1 Network Management Server (Server 2025)
- 2 Database Servers
- 2 Development Database Servers (Server 2025)
- 2 Development Application Servers (Server 2025)

**Workstations (21):**
- Operations: 5
- Development: 16 (includes Tony Stark - CEO)

**Network Bridges:** stk111-stk115

---

### cdx-pve-02 (Europe-Africa) - 71 VMs

#### Amsterdam (Netherlands) - 71 VMs
**Servers (12):**
- 1 Domain Controller (STK-DC-05)
- 2 File Servers
- 1 Network Management Server
- 1 WSUS Server (Europe)
- 2 Database Servers
- 2 Web Servers
- 3 Application Servers

**Workstations (59):**
- Operations: 12
- IT-Core: 5
- Ops-Support: 5
- Engineering: 10
- Engineering Development: 12
- QA: 15

**Network Bridges:** stk133-stk140

---

### cdx-pve-03 (Asia-Pacific) - 76 VMs

#### Nagasaki (Japan) - 76 VMs
**Servers (8):**
- 1 Domain Controller (STK-DC-04)
- 2 File Servers
- 1 Network Management Server
- 1 WSUS Server (Asia-Pacific)
- 3 Database Servers

**Workstations (68):**
- Operations: 15
- IT-Core: 6
- Ops-Support: 5
- Engineering: 12
- Engineering Development: 12
- QA: 18

**Network Bridges:** stk125-stk132

---

## Deployment Commands

### Creating Linked Clones

#### Basic Syntax
```bash
# Linked clone with target node and storage
qm clone <TEMPLATE_ID> <VM_ID> --name <VM_NAME> --full 0 --target <NODE> --storage <STORAGE>
```

**Parameters:**
- `--full 0` = Create linked clone (not full clone)
- `--target <NODE>` = Specify which node to create VM on
- `--storage <STORAGE>` = Local storage for VM disk (raid)

#### Domain Controller Example (HQ)
```bash
# Clone from Windows Server 2019 template (2003)
# To cdx-pve-01 with local raid storage
qm clone 2003 5001 --name STK-DC-01 --full 0 --target cdx-pve-01 --storage raid

# Configure network
qm set 5001 --net0 virtio=14:18:77:3A:2B:C1,bridge=stk100,firewall=1

# Start VM
qm start 5001
```

#### VIP Workstation Example (Tony Stark)
```bash
# Clone from Windows 10 Enterprise template (2010)
qm clone 2010 6200 --name ML-DEV-W32805N --full 0 --target cdx-pve-01 --storage raid

# Configure network
qm set 6200 --net0 virtio=D4:AE:52:C4:2D:34,bridge=stk115,firewall=1

# Start VM
qm start 6200
```

### Automated Mass Deployment

#### Bash Script for Batch Deployment
```bash
#!/bin/bash
# deploy_cluster_vms.sh

JSON_FILE="computers.json"

# Deploy all servers
jq -r '.computers[] | "\(.vmid)|\(.name)|\(.template)|\(.proxmox.node)|\(.proxmox.storage)|\(.mac)|\(.network.bridge)"' $JSON_FILE | \
while IFS='|' read -r vmid name template node storage mac bridge; do
    echo "Deploying VM $vmid: $name on $node..."
    
    # Clone VM
    qm clone $template $vmid --name $name --full 0 --target $node --storage $storage
    
    # Configure network
    qm set $vmid --net0 virtio=$mac,bridge=$bridge,firewall=1
    
    echo "VM $vmid deployed successfully"
done

# Deploy all workstations
jq -r '.workstations[] | "\(.vmid)|\(.hostname)|\(.template)|\(.proxmox.node)|\(.proxmox.storage)|\(.mac)|\(.network.bridge)"' $JSON_FILE | \
while IFS='|' read -r vmid hostname template node storage mac bridge; do
    echo "Deploying VM $vmid: $hostname on $node..."
    
    # Clone VM
    qm clone $template $vmid --name $hostname --full 0 --target $node --storage $storage
    
    # Configure network
    qm set $vmid --net0 virtio=$mac,bridge=$bridge,firewall=1
    
    echo "VM $vmid deployed successfully"
done
```

#### Python Deployment Script
```python
#!/usr/bin/env python3
import json
import subprocess
import sys

def deploy_vm(vm_data):
    """Deploy a single VM"""
    vmid = vm_data['vmid']
    name = vm_data.get('name', vm_data.get('hostname'))
    template = vm_data['template']
    node = vm_data['proxmox']['node']
    storage = vm_data['proxmox']['storage']
    mac = vm_data['mac']
    bridge = vm_data['network']['bridge']
    
    print(f"Deploying VM {vmid}: {name} on {node}...")
    
    # Clone VM
    clone_cmd = [
        'qm', 'clone', str(template), str(vmid),
        '--name', name,
        '--full', '0',
        '--target', node,
        '--storage', storage
    ]
    
    try:
        subprocess.run(clone_cmd, check=True)
        print(f"  ✓ Cloned VM {vmid}")
    except subprocess.CalledProcessError as e:
        print(f"  ✗ Failed to clone VM {vmid}: {e}")
        return False
    
    # Configure network
    net_cmd = [
        'qm', 'set', str(vmid),
        '--net0', f'virtio={mac},bridge={bridge},firewall=1'
    ]
    
    try:
        subprocess.run(net_cmd, check=True)
        print(f"  ✓ Configured network for VM {vmid}")
    except subprocess.CalledProcessError as e:
        print(f"  ✗ Failed to configure network for VM {vmid}: {e}")
        return False
    
    return True

def main():
    with open('computers.json', 'r') as f:
        data = json.load(f)
    
    # Deploy servers first
    print("Deploying servers...")
    for server in data['computers']:
        deploy_vm(server)
    
    # Deploy workstations
    print("\nDeploying workstations...")
    for ws in data['workstations']:
        deploy_vm(ws)

if __name__ == '__main__':
    main()
```

---

## Deployment Phases

### Phase 1: Critical Infrastructure (Priority 1)
Deploy Domain Controllers first on all nodes:

```bash
# cdx-pve-01 (Americas)
qm clone 2003 5001 --name STK-DC-01 --full 0 --target cdx-pve-01 --storage raid
qm clone 2003 5002 --name STK-DC-02 --full 0 --target cdx-pve-01 --storage raid
qm clone 2003 5003 --name STK-DC-03 --full 0 --target cdx-pve-01 --storage raid

# cdx-pve-02 (Europe)
qm clone 2003 5005 --name STK-DC-05 --full 0 --target cdx-pve-02 --storage raid

# cdx-pve-03 (Asia)
qm clone 2003 5004 --name STK-DC-04 --full 0 --target cdx-pve-03 --storage raid
```

Configure networks and start DCs, then verify AD replication before proceeding.

### Phase 2: Infrastructure Servers (Priority 2)
Deploy file servers, WSUS, NMS, database servers per node.

### Phase 3: VIP Systems (Priority 3)
Deploy the 3 VIP workstations:
- VM 6001: Pepper Potts (cdx-pve-01)
- VM 6022: Happy Hogan (cdx-pve-01)
- VM 6200: Tony Stark (cdx-pve-01)

### Phase 4: Application Layer (Priority 4)
Deploy web and application servers.

### Phase 5: Standard Workstations (Priority 5)
Deploy remaining workstations by node to balance load.

---

## Storage Considerations

### Disk Space Requirements

#### Per Node Estimates
**cdx-pve-01 (196 VMs):**
- Linked clone overhead: ~5-10 GB per VM average
- Estimated total: **980 GB - 1.96 TB**

**cdx-pve-02 (71 VMs):**
- Linked clone overhead: ~5-10 GB per VM average
- Estimated total: **355 GB - 710 GB**

**cdx-pve-03 (76 VMs):**
- Linked clone overhead: ~5-10 GB per VM average
- Estimated total: **380 GB - 760 GB**

**Note:** Linked clones grow over time as changes accumulate. Plan for 2-3x initial size for production use.

### Template Storage (NAS)
Required space for all templates:
- Windows Server templates: ~100-120 GB total
- Windows workstation templates: ~80-100 GB total
- **Total estimated:** 180-220 GB

### Snapshot Considerations
If using snapshots for linked clones:
- Each snapshot stores changes since parent
- Multiple snapshots can increase storage significantly
- Recommendation: Limit snapshots per VM or use backup solution

---

## Network Configuration

### Inter-Node Communication
Ensure Proxmox cluster communication is working:
```bash
pvecm status
```

### Bridge Availability
All bridges (stk100-stk140) must exist on all nodes where VMs will use them:

**cdx-pve-01 requires:**
- stk100-stk110 (HQ)
- stk111-stk115 (Malibu)
- stk116-stk124 (Dallas)

**cdx-pve-02 requires:**
- stk133-stk140 (Amsterdam)

**cdx-pve-03 requires:**
- stk125-stk132 (Nagasaki)

### Creating Bridges on Specific Nodes

```bash
# SSH to cdx-pve-01 and create HQ bridges
cat >> /etc/network/interfaces << 'EOF'

auto stk100
iface stk100 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # HQ Core Servers
EOF

# Repeat for all required bridges...
systemctl restart networking
```

---

## Migration and High Availability

### Live Migration Limitations
With linked clones on local storage:
- **Cannot live migrate** between nodes (storage is local)
- Must perform cold migration (shutdown, copy, start)
- Consider this when planning maintenance

### Backup Strategy
Since VMs use local storage:
1. Use Proxmox Backup Server (PBS) or vzdump
2. Schedule regular backups per node
3. Store backups on NAS or external storage
4. Test restore procedures

### Converting to Full Clone (if needed)
```bash
# Move VM disk to create independent copy
qm move-disk <VMID> scsi0 <NEW_STORAGE> --delete 1
```

---

## Cluster Management

### Checking VM Distribution
```bash
# List VMs per node
for node in cdx-pve-01 cdx-pve-02 cdx-pve-03; do
    echo "=== $node ==="
    pvesh get /nodes/$node/qemu --output-format=json | jq -r '.[].vmid' | wc -l
done
```

### Storage Usage per Node
```bash
# Check raid storage usage
pvesm status --storage raid --node cdx-pve-01
pvesm status --storage raid --node cdx-pve-02
pvesm status --storage raid --node cdx-pve-03
```

### Template Verification
```bash
# Ensure all templates are accessible from each node
for node in cdx-pve-01 cdx-pve-02 cdx-pve-03; do
    echo "=== $node ==="
    ssh root@$node "qm list" | grep -E "2001|2002|2003|2009|2010|2011|2012"
done
```

---

## Troubleshooting

### Clone Failures

#### Template Not Found
```bash
# Error: template 2003 does not exist
# Solution: Verify template exists on NAS
pvesm list NAS

# If missing, create/restore template
```

#### Insufficient Storage
```bash
# Error: unable to create disk - no space left
# Solution: Check storage allocation
pvesm status --storage raid --node cdx-pve-01

# Free up space or add storage
```

#### Network Bridge Missing
```bash
# Error: bridge 'stk100' does not exist
# Solution: Create bridge on the target node
ssh root@cdx-pve-01 "brctl show | grep stk100"
```

### Performance Issues

#### Slow Clone Operations
- Check NAS network performance
- Verify NAS is not overloaded
- Consider staggering clone operations

#### High Storage I/O
- Linked clones read from templates frequently
- Ensure NAS has good performance
- Consider SSD-based NAS for templates

---

## Disaster Recovery

### Node Failure Scenarios

#### cdx-pve-01 Failure (Americas)
- **Impact:** 196 VMs offline (57% of infrastructure)
- **Sites affected:** HQ, Dallas, Malibu
- **Critical services:** 2 DCs, HQ web/app servers
- **Recovery:** Restore from backups to surviving nodes or replacement hardware

#### cdx-pve-02 Failure (Europe)
- **Impact:** 71 VMs offline (21% of infrastructure)
- **Sites affected:** Amsterdam
- **Critical services:** 1 DC, Europe WSUS, Amsterdam web/app
- **Recovery:** AD replication ensures domain continues; restore VMs when node returns

#### cdx-pve-03 Failure (Asia)
- **Impact:** 76 VMs offline (22% of infrastructure)
- **Sites affected:** Nagasaki
- **Critical services:** 1 DC, Asia-Pacific WSUS
- **Recovery:** AD replication ensures domain continues; restore VMs when node returns

### Template Storage (NAS) Failure
- **Impact:** Cannot create new VMs or clones
- **Existing VMs:** Continue running normally (data is local)
- **Recovery:** Restore NAS from backup or rebuild templates

---

## Best Practices

### 1. Template Management
- Keep templates up-to-date with patches
- Test template changes before mass deployment
- Maintain template documentation
- Version control for templates

### 2. Monitoring
- Monitor storage growth on each node
- Alert on high storage usage (>80%)
- Track clone operation times
- Monitor inter-node cluster communication

### 3. Capacity Planning
- Plan for 2-3x initial storage for linked clones
- Reserve 20% storage overhead per node
- Consider node expansion if load increases

### 4. Documentation
- Document custom configurations per VM
- Keep network diagram up-to-date
- Maintain change log for infrastructure

### 5. Testing
- Test backup/restore procedures regularly
- Verify node failover procedures
- Test cross-node VM migration (cold)
- Validate AD replication across all DCs

---

## Summary

**Cluster Configuration:**
- 3 nodes: cdx-pve-01, cdx-pve-02, cdx-pve-03
- Geographic distribution: Americas, Europe-Africa, Asia-Pacific
- 343 VMs total (196 + 71 + 76)
- Linked clones on local RAID storage
- Templates on shared NAS storage

**Deployment Strategy:**
1. Verify templates on NAS
2. Create network bridges on all nodes
3. Deploy DCs first (5 VMs)
4. Deploy infrastructure servers (43 VMs)
5. Deploy VIP workstations (3 VMs)
6. Deploy standard workstations (292 VMs)

**Storage:**
- NAS: Shared template storage (~200 GB)
- raid: Local VM disks per node (1-2 TB each)
- Linked clones for space efficiency

---

**Last Updated:** 2025-11-24  
**Framework:** CDX-E v2.0  
**Exercise:** CHILLED_ROCKET  
**Configuration Version:** 2.3 (Cluster-Enabled)

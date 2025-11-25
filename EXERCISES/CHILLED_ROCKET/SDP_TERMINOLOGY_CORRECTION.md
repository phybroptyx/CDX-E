# SDP Terminology Correction

## Corrected Definition

**SDP = Service Delivery Point (Edge Router)**

The SDP is the **edge router** that serves as the primary connection point between:
- The site's internal networks
- The ISP (CDX Internet)
- Other sites (via WAN/VPN)

---

## What SDP Is

**Service Delivery Point:**
- Primary edge router for the site
- ISP handoff point (where CDX Internet connects)
- BGP peering endpoint
- Site-to-site VPN termination
- First-hop router for all site traffic

---

## What SDP Is NOT

~~**Software-Defined Perimeter**~~ (This was incorrect)

The term SDP in this context does **NOT** refer to Zero Trust network architecture or software-defined security gateways.

---

## Boundary Networks - Corrected Purpose

The **Boundary networks** (stk101, 111, 116, 125, 133) host:

### Primary Components:
1. **SDP (Service Delivery Point)** - Edge Router
   - ISP connection (CDX Internet)
   - BGP routing
   - Site-to-site connectivity
   - Primary gateway

2. **Core Router** (if separate from SDP)
   - Internal routing
   - VLAN routing
   - Redundancy/HA pair with SDP

3. **Edge Firewall/Security Appliances**
   - Stateful packet inspection
   - IDS/IPS
   - Content filtering
   - VPN concentration

---

## Network Topology (Corrected)

```
                    Internet (CDX Internet)
                            ↓
                    ┌───────────────┐
                    │   ISP Router  │
                    │  (Provider)   │
                    └───────┬───────┘
                            │
    ┌───────────────────────▼────────────────────────┐
    │         BOUNDARY NETWORK (stk101)              │
    │                                                 │
    │  ┌─────────────────────────────────────────┐  │
    │  │ SDP (Service Delivery Point)            │  │
    │  │ • Edge Router                           │  │
    │  │ • BGP Peering with ISP                  │  │
    │  │ • Site Gateway                          │  │
    │  │ • NAT/PAT                               │  │
    │  └─────────────┬───────────────────────────┘  │
    │                │                               │
    │  ┌─────────────▼───────────────────────────┐  │
    │  │ Core Router (Optional - Redundancy)     │  │
    │  │ • Internal routing                      │  │
    │  │ • VLAN routing                          │  │
    │  │ • HA pair with SDP                      │  │
    │  └─────────────┬───────────────────────────┘  │
    │                │                               │
    │  ┌─────────────▼───────────────────────────┐  │
    │  │ Edge Firewall / Security                │  │
    │  │ • Stateful inspection                   │  │
    │  │ • IDS/IPS                               │  │
    │  │ • Content filtering                     │  │
    │  └─────────────┬───────────────────────────┘  │
    └────────────────┼───────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼────────┐       ┌───────▼─────────┐
│  DMZ (stk102)  │       │  Core Servers   │
│  • Web         │       │  (stk100)       │
│  • App (Public)│◄──────┤  • DCs          │
└────────────────┘       │  • File/DB      │
                         └─────────┬───────┘
                                   │
                         ┌─────────▼──────────┐
                         │  Department VLANs  │
                         │  (stk103-110)      │
                         └────────────────────┘
```

---

## SDP Configuration Example (VyOS)

### HQ Service Delivery Point (stk101)

```bash
# Interfaces
set interfaces ethernet eth0 address '66.218.183.2/26'
set interfaces ethernet eth0 description 'WAN - ISP (CDX Internet)'

set interfaces ethernet eth1 address '66.218.180.1/24'
set interfaces ethernet eth1 description 'LAN - Core Servers (stk100)'

set interfaces ethernet eth2 address '66.218.181.1/24'
set interfaces ethernet eth2 description 'LAN - DMZ (stk102)'

# BGP Configuration (ISP Peering)
set protocols bgp system-as 65001
set protocols bgp neighbor 66.218.183.1 remote-as 65000
set protocols bgp neighbor 66.218.183.1 description 'ISP - CDX Internet'
set protocols bgp neighbor 66.218.183.1 ebgp-multihop 2

# Advertise internal networks to ISP
set protocols bgp address-family ipv4-unicast network 66.218.180.0/22

# Default route via ISP
set protocols static route 0.0.0.0/0 next-hop 66.218.183.1

# NAT for outbound traffic
set nat source rule 100 outbound-interface 'eth0'
set nat source rule 100 source address '66.218.180.0/22'
set nat source rule 100 translation address 'masquerade'

# Firewall - WAN inbound
set firewall name WAN-TO-LAN default-action 'drop'
set firewall name WAN-TO-LAN rule 10 action 'accept'
set firewall name WAN-TO-LAN rule 10 state established 'enable'
set firewall name WAN-TO-LAN rule 10 state related 'enable'

# Allow specific inbound services to DMZ
set firewall name WAN-TO-DMZ default-action 'drop'
set firewall name WAN-TO-DMZ rule 10 action 'accept'
set firewall name WAN-TO-DMZ rule 10 protocol 'tcp'
set firewall name WAN-TO-DMZ rule 10 destination port '80,443'
set firewall name WAN-TO-DMZ rule 10 state new 'enable'

# Apply firewall
set interfaces ethernet eth0 firewall in name 'WAN-TO-LAN'
```

---

## Site-to-Site VPN (SDP to SDP)

### VPN Between HQ and Dallas SDPs

```bash
# HQ SDP (66.218.183.2) ↔ Dallas SDP (50.222.75.2)

# IPsec configuration on HQ SDP
set vpn ipsec esp-group ESP-DEFAULT compression 'disable'
set vpn ipsec esp-group ESP-DEFAULT lifetime '3600'
set vpn ipsec esp-group ESP-DEFAULT mode 'tunnel'
set vpn ipsec esp-group ESP-DEFAULT pfs 'dh-group19'
set vpn ipsec esp-group ESP-DEFAULT proposal 1 encryption 'aes256'
set vpn ipsec esp-group ESP-DEFAULT proposal 1 hash 'sha256'

set vpn ipsec ike-group IKE-DEFAULT key-exchange 'ikev2'
set vpn ipsec ike-group IKE-DEFAULT lifetime '28800'
set vpn ipsec ike-group IKE-DEFAULT proposal 1 dh-group '19'
set vpn ipsec ike-group IKE-DEFAULT proposal 1 encryption 'aes256'
set vpn ipsec ike-group IKE-DEFAULT proposal 1 hash 'sha256'

set vpn ipsec site-to-site peer 50.222.75.2 authentication mode 'pre-shared-secret'
set vpn ipsec site-to-site peer 50.222.75.2 authentication pre-shared-secret 'SecurePreSharedKey123'
set vpn ipsec site-to-site peer 50.222.75.2 ike-group 'IKE-DEFAULT'
set vpn ipsec site-to-site peer 50.222.75.2 local-address '66.218.183.2'
set vpn ipsec site-to-site peer 50.222.75.2 tunnel 1 esp-group 'ESP-DEFAULT'
set vpn ipsec site-to-site peer 50.222.75.2 tunnel 1 local prefix '66.218.180.0/22'
set vpn ipsec site-to-site peer 50.222.75.2 tunnel 1 remote prefix '50.222.72.0/22'
```

---

## Boundary Network IP Allocation

### Recommended /26 subnet allocation for each site boundary:

| Site | Boundary Network | Purpose | IP Example |
|------|-----------------|---------|------------|
| **HQ** | 66.218.183.0/26 | stk101 | .1 ISP, .2 SDP WAN, .3 SDP LAN, .4 Firewall |
| **Malibu** | 4.150.219.0/26 | stk111 | .1 ISP, .2 SDP WAN, .3 SDP LAN, .4 Firewall |
| **Dallas** | 50.222.75.0/26 | stk116 | .1 ISP, .2 SDP WAN, .3 SDP LAN, .4 Firewall |
| **Nagasaki** | 14.206.3.0/26 | stk125 | .1 ISP, .2 SDP WAN, .3 SDP LAN, .4 Firewall |
| **Amsterdam** | 37.74.127.0/26 | stk133 | .1 ISP, .2 SDP WAN, .3 SDP LAN, .4 Firewall |

### Example (HQ):
```
66.218.183.0/26 (stk101 - HQ Boundary)
├─ .1   : ISP Gateway (CDX Internet handoff)
├─ .2   : SDP WAN Interface (external)
├─ .3   : SDP LAN Interface (internal to core/DMZ)
├─ .4   : Edge Firewall (if separate appliance)
├─ .5   : Core Router (if separate from SDP)
├─ .6-.10 : Reserved for additional edge infrastructure
└─ .11-.62 : Available for future use
```

---

## Key Differences: SDP vs Core Router

| Feature | SDP (Service Delivery Point) | Core Router |
|---------|------------------------------|-------------|
| **Location** | Edge (ISP handoff) | Internal |
| **Primary Role** | ISP connectivity | Internal routing |
| **BGP** | Yes (external peers) | Optional (internal) |
| **NAT** | Yes (outbound) | Usually no |
| **Internet-facing** | Yes | No |
| **Firewall** | Basic ACLs | Not typically |
| **VPN** | Site-to-site termination | Usually no |

**Note:** In smaller sites, SDP and Core Router may be the same device. In larger sites, they are typically separate for redundancy and security.

---

## Summary

### Corrected Terminology:
- **SDP** = Service Delivery Point (Edge Router)
- **NOT** = Software-Defined Perimeter

### Boundary Networks Host:
1. SDP (Edge Router) - ISP connection point
2. Core Router (optional) - Internal routing
3. Edge Security (firewall, IDS/IPS)

### Network Flow:
```
Internet → ISP → SDP (Boundary) → Core Router → Firewall → Internal Networks
```

---

**Last Updated:** 2025-11-24  
**Correction:** SDP terminology updated to Service Delivery Point (Edge Router)  
**Framework:** CDX-E v2.0  
**Exercise:** CHILLED_ROCKET

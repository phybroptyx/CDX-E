# CDX-I Network Architecture – README

## Overview

The **Cyber Defense eXercise – Internet (CDX-I)** network is a fully isolated, self-contained emulation of the public Internet.  
Its purpose is to provide realistic global routing, peering, and multi-regional topology behavior without relying on any external connectivity.

CDX-I acts as the **“Internet core”** for all Enterprise, Red Team, SOC, and OPFOR networks within the exercise environment.  
It provides:

- Internet-like latency pathways  
- Multi-tier routing hierarchy  
- Global IP space simulation  
- Public routing protocols (OSPF-based in the lab)  
- Regional peering at simulated Internet Exchange Points (IXPs)  

This design allows Blue Teams, Red Teams, and SOCs to operate in an Internet-realistic environment—supporting malware C2 traffic, OSINT simulation, attack paths, enterprise external services, and realistic routing behavior.

## Routing Architecture

CDX-I is built using a **three-tier hierarchical routing model** inspired by real Internet backbone/IPX architecture:

### Tier 0 – Global Internet Core (Backbone)

Routers: `CORE-T0-R1`, `CORE-T0-R2`, `CORE-T0-R3`

These serve as the **global, continent-scale backbone** of the CDX-I environment.

Functions:
- Represent the world’s major Internet backbone carriers and transoceanic interconnects.
- Form a strict **OSPF Area 0** backbone.
- Provide transit connectivity between all regional Tier-1 IXPs.
- Contain clean, minimal routing—no customer / enterprise / local subnets.

### Tier 1 – Regional Internet Exchange Points (IXPs)

Routers: `IXP-T1-EQIX-1` through `IXP-T1-EQIX-10`

These emulate large regional IXPs, Tier-1 ISPs, or national gateways.

Functions:
- Provide interconnection between regional simulated ISPs, national-scale address blocks, enterprise public IP allocations.
- Aggregate many discontiguous provider blocks under a **single OSPF area per region**.
- Connect upstream to the global Tier-0 backbone.

Regional Area Mapping:

| Region / IXP      | Router Name     | OSPF Area |
|-------------------|------------------|-----------|
| London            | IXP-T1-EQIX-1    | Area 1    |
| Amsterdam         | IXP-T1-EQIX-2    | Area 2    |
| Sydney            | IXP-T1-EQIX-3    | Area 3    |
| Seattle           | IXP-T1-EQIX-4    | Area 4    |
| Toronto           | IXP-T1-EQIX-5    | Area 5    |
| Frankfurt         | IXP-T1-EQIX-6    | Area 6    |
| Vladivostok       | IXP-T1-EQIX-7    | Area 7    |
| Dubai             | IXP-T1-EQIX-8    | Area 8    |
| Rio de Janeiro    | IXP-T1-EQIX-9    | Area 9    |
| Seoul             | IXP-T1-EQIX-10   | Area 10   |

## OSPF Design Philosophy

### Backbone Area (Area 0)
- Implemented only on Tier-0 routers and their direct connections from Tier-1 routers.
- Represents global core connectivity.
- All other OSPF areas must attach to Area 0 through designated ABRs.

### Regional Areas (Areas 1–10)
- Each Tier-1 IXP uses a **unique non-zero OSPF area** representing an entire continental or national routing domain.
- Each area aggregates many IPv4 blocks representing carriers, cloud zones, gov networks, etc.

### Redistribution Rules
- No NAT or redistribution of enterprise RFC1918 space into CDX-I.
- Enterprises may advertise **summarized public allocations** only.

## Addressing Philosophy

CDX-I uses **valid real-world IPv4 prefixes** inside an isolated lab.

Key principles:
- Tier-0 uses real IXP/backbone space.
- Tier-1 uses large real-world regional allocations.
- Enterprises use simulated public ranges.
- No RFC1918 leaks into T0/T1.

## Router Roles Summary

### Tier 0 – Backbone
- Transit-only  
- OSPF Area 0  
- Minimal routing  

### Tier 1 – Regional IXPs
- ABR between Area 0 and Area X  
- Aggregates regional networks  
- No NAT  

## Conclusion

CDX-I provides a realistic global Internet simulation suitable for SOC training, malware analysis, and Red/Blue Team exercises.

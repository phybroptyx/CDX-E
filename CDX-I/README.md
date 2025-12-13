# CDX-I (Cyber Defense eXercise - Internet)

## Overview

The **CDX-I** component defines the virtual Internet backbone supporting all Cyber Defense eXercise (CDX) environments within the CDX-E project. It provides a realistic, multi-tiered network substrate that emulates Internet-scale routing, DNS hierarchy, global services, and upstream connectivity for all participating enterprise or adversary environments.

CDX-I exists as an independent, reusable Internet simulation layer. It does not represent any single organization; instead, it serves as the connective fabric through which exercise environments interact, exchange traffic, and experience realistic operational constraints.

---

## Objectives of CDX-I

CDX-I is designed to:

1. **Model a Layered Internet Topology**  
   Provide Tier-0 core routing, Tier-1 regional exchanges, and Tier-2 provider-level networks using structured addressing and hierarchical routing.

2. **Deliver Realistic Network Behavior**  
   Enable diverse traffic paths, asymmetric routing, and multi-hop packet flow that mimic enterprise-to-Internet communication.

3. **Provide Global Shared Services**  
   Operate neutral DNS, NTP, routing, and transit systems that do not belong to any enterprise or scenario, but which all depend upon.

4. **Enable Modular Exercise Integration**  
   Allow any exercise scenario—blue team, red team, or mixed—to attach their networks to CDX-I without modifying the backbone.

5. **Represent the “Internet Environment”**  
   Provide the adversarial noise floor, reconnaissance surface, and operational context necessary for modern cybersecurity training.

---

## Logical Architecture

CDX-I is built upon a three-tier design:

### Tier 0 — Core Backbone (OSPF Area 0)

The foundation of the simulated Internet.  
Responsibilities include:

- Backbone routing  
- Global DNS root and TLD services  
- Inter-region transit  
- Neutral monitoring or logging frameworks (optional)

Tier-0 nodes typically act as either high-availability core routers or transit switches that anchor the entire CDX topology.

### Tier 1 — Regional Internet Exchange Points

Tier-1 routers interconnect regions and serve as aggregation points for provider networks.  
They function as ABRs (Area Border Routers) and:

- Connect local regions to the core  
- Enforce separation between Tier-0 and downstream networks  
- Provide failover paths and distributed transit  

Each Tier-1 site represents a logical region rather than a specific geographic location.

### Tier 2 — Provider Edge (Service Delivery Points)

Tier-2 routers model:

- ISP PoPs  
- Customer-edge providers  
- Upstream connectivity for enterprises participating in an exercise  

Exercise networks attach to Tier-2, not directly to Tier-0 or Tier-1.

Tier-2 implements OSPF areas distinct from the backbone, allowing isolation, realistic route propagation, and training scenarios that depend on manipulated upstream connectivity.

---

## Services Hosted in CDX-I

Common services centralized within CDX-I may include:

### 1. Root & Authoritative DNS

- Replicated root name server infrastructure  
- Zone signing (optional)  
- Neutral authoritative zones for exercise resource records  

This provides an Internet-like DNS flow without requiring external connectivity.

### 2. NTP Services

- Highly available stratum servers  
- Syndicated to enterprise environments  

Ensures consistent clock synchronization for log correlation and detection pipelines.

### 3. Transit Routing

- OSPF (multi-area)  
- Optional BGP peering within Tier-0 or Tier-1  
- Structured prefix allocation  

Enables multi-hop routing and realistic traffic analysis.

### 4. Optional Global Sensors

Deployed only if required by the exercise design:

- Zeek  
- Suricata  
- Arkime  
- Flow monitors  

These sensors operate as *neutral* Internet-layer observatories, not enterprise-owned systems.

---

## Integration Model for Exercise Scenarios

Exercise deployments connect to CDX-I in a stable, controlled manner:

1. The scenario environment defines its **enterprise LAN(s)**.  
2. These LANs connect upstream to a **Tier-2 Service Delivery Point (SDP)**.  
3. CDX-I provides:  
   - DNS recursion → Core DNS  
   - Default routing → Tier-0  
   - Transit connectivity → Other exercise networks  
   - Optional adversarial background traffic  

The scenario does **not** modify CDX-I topology.  
Instead, it consumes upstream connectivity through designated attachment points, enabling modular and repeatable exercise design.

---

## Benefits of CDX-I

1. **Reusability**  
   CDX-I remains constant across exercises, enabling consistent training baselines.

2. **Isolation**  
   Scenario events never alter or disrupt the Internet backbone, maintaining environment integrity.

3. **Realism**  
   Provides an environment where attack paths, reconnaissance, misconfigurations, or outages behave as they would on the real Internet.

4. **Scalability**  
   Additional enterprises, regions, or adversary networks can be introduced without redesigning the backbone.

5. **Operational Separation**  
   Scenario controllers can deploy enterprise networks independently of the Internet architecture.

---

## Typical Repository Structure Within CDX-I

This folder typically contains:

- Router definitions  
- Network addressing plans  
- OSPF/BGP design documentation  
- DNS root/TLD configuration  
- Supporting scripts (deployment automation)  
- Optional topology diagrams  

This folder defines “the world outside the enterprise.”

---

## Deployment Considerations

- CDX-I should be deployed **before** any scenario networks.  
- Enterprises and adversary environments should rely on predefined Tier-2 entry points.  
- Routing changes must preserve backbone integrity; only scenario-specific Tier-2 or LAN changes should deviate.  
- DNS and NTP should be treated as authoritative infrastructure and must remain highly available.

---

## Conclusion

CDX-I is the strategic backbone supporting all CDX-E environments.  
It models the Internet as a stable, shared substrate on which enterprise networks, adversaries, and training scenarios operate. This layered approach ensures realism, scalability, and modularity while preserving the design separation essential for professional cyber defense exercises.

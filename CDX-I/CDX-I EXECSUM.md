# Executive Summary  
## CDX-I: Cyber Defense eXercise Internet

### Purpose

CDX-I (Cyber Defense eXercise Internet) is a fully simulated, isolated, and highly structured Internet architecture that serves as the foundational backbone for all environments deployed under the CDX-E project. It provides the routing, DNS hierarchy, time synchronization, transit networks, and upstream connectivity necessary to support realistic cybersecurity training at enterprise scale.

CDX-I enables exercises to take place within an Internet-like ecosystem—complete with multi-hop routing, authoritative DNS, distributed services, and multiple regional transit domains—while remaining fully offline and safe for experimentation.

---

### Strategic Objectives

1. **Provide a Realistic Internet Simulation**  
   CDX-I models the global Internet by using layered routing (OSPF areas), distributed DNS, and hierarchical service delivery, creating conditions nearly identical to production environments.

2. **Enable Scalable, Repeatable Cyber Exercises**  
   All scenarios, enterprises, and adversary networks attach to CDX-I without requiring changes to the backbone. This ensures consistency and reusability across exercises.

3. **Maintain Clear Separation of Concerns**  
   CDX-I represents “the world outside the enterprise.”  
   Enterprises, adversarial actors, and training scenarios function as customers of this simulated Internet, not as part of it.

4. **Support Advanced Training and Research**  
   By enabling realistic routing behavior, adversary infrastructure, global sensors, and monitored traffic flows, CDX-I provides the conditions necessary for:

   - Blue team defensive operations  
   - Red team offensive campaigns  
   - SOC analysis and forensics  
   - Threat detection, modeling, and tool testing  
   - Multi-domain cyber simulations  

---

### Architectural Overview

CDX-I uses a **three-tier model**:

1. **Tier 0 — Core Backbone**  
   - OSPF Area 0  
   - Simulated DNS root & TLD servers  
   - Core NTP  
   - High-availability transit routers  

2. **Tier 1 — Regional Internet Exchange Points**  
   - Area Border Routers (ABRs) bridging Area 0 ↔ Regional Areas  
   - Represent major global Internet hubs  
   - Aggregate routing and distribute services  

3. **Tier 2 — Provider Edge / Service Delivery Points (SDPs)**  
   - Function as ISPs for exercises  
   - Provide upstream Internet, DNS, NTP, and routing  
   - Serve as attachment points for enterprise and scenario networks  

This three-tier design allows large and complex environments to be orchestrated with clarity and precision.

---

### Key Capabilities

- **Fully isolated Internet emulation**  
- **Distributed DNS hierarchy (root → TLD → resolver)**  
- **Consistent NTP infrastructure for synchronized logs and detection tools**  
- **Multi-area routing for realistic network behavior**  
- **Support for enterprise networks, adversary infrastructure, and scenario environments**  
- **Global observability via optional neutral sensors**  
- **Scalable, modular design allowing new domains and networks to be added without disruption**  

---

### Benefits

- **Operational Realism**  
  CDX-I provides the same constraints, routing patterns, and service dependencies seen in real-world enterprises.

- **Training Fidelity**  
  Enables students and operators to experience the technical and analytical challenges of Internet-connected environments.

- **Safe Isolation**  
  No connectivity to the real Internet; all traffic is contained, controlled, and observable.

- **Scenario Flexibility**  
  Multiple exercises, networks, and threat actors can coexist, attach, detach, and evolve independently.

---

### Conclusion

CDX-I is a cornerstone of the CDX-E project—a purpose-built Internet simulation delivering the fidelity required for professional-grade cyber defense training. Its structured architecture, service hierarchy, and integration model create an environment where enterprise operations, threat behavior, and defensive analysis can be practiced at scale without risk to real-world systems.

It is the world in which the Cyber Defense eXercise unfolds—crafted with precision, designed for resilience, and capable of expanding as new challenges arise.

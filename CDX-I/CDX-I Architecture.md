# CDX-I Architecture Companion Document

## 1. Purpose

This document provides an architectural overview of the **CDX-I (Cyber Defense eXercise Internet)** environment and expands upon the high-level README by:

- Describing the **logical**, **physical**, and **service-layer** design of CDX-I.
- Explaining the **routing model** and **OSPF area hierarchy**.
- Defining how **enterprise** and **scenario** networks integrate with CDX-I.
- Providing references to associated **architecture diagrams** for visual support.

CDX-I is a **virtual, closed Internet simulation** that underpins all Cyber Defense eXercise (CDX) environments within the CDX-E project. It is designed to be reusable, scenario-agnostic, and operationally realistic.

---

## 2. Scope

This document covers:

- CDX-I core design and architecture.
- Core routing and OSPF area strategy.
- DNS, NTP, and other shared services.
- Integration patterns for enterprise and scenario environments.
- Operational and security considerations.

It does **not** define the internal design of any specific enterprise or scenario environment; those are documented separately and simply consume CDX-I as their upstream “Internet.”

---

## 3. Reference Diagrams

The following `.drawio` diagrams are associated with this document:

- **Physical Topology**
  - `diagrams/cdxi_physical_topology.drawio`
- **Geographical Tier-1 Layout**
  - `diagrams/cdxi_geographical_layout.drawio`
- **Service-Layer Architecture**
  - `diagrams/cdxi_service_layer.drawio`
- **Whitepaper-Style Overview**
  - `diagrams/cdxi_whitepaper_style.drawio`
- **Annotated Engineering Diagram**
  - `diagrams/cdxi_engineering_annotated.drawio`

These diagrams provide complementary perspectives: executive, logical, service-layer, geographical, physical, and engineering-level.

---

## 4. Architectural Overview

At a high level, CDX-I is structured into three layers:

1. **Tier 0 – Core Backbone (OSPF Area 0)**  
   - Simulated global Internet core.
   - Hosts DNS root/TLD, core NTP, and backbone routing.
   - Does not belong to any particular organization or scenario.

2. **Tier 1 – Regional Internet Exchange Points (IXPs)**  
   - Connect regions to the Tier-0 backbone via ABRs.
   - Represent major “regional Internet hubs.”
   - Segment routing into multiple OSPF areas.

3. **Tier 2 – Provider Edge / Service Delivery Points (SDPs)**  
   - Represent ISPs or provider edge routers.
   - Provide attachment points for **enterprise** and **scenario** networks.
   - Enforce separation between customer environments.

This layered design delivers:

- Realistic, multi-hop routing behavior.
- Separation of concerns between “Internet” and “customer networks.”
- Consistent upstream connectivity for all exercise environments.

For a high-level conceptual view, see:  
**`cdxi_whitepaper_style.drawio`**

---

## 5. Logical Architecture

### 5.1 Tier 0 – CDX-I Backbone

Tier 0 is modeled as an **OSPF Area 0** backbone, consisting of:

- **Core Routers (CR-x)**  
  - Participate in OSPF Area 0.
  - Optionally terminate BGP sessions with “transit” representations or aggregated prefixes.
  - Provide redundant paths through the virtual Internet core.

- **Core Services:**
  - **DNS Root and TLD Cluster**  
    - Simulated root servers and authoritative TLD servers.
    - May be implemented as one or more VMs with anycast-style addresses (logically).
  - **Core NTP Servers**  
    - Provide stable, canonical time sources to Tier-1 NTP aggregators.
  - **Optional Global Sensors**  
    - Neutral monitoring (e.g., Zeek, Suricata, flow collectors) observing “Internet” traffic patterns.

Tier 0 is **scenario-agnostic** and must remain stable across exercises.

For a detailed engineering representation, see:  
**`cdxi_engineering_annotated.drawio`**

---

### 5.2 Tier 1 – Regional ABRs / IXPs

Tier 1 consists of **regional ABR routers** that join Area 0 to regional areas:

- **ABR-A**: Connects **Area 0** to **Area 10** (Region A).
- **ABR-B**: Connects **Area 0** to **Area 20** (Region B).
- **ABR-C**: Connects **Area 0** to **Area 30** (Region C).

Each region represents a logical geography (e.g., Americas, EMEA, Asia-Pacific), not a specific real-world location.

Responsibilities:

- Enforce clear **area boundaries** between the backbone and regions.
- Aggregate and summarize routes from Tier-2 providers upward.
- Provide diversified paths for redundancy and asymmetric routing.

For a region-centric, geography-like view, see:  
**`cdxi_geographical_layout.drawio`**

---

### 5.3 Tier 2 – Provider Edge / Service Delivery Points (SDPs)

Tier 2 is where **enterprise** and **scenario** environments attach to CDX-I:

- **SDP-A1** (Area 10) – Provider edge router / ISP A.
- **SDP-B1** (Area 20) – Provider edge router / ISP B.
- **SDP-C1** (Area 30) – Provider edge router / ISP C.
- Additional SDPs may be introduced as needed.

Each SDP:

- Acts as the **default gateway to the Internet** for one or more “customer” environments.
- Provides access to:
  - Recursive DNS (which ultimately reaches Tier-0 root/TLD).
  - NTP (distributed from Tier-0 core NTP).
  - Routing to all other networks attached to CDX-I.

From the perspective of enterprise or scenario networks, the SDP is “their ISP.”

For overall Tier-0/Tier-1/Tier-2 flows, see:  
**`cdxi_service_layer.drawio`** and **`cdxi_engineering_annotated.drawio`**

---

## 6. Physical Architecture

The **physical (or virtual host-level) architecture** is designed around a virtualization cluster (e.g., Proxmox, vSphere) and a core switch or fabric.

Key elements:

- **Core Switch / Fabric**
  - Aggregates physical interfaces from virtualization hosts and core routers.
  - Provides the underlying L2 segments for management, transit, and service networks.

- **Virtualization Cluster**
  - One or more hypervisor hosts forming a cluster.
  - Runs CDX-I service VMs such as:
    - DNS root/TLD nodes.
    - NTP servers.
    - Global sensors (if deployed).
    - Supporting management systems.

- **Routers**
  - May be physical appliances or virtual routers (e.g., VyOS, other platforms).
  - Connected to transit VLANs / networks that correspond to Tier-0, Tier-1, and Tier-2 segments.

The goal is to keep **physical topology** relatively simple and stable while enabling complex logical topologies via routing and virtual networks.

For the host-level and cluster-centric view, see:  
**`cdxi_physical_topology.drawio`**

---

## 7. Services & Infrastructure

### 7.1 DNS

CDX-I provides a full DNS hierarchy:

- **Root Servers (Tier 0)**  
  - Simulated root zone and hint file.
  - May host multiple root-like instances for redundancy.

- **TLD / Authoritative Servers (Tier 0)**  
  - Host zones representing:
    - Enterprise domains.
    - Exercise-related domains.
    - Generic “Internet background” domains as needed.

- **Recursive Resolvers (Tier 1)**  
  - Per-region recursive DNS servers.
  - Enterprise/scenario networks are configured to use these resolvers (often at the SDP or regional level).

### 7.2 NTP

- **Core NTP Servers (Tier 0)**  
  - Serve as authoritative time sources within CDX-I.
- **Regional NTP Distributors (Tier 1)**  
  - Optionally deployed to fan out time services regionally.
- **Consumer Networks (Tier 2 and below)**  
  - Enterprise and scenario systems sync directly or indirectly to CDX-I NTP.

Consistent time is critical for correlation across logs, detection tools, and forensic workflows.

### 7.3 Monitoring & Sensors (Optional)

CDX-I can host neutral “Internet-level” sensors:

- Network IDS / traffic analyzers (Zeek, Suricata).
- Full-packet capture (Arkime, etc.).
- NetFlow/IPFIX collectors.

These are positioned to observe:

- Inter-regional traffic.
- Traffic between enterprises.
- Background/noise traffic injected into CDX-I.

This allows exercise staff and advanced students to analyze “Internet traffic” as part of training.

---

## 8. Routing Design

### 8.1 OSPF Area Design

The OSPF design uses:

- **Area 0** – CDX-I Backbone:
  - Core routers (CR-1, CR-2, etc.).
  - Possibly core DNS/NTP interfaces.

- **Regional Areas** (example mapping):
  - Area 10 – Region A (ABR-A ↔ SDPs in Region A).
  - Area 20 – Region B (ABR-B ↔ SDPs in Region B).
  - Area 30 – Region C (ABR-C ↔ SDPs in Region C).

This design:

- Keeps the backbone stable and small.
- Maintains clear hierarchy and summarization boundaries.
- Allows scaling by adding more areas and ABRs as needed.

### 8.2 Route Summarization & Control

- ABRs summarize **downstream prefixes** toward Area 0 where appropriate.
- SDPs often advertise a summarized set of customer prefixes toward their ABR.
- CDX-I core may inject “default route” or aggregate “Internet-like” prefixes toward SDPs.

Careful use of summarization ensures CDX-I remains scalable and manageable even as many enterprise/scenario networks are added.

---

## 9. Integration Patterns

Enterprise and scenario environments are **customers** of CDX-I and connect via SDPs.

Typical pattern:

1. Scenario or enterprise defines one or more **edge routers/firewalls**.
2. These edge devices establish **L3 adjacency** to a designated **SDP**:
   - Static routing or dynamic routing (e.g., OSPF Area X, BGP) may be used.
   - The SDP becomes the “upstream ISP” for that tenant.
3. The scenario/enterprise configures:
   - DNS servers pointing at CDX-I recursive resolvers.
   - NTP sources pointing at CDX-I NTP.
   - Default route pointing upstream to the SDP.

This approach:

- Keeps CDX-I unchanged when new scenarios are added.
- Allows each environment to be brought online or offline independently.
- Facilitates controlled experimentation with upstream failures, route manipulation, or DNS issues.

For examples of how multiple consumers attach to SDPs, see:  
**`cdxi_engineering_annotated.drawio`** and **`cdxi_service_layer.drawio`**

---

## 10. Security & Isolation Considerations

- **CDX-I is fully isolated** from the real Internet:
  - No physical or logical connectivity to external networks unless explicitly and carefully configured.
- **Segmentation:**
  - Clear separation between:
    - CDX-I core (Tier 0).
    - Regional transit domains (Tier 1).
    - Customer/tenant segments (Tier 2 and downstream).
- **Policy Enforcement:**
  - SDPs act as choke points where security policies, traffic shaping, or capture can be applied.
  - Enterprise environments may implement their own security stack behind their edge.

This ensures that even while CDX-I behaves like the Internet, it remains a **controlled, safe training environment**.

---

## 11. Deployment Order & Operational Notes

### 11.1 Recommended Deployment Order

1. **Core Infrastructure (Tier 0):**
   - Deploy core routers.
   - Establish OSPF Area 0 adjacency.
   - Stand up DNS root/TLD and core NTP.

2. **Regional Infrastructure (Tier 1):**
   - Deploy ABRs (Region A/B/C, etc.).
   - Configure OSPF areas (e.g., 10, 20, 30).
   - Stand up regional recursive DNS and NTP distribution if used.

3. **Provider Edge (Tier 2):**
   - Deploy SDPs / ISP PoPs.
   - Connect SDPs to ABRs (OSPF/BGP).
   - Define customer-facing interfaces or VLANs.

4. **Consumers (Enterprises / Scenarios):**
   - Deploy edge routers/firewalls.
   - Connect to SDPs.
   - Configure default routes, DNS, NTP, and security stack.

### 11.2 Operational Guidance

- CDX-I should be **brought online before exercises** and remain stable throughout.
- Scenario/enterprise failures or reconfigurations should **not** compromise the backbone.
- Changes to Tier 0 and Tier 1 should be rare and carefully controlled.

---

## 12. Future Enhancements

Potential enhancements to CDX-I include:

- Additional regions and areas (e.g., Area 40, Area 50).
- MPLS or segment routing overlays for more advanced exercises.
- Simulated content delivery networks and large-scale service providers.
- Advanced traffic generation for realistic Internet “background noise.”
- Integration with SOC tools as “Internet-facing sensors.”

These enhancements can be added incrementally without changing the fundamental three-tier model.

---

## 13. Conclusion

CDX-I provides a **robust, modular, and realistic Internet simulation** for the CDX-E ecosystem. By separating:

- **Backbone routing (Tier 0),**
- **Regional exchange (Tier 1),** and
- **Provider edge / customer access (Tier 2),**

the environment enables repeatable, scalable, and deeply realistic cyber defense exercises.

The diagrams and structure defined here should serve as the canonical reference for future expansions and for any team that needs to understand how “the Internet” works inside the CDX-E universe.


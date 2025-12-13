# CDX-E DNS Infrastructure - Architecture Comparison

**Date:** December 10, 2024  
**Purpose:** Compare centralized vs. geographic distribution architectures

---

## Quick Decision Guide

**Choose CENTRALIZED (Original) if:**
- ✓ Limited Docker host resources
- ✓ Simpler deployment preferred
- ✓ Training focuses on DNS protocol, not infrastructure
- ✓ All hosts on same physical network

**Choose GEOGRAPHIC (Recommended) if:**
- ✓ Multiple Docker hosts available
- ✓ Training includes infrastructure failures
- ✓ Geographic distribution matters for realism
- ✓ Want realistic failure domain separation

---

## Architecture Comparison

### Centralized Architecture (Version 2.0)

```
Docker Host 1: 23 containers
├── 13 Root Servers (all roots)
├── 8 TLD Primaries (all TLDs)
└── 2 TLD Secondaries (.com, .net)

Docker Host 2: 6 containers
└── 6 TLD Secondaries (.org, .edu, .io, .gov, .mil, .mrvl)

Docker Host 3: 1 container
└── Control/Monitoring
```

**Characteristics:**
- Root servers logically distributed (via IPs) but physically centralized
- All primary infrastructure on one host
- Simpler to deploy and manage
- Single point of failure (Host 1)

### Geographic Architecture (Version 3.0)

```
Docker Host 1 (Americas): 19 containers
├── 9 Root Servers (EQIX4 Seattle, EQIX5 Toronto)
├── 8 TLD Primaries (all TLDs)
└── 2 TLD Secondaries (.com, .net)

Docker Host 2 (Europe): 9 containers
├── 3 Root Servers (EQIX1 London, EQIX6 Frankfurt)
└── 6 TLD Secondaries (.org, .edu, .io, .gov, .mil, .mrvl)

Docker Host 3 (Asia-Pacific): 2 containers
├── 1 Root Server (EQIX10 Seoul)
└── Control/Monitoring
```

**Characteristics:**
- Root servers physically distributed across hosts
- True geographic separation
- Realistic failure domains
- Better load distribution

---

## Feature Comparison Matrix

| Feature | Centralized | Geographic |
|---------|-------------|------------|
| **Container Count** | 23 + 6 + 1 = 30 | 19 + 9 + 2 = 30 |
| **Root Server Distribution** | Logical only | Physical + Logical |
| **TLD Primary Location** | Host 1 only | Host 1 only |
| **TLD Secondary Distribution** | Host 1 (2) + Host 2 (6) | Host 1 (2) + Host 2 (6) |
| **Geographic Realism** | Low (IP-based) | High (physical) |
| **Failure Domains** | 1 critical host | 3 independent regions |
| **Load Distribution** | Unbalanced (23/6/1) | Balanced (19/9/2) |
| **Deployment Complexity** | Lower | Moderate |
| **Training Value** | Good | Excellent |
| **Zone File Distribution** | Host 1 only | Host 1 only |
| **Inter-Host Dependencies** | Zone transfers | Zone transfers |

---

## Deployment Complexity

### Centralized Architecture

**Pros:**
- ✅ 23 containers fit on one powerful host
- ✅ Simpler Docker Compose files
- ✅ Less inter-host traffic
- ✅ Easier troubleshooting

**Cons:**
- ❌ Host 1 is single point of failure
- ❌ All eggs in one basket
- ❌ Limited geographic training scenarios
- ❌ Poor resource distribution

**Best For:**
- Small to medium CDX exercises
- Limited Docker infrastructure
- Focus on DNS protocol training
- Simplified deployment requirements

### Geographic Architecture

**Pros:**
- ✅ True physical separation
- ✅ Realistic failure scenarios
- ✅ Better load distribution
- ✅ Independent failure domains
- ✅ Geographic training exercises

**Cons:**
- ❌ More complex to deploy
- ❌ Requires 3 well-configured Docker hosts
- ❌ More network dependencies
- ❌ More troubleshooting points

**Best For:**
- Large-scale CDX exercises
- Multiple Docker hosts available
- Infrastructure-focused training
- Realistic geographic scenarios

---

## Training Scenario Comparison

### Centralized Architecture Scenarios

**Scenario 1: Host 1 Failure**
- Impact: CATASTROPHIC
- Result: 13 roots + 8 primaries + 2 secondaries lost
- Training Value: Limited (too severe)

**Scenario 2: Host 2 Failure**
- Impact: Minor
- Result: 6 secondaries lost
- Training Value: Moderate (shows secondary importance)

**Scenario 3: Network Partition**
- Impact: Zone transfers fail
- Result: Secondaries can't refresh
- Training Value: Good (tests monitoring)

### Geographic Architecture Scenarios

**Scenario 1: Americas Failure (Host 1)**
- Impact: CRITICAL
- Result: 9 roots + 8 primaries lost, but 4 roots remain
- Training Value: Excellent (partial outage)

**Scenario 2: Europe Failure (Host 2)**
- Impact: MODERATE
- Result: 3 roots + 6 secondaries lost
- Training Value: Excellent (geographic impact)

**Scenario 3: Asia-Pacific Failure (Host 3)**
- Impact: LOW
- Result: 1 root + monitoring lost
- Training Value: Good (minimal impact demonstration)

**Scenario 4: Transatlantic Partition**
- Impact: MODERATE
- Result: Zone transfers fail, zones age
- Training Value: Excellent (network partition)

**Scenario 5: Regional DDoS**
- Impact: TARGETED
- Result: One region degraded, others unaffected
- Training Value: Excellent (regional attack)

**Winner:** Geographic Architecture (5 scenarios vs. 3, more realistic)

---

## Resource Requirements

### Centralized Architecture

**Docker Host 1:**
- vCPUs: 4-6
- RAM: 8-12 GB
- Storage: 100 GB
- Network: High bandwidth

**Docker Host 2:**
- vCPUs: 2
- RAM: 4 GB
- Storage: 50 GB
- Network: Moderate bandwidth

**Docker Host 3:**
- vCPUs: 1
- RAM: 2 GB
- Storage: 20 GB
- Network: Low bandwidth

**Total:** 7-9 vCPUs, 14-18 GB RAM

### Geographic Architecture

**Docker Host 1:**
- vCPUs: 4
- RAM: 8 GB
- Storage: 100 GB
- Network: High bandwidth

**Docker Host 2:**
- vCPUs: 3
- RAM: 6 GB
- Storage: 75 GB
- Network: Moderate bandwidth

**Docker Host 3:**
- vCPUs: 1
- RAM: 2 GB
- Storage: 20 GB
- Network: Low bandwidth

**Total:** 8 vCPUs, 16 GB RAM

**Winner:** Tie (similar requirements, better distributed)

---

## Deployment Time

### Centralized Architecture

**Phase 1:** Extract archives - 5 minutes
**Phase 2:** Create Docker Compose - 30 minutes
**Phase 3:** Deploy containers - 15 minutes
**Phase 4:** Test & verify - 30 minutes

**Total:** ~80 minutes

### Geographic Architecture

**Phase 1:** Extract archives - 5 minutes
**Phase 2:** Create Docker Compose - 45 minutes (3 hosts)
**Phase 3:** Deploy containers - 20 minutes
**Phase 4:** Test & verify - 45 minutes (inter-host)

**Total:** ~115 minutes

**Winner:** Centralized (35 minutes faster)

---

## Maintenance Complexity

### Centralized Architecture

**Zone Updates:**
- Update files on Host 1 only
- Reload primaries
- Secondaries auto-refresh

**Container Updates:**
- Most work on Host 1
- Minimal work on Host 2/3

**Monitoring:**
- Focus on Host 1 primarily
- Host 2/3 secondary priority

**Winner:** Centralized (simpler maintenance)

### Geographic Architecture

**Zone Updates:**
- Update files on Host 1 only
- Reload primaries
- Secondaries auto-refresh
- Verify across 3 hosts

**Container Updates:**
- Work distributed across 3 hosts
- More coordination required

**Monitoring:**
- Monitor all 3 hosts equally
- Inter-host connectivity critical

**Winner:** Centralized (simpler)

---

## Blue Team Training Value

### Centralized Architecture

**Skills Trained:**
- DNS protocol understanding ✓✓✓
- Zone transfer mechanics ✓✓✓
- Query analysis ✓✓✓
- Primary/secondary relationships ✓✓✓
- Network forensics ✓✓
- Geographic distribution concepts ✓
- Infrastructure failures ✓

**Score:** 7/10

### Geographic Architecture

**Skills Trained:**
- DNS protocol understanding ✓✓✓
- Zone transfer mechanics ✓✓✓
- Query analysis ✓✓✓
- Primary/secondary relationships ✓✓✓
- Network forensics ✓✓✓
- Geographic distribution concepts ✓✓✓
- Infrastructure failures ✓✓✓
- Cascade failure analysis ✓✓✓
- Regional attack detection ✓✓✓
- Cross-region monitoring ✓✓

**Score:** 10/10

**Winner:** Geographic Architecture (significantly more training value)

---

## Migration Path

### From Centralized to Geographic

**Can you migrate?** Yes

**Steps:**
1. Deploy geographic archives on new hosts
2. Configure Docker Compose for geographic distribution
3. Test in parallel with centralized
4. Cut over when confident
5. Decommission centralized

**Time:** 2-3 hours

**Risk:** Low (can run both simultaneously)

### From Geographic to Centralized

**Can you migrate?** Yes

**Steps:**
1. Deploy centralized archives
2. Simpler Docker Compose configuration
3. Test and verify
4. Cut over
5. Decommission geographic

**Time:** 1-2 hours

**Risk:** Low (downgrade is straightforward)

**When to do it:** If geographic proves too complex or resources are insufficient

---

## Recommendations by Use Case

### Small CDX Exercise (1-2 days, 20-50 participants)

**Recommendation:** Centralized Architecture

**Reasoning:**
- Simpler deployment
- Faster setup
- Adequate for protocol training
- Less infrastructure to manage

### Medium CDX Exercise (3-5 days, 50-100 participants)

**Recommendation:** Geographic Architecture

**Reasoning:**
- Better training scenarios
- More realistic infrastructure
- Justifies complexity investment
- Teaches advanced concepts

### Large CDX Exercise (1+ week, 100+ participants)

**Recommendation:** Geographic Architecture (Strongly)

**Reasoning:**
- Training value critical at this scale
- Infrastructure realism expected
- Advanced scenarios required
- Worth the deployment complexity

### Production Cyber Range

**Recommendation:** Geographic Architecture

**Reasoning:**
- Maximum realism
- Reusable infrastructure
- Comprehensive training capability
- Long-term investment justified

---

## File Size Comparison

### Centralized Archives

- docker-1.tar.gz: 6.9 KB (23 containers)
- docker-2.tar.gz: 973 bytes (6 containers)
- docker-3.tar.gz: 659 bytes (1 container)

**Total:** ~8.5 KB

### Geographic Archives

- docker-1-GEOGRAPHIC.tar.gz: 6.8 KB (19 containers)
- docker-2-GEOGRAPHIC.tar.gz: 2.6 KB (9 containers)
- docker-3-GEOGRAPHIC.tar.gz: 2.5 KB (2 containers)

**Total:** ~12 KB

**Winner:** Similar size (both very compact)

---

## Final Recommendation

### For Tony Stark / CHILLED_ROCKET Exercise

**RECOMMENDED:** Geographic Architecture (Version 3.0)

**Rationale:**
1. ✅ You have 3 Docker hosts available
2. ✅ CHILLED_ROCKET is a flagship exercise
3. ✅ Maximum training value desired
4. ✅ Resources justify complexity
5. ✅ Geographic realism enhances immersion
6. ✅ Better aligns with 343-VM enterprise scale

**The geographic architecture provides the training depth and infrastructure realism that matches the sophistication of your overall CDX-E framework.**

---

## Version History

**Version 1.0** (Deprecated)
- IP allocation errors
- Not recommended

**Version 2.0** (Centralized)
- Fixed IP allocations
- Centralized deployment
- Good for simple deployments

**Version 3.0** (Geographic) ⭐ RECOMMENDED
- Fixed IP allocations
- Geographic distribution
- Maximum training value
- Best for CHILLED_ROCKET

---

**Both architectures are deployment-ready. Choose based on your priorities: simplicity vs. realism.**

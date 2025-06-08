# Log Aggregation Implementation Plan

## Overview
Implement centralized log aggregation for the K3s homelab cluster using Loki and Grafana Alloy, integrating with existing Prometheus/Grafana monitoring stack.

## Architecture
```
K3s Pods/Containers → Grafana Alloy (DaemonSet) → Loki → Grafana (existing)
```

**Note:** Grafana Alloy has replaced Promtail as the recommended log collection agent. Promtail is considered feature complete, and future development for log collection will be in Grafana Alloy.

## Implementation Plan

### Phase 1: Loki Deployment
**Chart Structure:** `charts/loki/`
- **Namespace:** `monitoring` (existing namespace from kube-prometheus-stack)
- **Helm Chart:** Grafana Loki (official)
- **Storage:** Longhorn PVC for persistence (no host paths)
- **Pattern:** Similar to kube-prometheus-stack with overlays for ingress

**Files to Create:**
```
charts/loki/
├── fleet.yaml          # Fleet deployment config
├── values.yaml         # Base Helm values with Longhorn PVC config
└── overlays/dev/
    ├── kustomization.yaml
    └── ingress.yaml    # Loki UI ingress (loki.moria-lab.com)
```

**Key Configuration:**
- Single binary mode for homelab simplicity
- Longhorn storage with 2-replica HA
- Retention policy (30 days default)
- Integration with existing cert-manager

### Phase 2: Grafana Alloy Deployment
**Chart Structure:** `charts/alloy/`
- **Namespace:** `monitoring` (existing namespace from kube-prometheus-stack)
- **Helm Chart:** Grafana Alloy (official)
- **Pattern:** DaemonSet for log collection across all nodes

**Files to Create:**
```
charts/alloy/
├── fleet.yaml          # Fleet deployment config
└── values.yaml         # DaemonSet config with Loki endpoint
```

**Key Configuration:**
- DaemonSet deployment on all K3s nodes
- Longhorn PVC storage (no host path mounts)
- Kubernetes service discovery for log collection
- Labels for pod/namespace identification
- Integration with Loki via internal cluster communication

### Phase 3: Grafana Integration
**Existing Setup Enhancement:**
- Add Loki datasource to existing Grafana
- Pre-configured dashboards for log exploration

## Technical Specifications

### Loki Configuration
- **Storage Backend:** Filesystem (Longhorn PVC)
- **Chunk Store:** Filesystem
- **Index Store:** BoltDB
- **Retention:** 30 days
- **Limits:** 
  - Max query length: 12h
  - Max streams per user: 10000
  - Max entries per query: 5000

### Grafana Alloy Configuration
- **Target Discovery:** Kubernetes API
- **Log Collection:** Container runtime integration via Kubernetes API
- **Storage:** Longhorn PVC for agent persistence (no host paths)
- **Labels:** 
  - `job`, `namespace`, `pod`, `container`
  - `node`, `app`, `component`

### Network & Security
- **Loki Service:** ClusterIP with ingress
- **Alloy → Loki:** Internal cluster communication
- **TLS:** cert-manager with moria-lab-cert
- **Access:** Grafana UI integration + direct Loki UI

## Resource Requirements
- **Loki:** 
  - CPU: 500m request, 1 limit
  - Memory: 1Gi request, 2Gi limit
  - Storage: 25Gi Longhorn PVC
- **Grafana Alloy:** 
  - CPU: 100m request, 200m limit
  - Memory: 128Mi request, 256Mi limit
  - Storage: 10Gi Longhorn PVC (agent persistence)

## Integration Points
1. **Existing Monitoring:** Grafana datasource configuration (monitoring namespace)
2. **Storage:** Longhorn for both Loki and Alloy persistence
3. **Ingress:** Traefik with cert-manager SSL
4. **GitOps:** Fleet auto-deployment from charts/

## Testing Strategy
**Manual verification by user:**
1. Deploy Loki and verify storage/ingress accessibility
2. Deploy Grafana Alloy and verify log ingestion to Loki
3. Configure Grafana datasource for Loki
4. Validate log queries and dashboards functionality
5. Verify log retention and rotation policies

## Expected Outcomes
- Centralized log aggregation for all K3s workloads
- Integration with existing Grafana for unified observability
- Automated deployment via GitOps (Fleet)
- High availability with Longhorn storage
- Secure access via existing cert-manager setup

## Follow-up Enhancements - TODO Later
- Log-based alerting rules
- Custom dashboards for home automation apps
- Log aggregation from infrastructure VMs (Ansible integration)
- Long-term storage optimization
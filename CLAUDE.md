# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Infrastructure Architecture

This homelab follows a layered Infrastructure-as-Code approach:

**Proxmox VE** → **Packer** (VM templates) → **Terraform** (VM provisioning) → **Ansible** (configuration) → **K3s HA Cluster** → **Fleet GitOps** (application deployment)

### VM Classes and Resource Allocation

- **Ella Class**: 4 CPU cores, 4GB RAM - Used for K3s master nodes and critical workers (VM IDs: 101-104)
- **Elliot Class**: 6 CPU cores, 16GB RAM - Used for K3s agent nodes running workloads (VM ID: 120)

The cluster runs K3s in HA mode with embedded etcd across 3 control plane nodes plus 2 agent nodes.

## Common Command Workflows

### Packer VM Template Creation
```bash
# Validate template configuration
packer validate -var-file='../credentials.pkr.hcl' ubuntu-server-noble.pkr.hcl

# Build VM template (run from template directory)
packer build -var-file='../credentials.pkr.hcl' ubuntu-server-noble.pkr.hcl
```

### Terraform Infrastructure Provisioning
```bash
# Initialize and apply infrastructure
terraform init
terraform plan
terraform apply -auto-approve
```

Uses the `proxmox_vms` module to create VMs from Packer golden images with cloud-init configuration.

### Ansible Configuration Management
```bash
# Test connectivity
ansible -i hosts servers -m ping --user serveradmin

# Available playbooks
ansible-playbook -i hosts playbooks/apt.yml
ansible-playbook -i hosts playbooks/docker-setup.yml
ansible-playbook -i hosts playbooks/qemu-agent.yml
ansible-playbook -i hosts playbooks/reboot.yml
ansible-playbook -i hosts playbooks/reboot-required.yml
```

### Kubernetes Cluster Information
```bash
# List all pods across all namespaces
kubectl get pods --all-namespaces

# Get pod details in specific namespace
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>  # Follow logs

# Get services and endpoints
kubectl get services --all-namespaces
kubectl get endpoints --all-namespaces

# View deployments and their status
kubectl get deployments --all-namespaces
kubectl describe deployment <deployment-name> -n <namespace>

# Check node status and resources
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes  # Resource usage

# View persistent volumes and claims
kubectl get pv
kubectl get pvc --all-namespaces

# Check ingress resources
kubectl get ingressroute --all-namespaces
kubectl describe ingressroute <ingress-name> -n <namespace>

# View configmaps
kubectl get configmaps --all-namespaces

# Check cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check Prometheus rules
kubectl get prometheusrule --all-namespaces

# Check AlertManager configuration
kubectl get alertmanagerconfig --all-namespaces
kubectl describe alertmanagerconfig <name> -n monitoring

# View AlertManager logs
kubectl logs -n monitoring alertmanager-prometheus-alertmanager-0

# Check generated AlertManager config
kubectl get secret alertmanager-prometheus-alertmanager-generated -n monitoring \
  -o jsonpath='{.data.alertmanager\.yaml\.gz}' | base64 -d | gunzip

```

## GitOps Application Deployment

### Fleet Configuration Patterns

**Helm Charts with Fleet:**
```yaml
defaultNamespace: <namespace>
helm:
  repo: <repository-url>
  chart: <chart-name>
  version: <version>
  valuesFiles:
  - ./values.yaml
  releaseName: <release-name>
```

**Helm + Kustomize Overlays:**
```yaml
kustomize:
  dir: overlays/dev
```

### Application Categories

**Infrastructure Services:**
- cert-manager v1.17.2 (SSL automation)
- traefik v33.2.1 (ingress controller, LoadBalancer IP: 192.168.10.35)
- longhorn v1.8.1 (distributed storage, 2-replica HA)

**Monitoring:**
- kube-prometheus-stack v69.2.4 (Prometheus, Grafana, AlertManager)

**Home Automation:**
- Home Assistant 2024.9.3 (hostNetwork enabled, node affinity)
- Zigbee2MQTT v2.4.0 (USB device access)
- Z-Wave JS UI 9.30.1 (host path for USB devices)
- Eclipse Mosquitto 2.0.20 (MQTT broker)

### Environment Structure for Applications with Overlays

```
charts/<app>/
├── fleet.yaml          # Fleet deployment config
├── values.yaml         # Base Helm values
└── overlays/dev/
    ├── kustomization.yaml
    └── ingress.yaml    # Environment-specific ingress
```

Apps using overlays: kube-prometheus-stack (alerting + ingress), longhorn, z2m

### AlertManager Configuration Patterns

**AlertmanagerConfig CRD for Receivers:**
```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: <config-name>
  namespace: monitoring
  labels:
    alertmanagerConfig: <label>  # Must match alertmanagerConfigSelector
spec:
  route:
    receiver: '<receiver-name>'
    groupBy: ['alertname', 'namespace', 'severity']
  receivers:
    - name: '<receiver-name>'
      discordConfigs:
        - apiURL:
            name: <secret-name>
            key: <secret-key>
          sendResolved: true
```

**PrometheusRule for Custom Alerts:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: <rule-name>
  namespace: monitoring
  labels:
    prometheus: kube-prometheus-stack-prometheus  # Required label
    role: alert-rules
spec:
  groups:
    - name: <group-name>
      interval: 5m
      rules:
        - alert: <AlertName>
          expr: <promql-query>
          for: 5m
          labels:
            severity: warning|critical
            component: <component>
          annotations:
            summary: "Alert description"
```

**Managing Secrets for AlertManager:**
- Create secrets manually: `kubectl create secret generic <name> -n monitoring --from-literal=<key>=<value>`
- Mount in AlertManager via `alertmanagerSpec.secrets` in values.yaml
- Reference in AlertmanagerConfig CRD via `apiURL` field
- **Never commit secrets to source control**

## Key Configuration Files

- `terraform/modules/proxmox_vms/`: VM provisioning module with Ella/Elliot class definitions
- `ansible/hosts`: Current VM IP addresses and inventory
- `charts/*/fleet.yaml`: GitOps deployment configurations
- `charts/*/values.yaml`: Application-specific Helm values
- `k8s/misc/`: Manual Kubernetes manifests for certificates and external ingress

## Service Access Points

All services accessible via `moria-lab.com` domain (local network only):

| Service | URL | Namespace |
|---------|-----|-----------|
| Traefik Dashboard | `traefik.moria-lab.com` | `traefik-system` |
| Grafana | `grafana.moria-lab.com` | `monitoring` |
| Longhorn UI | `longhorn.moria-lab.com` | `longhorn-system` |
| Home Assistant | `ha.moria-lab.com` | `ha` |
| Zigbee2MQTT | `z2m.moria-lab.com` | `zigbee` |
| Z-Wave JS UI | `zwave.moria-lab.com` | `zwave` |

SSL certificates managed by cert-manager with Cloudflare DNS challenge using `moria-lab-cert`.

## Working with This Repository

### Adding New Applications

1. Create `charts/<app-name>/` directory
2. Add `fleet.yaml` with appropriate deployment type
3. Include `values.yaml` for Helm charts
4. Add `overlays/dev/` if ingress needed
5. Fleet automatically deploys on repository changes

### Infrastructure Changes

- **VM modifications**: Update `terraform/modules/proxmox_vms/`
- **Network changes**: Update `ansible/hosts` and ingress configurations
- **Storage changes**: Modify Longhorn values for replica count/placement

### Troubleshooting

- **Fleet deployments**: Check GitOps status in Rancher UI
- **Certificate issues**: Verify Cloudflare API credentials in cert-manager
- **Storage issues**: Check Longhorn UI for replica status
- **Ingress problems**: Verify Traefik configuration and LoadBalancer IP
- **AlertManager notifications**: Check receiver config with `kubectl get alertmanagerconfig -n monitoring`, verify secrets exist, check AlertManager logs for delivery errors

The repository uses the domain `moria-lab.com` with static IP `192.168.10.35` for the Traefik LoadBalancer service.

---

## Pull Request Template

When creating pull requests for this repository, use the following format to ensure consistent documentation:

### PR Title Format
Use conventional commit style:
- `chore:` - Routine tasks, dependency updates, maintenance
- `feat:` - New features or applications
- `fix:` - Bug fixes and corrections
- `docs:` - Documentation updates
- `refactor:` - Code restructuring without functional changes

**Example:** `chore: upgrade Traefik to v37.2.0 with syntax migration`

### PR Body Structure

```markdown
## Summary

[1-2 sentences describing what the PR does and why]

## Changes

- **file/path**: Brief description of what changed
- **file/path**: Brief description of what changed
- **file/path**: Brief description of what changed

## Technical Details

[Optional section for complex changes]

### [Subsection Title if Needed]
[Technical explanation, architecture notes, or breaking changes]

**Before:**
```yaml
[code example if applicable]
```

**After:**
```yaml
[code example if applicable]
```

### References
- [Link to documentation]
- [Link to related issue/PR]
- [Link to upstream changelog]

## Testing

[Optional section - include verification steps if applicable]

Fleet GitOps will deploy this automatically upon merge. Verify:
- [Specific thing to check]
- [Specific thing to check]
- [Specific thing to check]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### When to Use Each Section

- **Summary**: Always required - explains the "what" and "why"
- **Changes**: Always required - lists modified files with brief context
- **Technical Details**: Use for breaking changes, syntax migrations, or complex updates
- **References**: Use when relevant docs, issues, or upstream changes exist
- **Testing**: Use when specific verification steps are needed post-deployment

### Example PRs

See PR #29 for a complete example of this template in action (Traefik v37.2.0 upgrade).
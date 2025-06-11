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
kubectl get ingress --all-namespaces
kubectl describe ingress <ingress-name> -n <namespace>

# View configmaps and secrets
kubectl get configmaps --all-namespaces
kubectl get secrets --all-namespaces

# Check cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# View resource quotas and limits
kubectl get resourcequota --all-namespaces
kubectl get limitrange --all-namespaces
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

Apps using overlays: kube-prometheus-stack, longhorn, z2m

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

The repository uses the domain `moria-lab.com` with static IP `192.168.10.35` for the Traefik LoadBalancer service.
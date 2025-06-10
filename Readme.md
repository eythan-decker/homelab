# Homelab

Repo of current files and scripts used in my homelab setup.

## Packer

Packer lets you create identical machine images for multiple platforms from a single source configuration. A common use case is creating golden images for organizations to use in cloud infrastructure. [HashiCorp Packer Documentation](https://developer.hashicorp.com/packer/docs?ajs_aid=d6aa81ab-055d-469e-97ed-2f57626ada56&product_intent=packer)

Update credentials-example.pkr.hcl with vars for your environment.

Valite variables with template:
``` bash
packer validate -var-file='..\credentials.pkr.hcl' ubuntu-server-noble.pkr.hcl
```
Build template:
``` bash
packer build -var-file='..\credentials.pkr.hcl' ubuntu-server-noble.pkr.hcl
```
Note, any directories used in the template are relative to where the script is. For me, this was easiest to execute in the directory where the script was.

Not able to get template to work with username/password, only ssh. 

### References
- https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/
- https://github.com/ChristianLempa/boilerplates/blob/main/packer/proxmox/ubuntu-server-jammy/http/user-data

---
## Terraform

Terraform is an infrastructure as code tool that lets you build, change, and version infrastructure safely and efficiently [Terraform Documentation](https://developer.hashicorp.com/terraform?ajs_aid=65c4757a-b701-49a9-95a7-d13ae24aee15&product_intent=terraform)

The current terraform is setup to bootstrap the initial Proxmox VMs for use in K3S HA architecture See here for architecture reference: https://docs.k3s.io/datastore/ha-embedded 

1 additional vm for installing and setting up a Rancher cluster.

Not currently managing state with this Terraform, but in the future could store state management on a drive somewhere on my Proxmox node.

You will need to supply the values in provider.tf with your own credentials.auto.tfvars file.

Init, plan, review, then apply
```bash
terraform init
# installs the telmate/proxmox and configures the local module and vars

terraform plan
## Review output of what Terraform will apply

terraform apply -auto-approve
### Will take several minutes to deploy multiple VMs. Review completed output
```

### VM Classes
Standard image is currently pulling a golden image from Proxmox that was setup via Packer. Currently ubunut-server-noble with 32GB HDD and mounting a cloudinit drive.

- Ella: 4 cpu cores. 4GB Memory
- Elliot: 6 cpu cores, 16GB Memory.

### References
- https://github.com/Telmate/terraform-provider-proxmox/blob/master/docs/index.md
- https://github.com/ChristianLempa/boilerplates/blob/main/terraform/proxmox/full-clone.tf
- https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/

---

## Ansible
Ansible provides open-source automation that reduces complexity and runs everywhere. Using Ansible lets you automate virtually any task. [Ansible Introduction](https://docs.ansible.com/ansible/latest/getting_started/introduction.html)


Currently, I have playbooks for basic bootstrap automation after my proxmox cluster and initial VMs are setup. These include
- docker setup
- apt update
- qemu guest agent install
- reboot
- reboot-required (check if system reboot is required)
- inotify limits increase (fixes "too many open files" errors in Kubernetes)

Update the hosts file per your current environment.
To test connection with hosts:
```bash
ansible -i hosts servers -m ping --user serveradmin
```
Ansible commands must be ran on a machine with ssh keys already added to the target machine. If not using ssh keys, you could run a similar command with the password argument

I was going to add playbooks to boot strap the inital k3s-ha install and configuration but this linked repo does a much better job than I could do and it worked right out of the box [k3s-ansible on GitHub](https://github.com/techno-tim/k3s-ansible) Shoutout to Techno-Tim.

### References
- https://github.com/techno-tim/k3s-ansible
- https://github.com/techno-tim/k3s-ansible

---

## GitOps & Fleet Deployment Architecture

This homelab uses Fleet for GitOps-based deployments to a K3s high-availability cluster. Fleet automatically manages Helm chart deployments and Kubernetes manifests based on repository changes.

### Fleet GitOps Workflow

Fleet monitors this repository and automatically deploys applications when changes are detected. Each application follows a standardized structure:

```yaml
# fleet.yaml structure
defaultNamespace: <namespace>
helm:
  repo: <helm-repository-url>
  chart: <chart-name>
  version: <version>
  valuesFiles:
  - ./values.yaml
  releaseName: <release-name>
kustomize:
  dir: overlays/dev  # For environment-specific configurations
```

### Chart Organization

**Deployment Types:**
- **Helm Charts**: Applications deployed via official Helm repositories (cert-manager, traefik, longhorn, etc.)
- **Kubernetes Manifests**: Custom deployments for specific configurations (Home Assistant, MQTT, Z-Wave)
- **Hybrid**: Helm charts with Kustomize overlays for environment-specific settings

**Environment Structure:**
```
charts/<app>/
├── fleet.yaml          # Fleet deployment configuration
├── values.yaml         # Base Helm values
└── overlays/
    └── dev/
        ├── kustomization.yaml
        └── ingress.yaml # Environment-specific ingress
```

---

## Kubernetes Applications & Versions

### Infrastructure Services

| Application | Version | Purpose | Namespace |
|-------------|---------|---------|-----------|
| **cert-manager** | v1.17.2 | SSL certificate automation with Let's Encrypt | `cert-manager` |
| **traefik** | v33.2.1 | Reverse proxy, load balancer, and ingress controller | `traefik-system` |
| **longhorn** | v1.8.1 | Distributed block storage with 2-replica HA | `longhorn-system` |

### Monitoring & Observability

| Application | Version | Purpose | Namespace |
|-------------|---------|---------|-----------|
| **kube-prometheus-stack** | v69.2.4 | Prometheus, Grafana, AlertManager monitoring stack | `monitoring` |
| **Loki** | 6.30.1 | Log aggregation and storage system | `monitoring` |
| **Grafana Alloy** | 1.1.1 | Telemetry data collection and forwarding agent | `monitoring` |

### Home Automation Platform

| Application | Version | Purpose | Namespace |
|-------------|---------|---------|-----------|
| **Home Assistant** | 2024.9.3 | Home automation platform with hostNetwork access | `ha` |
| **Zigbee2MQTT** | v2.4.0 | Zigbee to MQTT bridge for smart devices | `zigbee` |
| **Z-Wave JS UI** | 9.30.1 | Z-Wave device management with USB device access | `zwave` |
| **Eclipse Mosquitto** | 2.0.20 | MQTT message broker for IoT communication | `mqtt` |

### High Availability Configuration

- **Control Plane**: 3 nodes for K3s HA with embedded etcd. 2 agent nodes. 1 Elliot class VM and 1 Ella class
- **Storage**: Longhorn with 2-replica distribution across 2 agent nodes
- **Load Balancing**: Traefik with 3 replicas and static IP assignment
- **Node Affinity**: Home automation services pinned to dedicated nodes

---

## Ingress & Domain Configuration

All services are accessible via the `moria-lab.com` domain on my local network only currently with automatic SSL certificates managed by cert-manager using Cloudflare DNS challenge.


### Service URLs

| Service | URL |
|---------|-----|
| **Traefik Dashboard** | `traefik.moria-lab.com` |
| **Grafana** | `grafana.moria-lab.com` |
| **Longhorn UI** | `longhorn.moria-lab.com` |
| **Home Assistant** | `ha.moria-lab.com` |
| **Zigbee2MQTT** | `z2m.moria-lab.com` |
| **Z-Wave JS UI** | `zwave.moria-lab.com` |

---

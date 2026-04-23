# How vCluster Helps GPU Cloud Providers Climb the ClusterMAX Rankings

GPU cloud providers are increasingly being evaluated not just on raw hardware performance, but on the quality of their managed Kubernetes offering. ClusterMAX — the industry-standard GPU cloud rating system developed by SemiAnalysis — rewards providers that deliver production-grade orchestration, isolation, and observability.

Scaleway currently holds a **Silver rating** in ClusterMAX 2.0 — a notable achievement as the only European cloud provider to reach that tier. But Silver and Gold are separated by gaps in automation, observability, and multi-tenant Kubernetes quality. This article walks through how virtual clusters (vcluster) directly address those gaps, and what it would take for Scaleway to make the jump to Gold.

---

## What is ClusterMAX?

ClusterMAX is a rating framework by SemiAnalysis that evaluates GPU cloud providers across 10 dimensions with over 50 individual requirements. The current tier landscape (ClusterMAX 2.0) looks like this:

| Tier | Providers |
|------|-----------|
| Platinum | CoreWeave |
| Gold | Azure, Oracle, Crusoe |
| Silver | **Scaleway**, AWS, Lambda |
| Bronze | Meets minimum criteria |

Scaleway's Silver rating reflects strong GPU infrastructure and HPC capabilities — SemiAnalysis specifically praised its seamless container integration within SLURM. The gap to Gold comes down to three areas SemiAnalysis flagged: **automation**, **observability**, and **multi-tenant Kubernetes quality**.

Key orchestration requirements that separate Gold from Silver include:

- Per-tenant cluster isolation with independent control planes
- RBAC and authentication scoped per project or team
- Resource quotas enforced at the cluster level
- Network policies preventing cross-tenant data access
- Automated, self-service cluster provisioning per tenant

---

## The Problem: Namespace Isolation Is Not Enough

Consider a typical GPU cloud setup without vcluster. A provider deploys a single Kubernetes cluster and gives each AI team their own namespace:

```
cluster: k8s-prod
├── namespace: team-ml       ← Team A
├── namespace: team-dev      ← Team B
└── namespace: team-research ← Team C
```

The issues with this model from a ClusterMAX perspective:

1. **Shared control plane** — all teams share the same API server and etcd. A misconfigured RBAC rule can expose one tenant's secrets to another.
2. **Single kubeconfig** — admins manage access through RBAC, but there's no clean per-tenant authentication boundary.
3. **No API server isolation** — a noisy tenant can exhaust API server resources and affect everyone.
4. **ClusterMAX evaluators flag this** — the rating criteria specifically rewards providers that offer per-tenant cluster isolation, not just namespace isolation.

---

## The Solution: vCluster for True Multi-Tenancy

vCluster creates a virtual Kubernetes cluster inside a namespace of a host cluster. Each tenant gets their own:

- **API server** (lightweight k3s)
- **kubeconfig** with independent authentication
- **Control plane** isolated from other tenants
- **Resource quotas** enforced at the namespace level on the host

From the tenant's perspective, they have their own full Kubernetes cluster. From the provider's perspective, it runs on existing nodes with ~200MB RAM overhead per virtual cluster.

```
host cluster: k8s-prod (Scaleway)
├── namespace: vcluster-team-ml
│   └── vcluster: team-ml  ← Team A gets their own K8s API
├── namespace: vcluster-team-dev
│   └── vcluster: team-dev ← Team B gets their own K8s API
└── GPU pool (shared physical hardware)
    └── L4-1-24G nodes (NVIDIA L4 24GB)
```

This directly maps to ClusterMAX's multi-tenancy and orchestration requirements.

---

## Implementation: Scaleway + Terraform + vCluster

The following Terraform configuration provisions a Scaleway Kubernetes cluster with a per-tenant vcluster fleet. The full source is available in this repository.

### Cluster Setup

The host cluster uses Cilium CNI, runs on Scaleway in `fr-par-1` (where L4 GPUs are available), and has a dedicated GPU node pool that scales to zero when idle:

```hcl
# dev.tfvars
cluster_name = "k8s-dev"
zone         = "fr-par-1"   # L4 GPUs available here
k8s_version  = "1.34"
cni          = "cilium"

# GPU node pool — scales to zero when idle
gpu_pool_enabled  = true
gpu_node_type     = "L4-1-24G"
gpu_min_nodes     = 0
gpu_max_nodes     = 2
```

### Per-Tenant vCluster Fleet

The `vclusters` variable accepts a map of tenants. Each entry provisions an isolated virtual cluster with its own namespace, resource quotas, and network policies:

```hcl
vclusters = {
  "team-ml" = {
    cpu_limit             = "2000m"
    memory_limit          = "4Gi"
    storage_size          = "10Gi"
    storage_class         = "scw-bssd"
    isolation_enabled     = true
    resource_quota_cpu    = "20"
    resource_quota_memory = "40Gi"
  }
  "team-dev" = {
    cpu_limit             = "500m"
    memory_limit          = "1Gi"
    storage_size          = "5Gi"
    storage_class         = "scw-bssd"
    isolation_enabled     = true
    resource_quota_cpu    = "10"
    resource_quota_memory = "20Gi"
  }
}
```

Under the hood, `vclusters.tf` provisions for each tenant:

1. A dedicated Kubernetes namespace (`vcluster-{name}`)
2. A Helm-managed vcluster release (chart `0.30.4`, k3s-backed)
3. A `ResourceQuota` capping CPU and memory consumption
4. A `NetworkPolicy` blocking access to the cloud metadata service (`169.254.169.254`) — a ClusterMAX security requirement

```hcl
# Network policy blocking metadata service per tenant
resource "kubernetes_network_policy" "vcluster_isolation" {
  for_each = { for k, v in var.vclusters : k => v if v.isolation_enabled }

  spec {
    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = ["169.254.169.254/32"]
        }
      }
    }
    policy_types = ["Egress"]
  }
}
```

### Connecting to a Tenant's vCluster

Each tenant receives their own kubeconfig:

```bash
# Connect as team-ml
vcluster connect team-ml -n vcluster-team-ml
kubectl get nodes        # sees real GPU nodes
kubectl get namespaces   # only sees their own namespaces
vcluster disconnect

# Connect as team-dev
vcluster connect team-dev -n vcluster-team-dev
kubectl get nodes        # cannot see team-ml's workloads
```

This is the isolation story in action — two teams on the same physical hardware, with no visibility into each other's control plane.

---

## ClusterMAX Alignment: Before and After vCluster

| ClusterMAX Requirement | Without vCluster | With vCluster |
|------------------------|-----------------|---------------|
| Per-tenant Kubernetes isolation | ❌ Shared control plane | ✅ Independent API server per tenant |
| Per-tenant RBAC / kubeconfig | ❌ Admin-managed RBAC on shared cluster | ✅ Each tenant has their own kubeconfig |
| Resource quotas | ⚠️ Namespace-level only | ✅ Enforced at namespace + control plane |
| Metadata service blocking | ❌ Not enforced | ✅ NetworkPolicy per tenant |
| Multi-tenant provisioning speed | ❌ Manual namespace setup | ✅ ~30 seconds via Terraform |

The improvement is specifically in the **Orchestration** and **Security** dimensions of ClusterMAX — not in hardware or networking scores, which are determined by the host cluster.

### Silver → Gold: What This Closes

Of the three gaps SemiAnalysis identified for Scaleway's Silver rating, this implementation directly addresses two:

| Gap identified by SemiAnalysis | Addressed by this implementation? |
|--------------------------------|----------------------------------|
| Automation | ✅ Terraform-managed, self-service vcluster provisioning per tenant |
| Observability / Monitoring | ✅ Prometheus + Grafana + DCGM Exporter deployed per cluster |
| Multi-tenant Kubernetes quality | ✅ Per-tenant isolated control planes via vcluster |

This does not guarantee a Gold rating — ClusterMAX evaluates many dimensions beyond orchestration. But it directly closes the gaps SemiAnalysis called out as differentiators between Scaleway's current Silver and the Gold tier.

---

## What vCluster Does NOT Improve

It is important to be precise about scope. vCluster is transparent to:

- **GPU bandwidth and NCCL performance** — pod networking goes through the host, so GPU-to-GPU communication is the same with or without vcluster.
- **Hardware availability scores** — GPU instance types, availability zones, and interconnect speed are Scaleway infrastructure concerns.
- **Storage IOPS** — the host's block storage (`scw-bssd`) is used directly.

ClusterMAX rates the provider as a whole. vCluster improves the provider's **managed Kubernetes product quality**, which maps to the orchestration and security dimensions of the rating — not the hardware dimensions.

---

## Monitoring: Closing the Observability Loop

A complete ClusterMAX-aligned setup also requires per-cluster observability. The Prometheus/Grafana stack deployed on the host collects metrics from all tenant vclusters via ServiceMonitors, and DCGM Exporter provides GPU utilization metrics from the L4 nodes:

```hcl
monitoring_enabled      = true
prometheus_retention    = "7d"
prometheus_storage_size = "30Gi"
grafana_admin_password  = "your-password"
```

Tenants can be given Grafana dashboard access scoped to their namespace, providing the per-tenant visibility that Platinum-tier ClusterMAX ratings require.

---

## Conclusion

vCluster does not make a GPU cloud provider's hardware faster. What it does is enable the provider to offer a **genuinely isolated, per-tenant managed Kubernetes experience** — the kind that ClusterMAX's orchestration tier rewards.

For a provider like Scaleway, the combination of:
- Managed K8s with auto-upgrade and auto-healing (already supported)
- Per-tenant vcluster fleet with independent control planes
- Resource quotas and network isolation per tenant
- GPU node pool with autoscaling
- Prometheus/Grafana observability stack

...directly addresses the automation, observability, and multi-tenancy gaps that SemiAnalysis identified as separating Scaleway's current Silver rating from Gold. The Terraform configuration in this repository is a concrete, deployable reference implementation of what that upgrade looks like in practice.

---

*The full Terraform source for this implementation is available at [github.com/your-org/scw-k8s](https://github.com/your-org/scw-k8s).*

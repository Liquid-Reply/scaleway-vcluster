# Scaleway Kubernetes + VCluster Fleet

Terraform configuration for a managed Kubernetes cluster on Scaleway with a fleet of isolated virtual clusters (vclusters) — one per tenant.

## Features

- Managed Kubernetes cluster with autoscaling and autohealing
- VPC private network
- **VCluster fleet**: one isolated virtual cluster per tenant, provisioned via Helm (chart 0.30.4)
- Per-tenant resource quotas and network isolation (blocks cloud metadata service)
- Environment-specific configuration via `.tfvars` files

## VCluster and Multi-Tenancy Ratings

Cloud provider rating systems (e.g. ClusterMAX by SemiAnalysis) score providers on multi-tenancy quality as a distinct criterion. Three properties of this vcluster implementation directly contribute to that score:

**1. Dedicated control plane per tenant**

Namespace-based multi-tenancy is the naive approach — all tenants share one API server, so rate limits, RBAC scope, and failure blast radius are shared too. Each vcluster runs its own isolated k3s API server as a StatefulSet. A tenant crashing their workloads, exhausting API request budgets, or misconfiguring RBAC cannot affect any other tenant's control plane.

**2. Noisy-neighbour prevention**

Hard resource quotas are enforced at the host namespace level (not just inside the vcluster). Even if a tenant's workloads spike beyond their vcluster limits, the host-side quota caps how much CPU and memory their namespace can consume on the underlying Scaleway nodes. Tenant A cannot starve Tenant B regardless of what runs inside their virtual cluster.

**3. Metadata service lockdown**

A network egress policy on each tenant namespace blocks all traffic to `169.254.169.254` — the Scaleway instance metadata endpoint. Without this, any workload inside a vcluster could reach the host node's metadata API and extract IAM credentials or instance configuration. This is a concrete, auditable security control for shared-infrastructure environments.

## Prerequisites

1. **Scaleway account** — [scaleway.com](https://www.scaleway.com)
2. **API credentials** — generate at [Scaleway Console > IAM > API Keys](https://console.scaleway.com/iam/api-keys)
3. **Terraform** >= 1.0 — [terraform.io](https://www.terraform.io/downloads)
4. **kubectl** — [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)
5. **vcluster CLI** — `brew install loft-sh/tap/vcluster` or [github.com/loft-sh/vcluster](https://github.com/loft-sh/vcluster/releases)

## Credentials

Set environment variables:

```bash
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_DEFAULT_PROJECT_ID="your-project-id"
```

Or configure `~/.config/scw/config.yaml`:

```yaml
access_key: your-access-key
secret_key: your-secret-key
default_project_id: your-project-id
default_region: fr-par
default_zone: fr-par-1
```

## Usage

```bash
terraform init
terraform validate
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

## Cluster Access

```bash
# Option 1: via Terraform output
terraform output -raw kubeconfig_file > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# Option 2: via Scaleway CLI
scw k8s kubeconfig get <cluster-id> > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
```

## VCluster Fleet

Tenants are defined as a map in your `.tfvars` file. Each entry provisions an isolated vcluster in its own namespace.

```hcl
vclusters = {
  "team-ml" = {
    cpu_limit                   = "2000m"
    memory_limit                = "4Gi"
    storage_size                = "10Gi"
    storage_class               = "scw-bssd"
    isolation_enabled           = true
    resource_quota_cpu          = "20"
    resource_quota_memory       = "40Gi"
    resource_quota_cpu_limit    = "30"
    resource_quota_memory_limit = "60Gi"
  }
  "team-dev" = {
    cpu_limit    = "500m"
    memory_limit = "1Gi"
    storage_size = "5Gi"
    isolation_enabled = true
    # ... resource quota fields
  }
}
```

Add a tenant by adding an entry; remove by deleting it. Terraform handles the rest.

### Connect to a vcluster

```bash
vcluster connect team-ml -n vcluster-team-ml
kubectl get nodes
kubectl get namespaces
vcluster disconnect
```

### What each vcluster gets

- Dedicated k3s control plane (chart 0.30.4)
- Service CIDR aligned to Scaleway host cluster (`10.32.0.0/12`)
- Node sync from host cluster
- Resource quota (CPU + memory) on the host namespace
- Network policy blocking cloud metadata service (`169.254.169.254`)

## Configuration Variables

### Cluster

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Cluster name | Required |
| `project_id` | Scaleway project ID | Required |
| `region` | Scaleway region | `fr-par` |
| `zone` | Scaleway zone | `fr-par-1` |
| `k8s_version` | Kubernetes minor version (e.g. `1.32`) | `1.32` |
| `cni` | CNI plugin (`cilium`, `calico`, `kilo`) | `cilium` |
| `node_type` | Node instance type | `DEV1-M` |
| `node_count` | Initial node count | `3` |
| `min_nodes` | Autoscaler minimum | `1` |
| `max_nodes` | Autoscaler maximum | `10` |
| `autoscaling_enabled` | Enable node autoscaling | `true` |
| `autohealing_enabled` | Enable node autohealing | `true` |
| `delete_additional_resources` | Delete PVs/LBs on destroy | `false` |
| `pool_name` | Node pool name | `default-pool` |
| `private_network_name` | VPC name (defaults to `{cluster_name}-pn`) | `""` |
| `tags` | Resource tags | `[]` |

### VCluster fleet

| Variable | Description | Default |
|----------|-------------|---------|
| `vclusters` | Map of tenant vclusters (see above) | `{}` |

Each vcluster object supports:

| Field | Description | Default |
|-------|-------------|---------|
| `cpu_limit` | CPU limit for vcluster control plane | `1000m` |
| `memory_limit` | Memory limit | `2Gi` |
| `storage_size` | Persistent volume size | `5Gi` |
| `storage_class` | Storage class | `scw-bssd` |
| `isolation_enabled` | Enable resource quota + metadata network policy | `true` |
| `resource_quota_cpu` | Namespace CPU request quota | `10` |
| `resource_quota_memory` | Namespace memory request quota | `20Gi` |
| `resource_quota_cpu_limit` | Namespace CPU limit quota | `20` |
| `resource_quota_memory_limit` | Namespace memory limit quota | `40Gi` |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | Cluster identifier |
| `cluster_url` | Kubernetes API endpoint |
| `cluster_status` | Current cluster status |
| `cluster_version` | Kubernetes version |
| `kubeconfig_file` | Complete kubeconfig (sensitive) |
| `pool_current_size` | Current number of nodes |
| `wildcard_dns` | Wildcard DNS for cluster services |
| `vclusters_deployed` | Map of deployed vclusters with connect commands |
| `vcluster_fleet_count` | Number of provisioned vclusters |

## Teardown

```bash
terraform destroy -var-file="dev.tfvars"
```

If `delete_additional_resources = false` (default), manually clean up any remaining Persistent Volumes and Load Balancers in the Scaleway console.

## Troubleshooting

**`auto_upgrade` version error** — Use minor version format (`1.32`, not `1.32.3`). Auto-upgrade is enabled by default.

**vcluster pods in `CrashLoopBackOff`** — Check the service CIDR. The chart is pre-configured for Scaleway's `10.32.0.0/12`. If your host cluster uses a different CIDR, update `controlPlane.distro.k3s.extraArgs` in `vclusters.tf`.

**Nodes not scaling** — Verify `autoscaling_enabled = true` and that pods have resource requests set.

## Resources

- [Scaleway Kubernetes Docs](https://www.scaleway.com/en/docs/compute/kubernetes/)
- [Terraform Scaleway Provider](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs)
- [VCluster Docs](https://www.vcluster.com/docs/)

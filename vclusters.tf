# VCluster Fleet Configuration
# Provisions one isolated virtual Kubernetes cluster per tenant.
# Add/remove tenants via the vclusters variable in your .tfvars file.

# Namespace per tenant
resource "kubernetes_namespace" "vcluster" {
  for_each = var.vclusters

  metadata {
    name = "vcluster-${each.key}"
    labels = {
      "app"       = "vcluster"
      "tenant"    = each.key
      "terraform" = "true"
    }
  }

  depends_on = [
    scaleway_k8s_pool.main,
    scaleway_k8s_cluster.main
  ]

  lifecycle {
    create_before_destroy = false
  }
}

# Helm release per tenant
resource "helm_release" "vcluster" {
  for_each = var.vclusters

  name       = each.key
  namespace  = kubernetes_namespace.vcluster[each.key].metadata[0].name
  repository = "https://charts.loft.sh"
  chart      = "vcluster"
  version    = "0.30.4"

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      controlPlane = {
        distro = {
          k3s = {
            extraArgs = ["--service-cidr=10.32.0.0/12"]
          }
        }
        statefulSet = {
          resources = {
            limits = {
              cpu    = each.value.cpu_limit
              memory = each.value.memory_limit
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
          persistence = {
            volumeClaim = {
              enabled      = "auto"
              size         = each.value.storage_size
              storageClass = each.value.storage_class
              accessModes  = ["ReadWriteOnce"]
            }
          }
        }
      }
      sync = {
        fromHost = {
          nodes = {
            enabled  = true
            selector = { all = true }
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.vcluster,
    scaleway_k8s_pool.main,
    scaleway_k8s_cluster.main
  ]

  lifecycle {
    create_before_destroy = false
  }
}

# Resource quota per tenant (when isolation_enabled)
resource "kubernetes_resource_quota" "vcluster" {
  for_each = { for k, v in var.vclusters : k => v if v.isolation_enabled }

  metadata {
    name      = "vcluster-quota"
    namespace = kubernetes_namespace.vcluster[each.key].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = each.value.resource_quota_cpu
      "requests.memory" = each.value.resource_quota_memory
      "limits.cpu"      = each.value.resource_quota_cpu_limit
      "limits.memory"   = each.value.resource_quota_memory_limit
    }
  }

  depends_on = [kubernetes_namespace.vcluster]
}

# Network policy per tenant — blocks cloud metadata service (when isolation_enabled)
resource "kubernetes_network_policy" "vcluster_isolation" {
  for_each = { for k, v in var.vclusters : k => v if v.isolation_enabled }

  metadata {
    name      = "deny-metadata-access"
    namespace = kubernetes_namespace.vcluster[each.key].metadata[0].name
  }

  spec {
    pod_selector {}

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

  depends_on = [kubernetes_namespace.vcluster]
}

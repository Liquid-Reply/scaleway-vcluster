# Main Infrastructure Configuration
# Providers are configured in providers.tf

# VPC Private Network (required for K8s cluster)
resource "scaleway_vpc_private_network" "main" {
  name = var.private_network_name != "" ? var.private_network_name : "${var.cluster_name}-pn"
  tags = concat(["terraform", "kubernetes"], var.tags)
}

# Kubernetes Cluster
resource "scaleway_k8s_cluster" "main" {
  name                        = var.cluster_name
  version                     = var.k8s_version
  cni                         = var.cni
  private_network_id          = scaleway_vpc_private_network.main.id
  delete_additional_resources = var.delete_additional_resources
  tags                        = concat(["terraform"], var.tags)

  autoscaler_config {
    disable_scale_down              = false
    scale_down_delay_after_add      = "10m"
    scale_down_unneeded_time        = "10m"
    estimator                       = "binpacking"
    expander                        = "least_waste"
    ignore_daemonsets_utilization   = false
    balance_similar_node_groups     = true
    expendable_pods_priority_cutoff = -10
  }

  auto_upgrade {
    enable                        = true
    maintenance_window_day        = "sunday"
    maintenance_window_start_hour = 2
  }
}

# Node Pool
resource "scaleway_k8s_pool" "main" {
  cluster_id = scaleway_k8s_cluster.main.id
  name       = var.pool_name
  node_type  = var.node_type
  size       = var.node_count

  autoscaling = var.autoscaling_enabled
  autohealing = var.autohealing_enabled

  min_size = var.min_nodes
  max_size = var.max_nodes

  tags = concat(["terraform"], var.tags)

  upgrade_policy {
    max_unavailable = 1
    max_surge       = 0
  }
}

# GPU Node Pool (optional — enabled via gpu_pool_enabled variable)
# Scaleway automatically installs the NVIDIA GPU operator on GPU node types.
# Available GPU types in fr-par-1: L4-1-24G (NVIDIA L4 24GB), H100-1-80G (NVIDIA H100 80GB)
resource "scaleway_k8s_pool" "gpu" {
  count = var.gpu_pool_enabled ? 1 : 0

  cluster_id = scaleway_k8s_cluster.main.id
  name       = var.gpu_pool_name
  node_type  = var.gpu_node_type
  size       = var.gpu_node_count

  autoscaling = var.gpu_autoscaling_enabled
  autohealing = var.gpu_autohealing_enabled

  min_size = var.gpu_min_nodes
  max_size = var.gpu_max_nodes

  tags = concat(["terraform", "gpu"], var.tags)

  upgrade_policy {
    max_unavailable = 1
    max_surge       = 0
  }
}

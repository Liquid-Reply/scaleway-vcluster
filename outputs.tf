output "cluster_id" {
  description = "The ID of the Kubernetes cluster"
  value       = scaleway_k8s_cluster.main.id
}

output "cluster_name" {
  description = "The name of the Kubernetes cluster"
  value       = scaleway_k8s_cluster.main.name
}

output "cluster_url" {
  description = "The URL of the Kubernetes API server"
  value       = scaleway_k8s_cluster.main.apiserver_url
}

output "cluster_status" {
  description = "The status of the Kubernetes cluster"
  value       = scaleway_k8s_cluster.main.status
}

output "cluster_version" {
  description = "The version of the Kubernetes cluster"
  value       = scaleway_k8s_cluster.main.version
}

# output "kubeconfig_host" {
#   description = "The Kubernetes API server host for kubeconfig"
#   value       = try(scaleway_k8s_cluster.main.kubeconfig[0].host, "")
# }

output "kubeconfig_token" {
  description = "The token for kubeconfig authentication"
  value       = try(scaleway_k8s_cluster.main.kubeconfig[0].token, "")
  sensitive   = true
}

output "kubeconfig_cluster_ca_certificate" {
  description = "The CA certificate for kubeconfig"
  value       = try(scaleway_k8s_cluster.main.kubeconfig[0].cluster_ca_certificate, "")
  sensitive   = true
}

output "kubeconfig_file" {
  description = "Complete kubeconfig file content"
  value       = try(scaleway_k8s_cluster.main.kubeconfig[0].config_file, "")
  sensitive   = true
}

output "private_network_id" {
  description = "The ID of the VPC private network"
  value       = scaleway_vpc_private_network.main.id
}

output "pool_id" {
  description = "The ID of the node pool"
  value       = scaleway_k8s_pool.main.id
}

output "pool_status" {
  description = "The status of the node pool"
  value       = scaleway_k8s_pool.main.status
}

output "pool_current_size" {
  description = "Current number of nodes in the pool"
  value       = scaleway_k8s_pool.main.current_size
}

output "pool_nodes" {
  description = "List of nodes in the pool"
  value       = scaleway_k8s_pool.main.nodes
}

output "wildcard_dns" {
  description = "The wildcard DNS that points to all ready nodes"
  value       = scaleway_k8s_cluster.main.wildcard_dns
}

# VCluster Fleet Outputs

output "vclusters_deployed" {
  description = "All deployed tenant vclusters with namespace, status, and connect command"
  value = {
    for name, _ in var.vclusters : name => {
      namespace         = kubernetes_namespace.vcluster[name].metadata[0].name
      status            = helm_release.vcluster[name].status
      isolation_enabled = var.vclusters[name].isolation_enabled
      connect           = "vcluster connect ${name} -n vcluster-${name}"
    }
  }
}

output "vcluster_fleet_count" {
  description = "Number of tenant vclusters provisioned"
  value       = length(var.vclusters)
}


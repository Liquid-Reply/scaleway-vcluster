# Provider Configuration
# This file configures all providers used in the project

# Scaleway provider is configured via environment variables or config file
provider "scaleway" {
  region     = var.region
  zone       = var.zone
  project_id = var.project_id
}

# Kubernetes provider - configured to use the Scaleway K8s cluster
# Using lifecycle ignore_changes to prevent cycles during cluster updates
provider "kubernetes" {
  host                   = length(scaleway_k8s_cluster.main.kubeconfig) > 0 ? scaleway_k8s_cluster.main.kubeconfig[0].host : ""
  token                  = length(scaleway_k8s_cluster.main.kubeconfig) > 0 ? scaleway_k8s_cluster.main.kubeconfig[0].token : ""
  cluster_ca_certificate = length(scaleway_k8s_cluster.main.kubeconfig) > 0 ? base64decode(scaleway_k8s_cluster.main.kubeconfig[0].cluster_ca_certificate) : ""
}

# Helm provider - configured to use the Scaleway K8s cluster
# Using lifecycle ignore_changes to prevent cycles during cluster updates
provider "helm" {
  kubernetes {
    host                   = length(scaleway_k8s_cluster.main.kubeconfig) > 0 ? scaleway_k8s_cluster.main.kubeconfig[0].host : ""
    token                  = length(scaleway_k8s_cluster.main.kubeconfig) > 0 ? scaleway_k8s_cluster.main.kubeconfig[0].token : ""
    cluster_ca_certificate = length(scaleway_k8s_cluster.main.kubeconfig) > 0 ? base64decode(scaleway_k8s_cluster.main.kubeconfig[0].cluster_ca_certificate) : ""
  }
}

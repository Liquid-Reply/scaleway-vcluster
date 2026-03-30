variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-1"
}

variable "k8s_version" {
  description = "Kubernetes version (minor version x.y when auto_upgrade is enabled)"
  type        = string
  default     = "1.32"
}

variable "cni" {
  description = "Container Network Interface plugin (cilium, calico, or kilo)"
  type        = string
  default     = "cilium"

  validation {
    condition     = contains(["cilium", "calico", "kilo"], var.cni)
    error_message = "CNI must be one of: cilium, calico, kilo"
  }
}

variable "node_type" {
  description = "Instance type for nodes (e.g., DEV1-M, GP1-S, GP1-M)"
  type        = string
  default     = "DEV1-M"
}

variable "node_count" {
  description = "Initial number of nodes in the pool"
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1

  validation {
    condition     = var.min_nodes >= 0
    error_message = "Minimum nodes must be >= 0"
  }
}

variable "max_nodes" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10

  validation {
    condition     = var.max_nodes >= var.min_nodes
    error_message = "Maximum nodes must be >= minimum nodes"
  }
}

variable "autoscaling_enabled" {
  description = "Enable autoscaling for the node pool"
  type        = bool
  default     = true
}

variable "autohealing_enabled" {
  description = "Enable autohealing for the node pool"
  type        = bool
  default     = true
}

variable "delete_additional_resources" {
  description = "Delete additional resources like volumes and load balancers on cluster deletion"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = list(string)
  default     = []
}

variable "private_network_name" {
  description = "Name for the VPC private network (if empty, defaults to {cluster_name}-pn)"
  type        = string
  default     = ""
}

variable "pool_name" {
  description = "Name for the node pool"
  type        = string
  default     = "default-pool"
}

# VCluster Fleet Variables

variable "vclusters" {
  description = "Map of tenant vclusters to provision. Key is the tenant name (e.g. 'team-ml', 'team-dev')."
  type = map(object({
    cpu_limit                   = optional(string, "1000m")
    memory_limit                = optional(string, "2Gi")
    storage_size                = optional(string, "5Gi")
    storage_class               = optional(string, "scw-bssd")
    isolation_enabled           = optional(bool, true)
    resource_quota_cpu          = optional(string, "10")
    resource_quota_memory       = optional(string, "20Gi")
    resource_quota_cpu_limit    = optional(string, "20")
    resource_quota_memory_limit = optional(string, "40Gi")
  }))
  default = {}
}

variable "project_id" {
  type        = string
  description = "Your project ID."
}

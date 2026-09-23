variable "name" {
  description = "Cluster name; also the prefix for the IAM roles and security groups it owns."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC the cluster is created in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and the node groups."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "public_subnet_ids" {
  description = "Public subnets, attached so the load balancer controller can place internet-facing ALBs."
  type        = list(string)
  default     = []
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API endpoint to the internet."
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Narrow this to operator networks outside dev."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Control plane log types shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "control_plane_log_retention_days" {
  description = "Retention for the control plane log group."
  type        = number
  default     = 30
}

variable "node_groups" {
  description = "Managed node groups, keyed by name."
  type = map(object({
    instance_types = optional(list(string), ["t3.large"])
    capacity_type  = optional(string, "ON_DEMAND")
    desired_size   = optional(number, 2)
    min_size       = optional(number, 2)
    max_size       = optional(number, 4)
    disk_size      = optional(number, 50)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))

  default = { default = {} }

  validation {
    condition     = alltrue([for ng in var.node_groups : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size])
    error_message = "Each node group must satisfy min_size <= desired_size <= max_size."
  }

  validation {
    condition     = alltrue([for ng in var.node_groups : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "cluster_admin_principals" {
  description = "IAM principal ARNs granted cluster-admin through EKS access entries."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
  default     = {}
}

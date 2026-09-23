variable "region" {
  description = "AWS region for every resource in this environment."
  type        = string
}

variable "environment" {
  description = "Environment name; forms part of every resource name and tag."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment must be lowercase alphanumeric with hyphens, 2-16 characters."
  }
}

variable "project" {
  description = "Project name; forms part of every resource name and tag."
  type        = string
  default     = "conduit"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be lowercase alphanumeric with hyphens, 2-21 characters."
  }
}

variable "owner" {
  description = "Team accountable for these resources; used for cost allocation."
  type        = string
  default     = "platform"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones to span."
  type        = number
  default     = 2
}

variable "nat_gateway_strategy" {
  description = "NAT gateway topology. Dev defaults to a single gateway to keep the hourly cost down."
  type        = string
  default     = "single"
}

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.31"
}

variable "eks_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API endpoint. Narrow this before promoting beyond dev."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_node_groups" {
  description = "Managed node group definitions passed through to the EKS module."
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

  default = {
    default = {
      instance_types = ["t3.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 4
    }
  }
}

variable "cluster_admins" {
  description = "Additional IAM principals granted cluster-admin via EKS access entries, keyed by a stable name."
  type        = map(string)
  default     = {}
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.15"
}

variable "db_multi_az" {
  description = "Run an RDS standby in a second availability zone."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated backup retention, which is also the point-in-time recovery window."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Block accidental deletion of the database."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy."
  type        = bool
  default     = false
}

variable "github_repositories" {
  description = <<-EOT
      Repositories allowed to deploy through OIDC, keyed by a short label. GitHub
      issues subjects carrying the numeric IDs of the owner and the repository, so
      both are recorded next to the names they belong to.
  EOT
  type = map(object({
    owner    = string
    owner_id = string
    name     = string
    id       = string
  }))

  validation {
    condition = alltrue([
      for r in values(var.github_repositories) :
      can(regex("^[A-Za-z0-9._-]+$", r.owner)) && can(regex("^[A-Za-z0-9._-]+$", r.name))
    ])
    error_message = "owner and name must be bare GitHub names, without a slash."
  }

  validation {
    condition     = alltrue([for r in values(var.github_repositories) : can(regex("^[0-9]+$", r.owner_id)) && can(regex("^[0-9]+$", r.id))])
    error_message = "owner_id and id must be numeric."
  }
}

variable "github_oidc_provider_arn" {
  description = "GitHub OIDC provider created by the bootstrap root. Passing it avoids creating a second provider for the same issuer."
  type        = string
}

variable "github_deploy_environment" {
  description = "GitHub Environment whose jobs may assume the application deployment role."
  type        = string
  default     = "dev"
}

variable "ecr_force_delete" {
  description = "Allow ECR repositories to be deleted while they still contain images. True for a demo environment that has to be torn down."
  type        = bool
  default     = false
}

variable "alarm_email_subscriptions" {
  description = "Email addresses subscribed to the CloudWatch alarm topic."
  type        = list(string)
  default     = []
}

variable "ingress_load_balancer_arn_suffix" {
  description = <<-EOT
    ARN suffix of the ALB the ingress creates, e.g. app/k8s-conduit-abc/0123456789abcdef.
    The load balancer is provisioned by the in-cluster controller rather than by
    Terraform, so this is supplied on a second apply once the ingress exists.
  EOT
  type        = string
  default     = ""
}

variable "name" {
  description = "Name of the deployment role."
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false when another stack in the same account already owns it."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of an existing GitHub OIDC provider. Required when create_oidc_provider is false."
  type        = string
  default     = null

  validation {
    condition     = var.oidc_provider_arn == null || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be an IAM OIDC provider ARN."
  }
}

variable "subjects" {
  description = <<-EOT
    GitHub OIDC subject claims allowed to assume the role, e.g.
    "repo:acme/backend:ref:refs/heads/main" or "repo:acme/backend:environment:production".
    Wildcarding the ref lets any branch deploy, so keep these specific.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.subjects) > 0
    error_message = "At least one subject claim is required; an empty list would produce a role nothing can assume."
  }

  validation {
    condition     = alltrue([for s in var.subjects : startswith(s, "repo:")])
    error_message = "Every subject must start with \"repo:\"."
  }
}

variable "ecr_repository_arns" {
  description = "ECR repositories the role may push to."
  type        = list(string)
  default     = []
}

variable "eks_cluster_arns" {
  description = "EKS clusters the role may describe in order to build a kubeconfig."
  type        = list(string)
  default     = []
}

variable "rds_instance_arns" {
  description = "Database instances the deploy step may describe when resolving the endpoint. Empty omits the permission."
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Maximum session length in seconds."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
  default     = {}
}

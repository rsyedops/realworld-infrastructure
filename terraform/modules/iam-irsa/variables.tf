variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "Issuer host of the cluster OIDC provider, without the https:// scheme."
  type        = string

  validation {
    condition     = !startswith(var.oidc_provider_url, "https://")
    error_message = "oidc_provider_url must not include the scheme; pass the host only."
  }
}

variable "namespace" {
  description = "Kubernetes namespace of the service account."
  type        = string
}

variable "service_account" {
  description = "Name of the Kubernetes service account allowed to assume this role."
  type        = string
}

variable "policy_arns" {
  description = "Managed policy ARNs to attach."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Inline policy document. Null attaches no inline policy."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the role."
  type        = map(string)
  default     = {}
}

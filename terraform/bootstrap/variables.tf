variable "region" {
  description = "AWS region for the state bucket."
  type        = string
}

variable "project" {
  description = "Project name; prefixes the bucket and role."
  type        = string
  default     = "conduit"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

variable "infrastructure_repository" {
  description = "owner/name of the repository whose workflow runs Terraform."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.infrastructure_repository))
    error_message = "Must be in owner/name form."
  }
}

variable "deploy_ref" {
  description = "Git ref allowed to assume the Terraform role."
  type        = string
  default     = "refs/heads/main"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

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

variable "infrastructure_owner_id" {
  description = "Numeric GitHub account ID of the repository owner. Appears in the OIDC subject as owner@id."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.infrastructure_owner_id))
    error_message = "infrastructure_owner_id must be numeric."
  }
}

variable "infrastructure_repository_id" {
  description = "Numeric GitHub repository ID. Appears in the OIDC subject as name@id."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.infrastructure_repository_id))
    error_message = "infrastructure_repository_id must be numeric."
  }
}

variable "deploy_environment" {
  description = "GitHub Environment whose jobs may assume the Terraform role. A job that declares this environment receives an OIDC subject of repo:<owner>/<name>:environment:<value>."
  type        = string
  default     = "dev"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

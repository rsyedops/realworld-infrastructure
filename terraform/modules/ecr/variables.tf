variable "repositories" {
  description = "Repository names to create, relative to the registry."
  type        = list(string)

  validation {
    condition     = length(var.repositories) > 0
    error_message = "At least one repository name is required."
  }
}

variable "image_tag_mutability" {
  description = "IMMUTABLE prevents a tag being repointed after a push, which is what makes a deployed digest auditable."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "scan_on_push" {
  description = "Run a vulnerability scan when an image is pushed."
  type        = bool
  default     = true
}

variable "untagged_image_expiry_days" {
  description = "Days before untagged layers are expired."
  type        = number
  default     = 7
}

variable "max_tagged_images" {
  description = "Number of released images to retain per repository."
  type        = number
  default     = 30
}

variable "release_tag_prefixes" {
  description = "Tag prefixes treated as releases by the retention rule."
  type        = list(string)
  default     = ["sha-", "v"]
}

variable "force_delete" {
  description = "Delete repositories that still contain images. Only appropriate for throwaway environments."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for image encryption. Null uses the AES256 default."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every repository."
  type        = map(string)
  default     = {}
}

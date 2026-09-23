variable "name" {
  description = "Name prefix applied to every resource in this module."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC. Must leave room for the per-AZ subnet split."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) && tonumber(split("/", var.cidr_block)[1]) <= 20
    error_message = "cidr_block must be valid CIDR notation with a prefix of /20 or larger (e.g. 10.0.0.0/16)."
  }
}

variable "availability_zone_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4
    error_message = "availability_zone_count must be between 2 and 4; EKS and RDS both require at least two."
  }
}

variable "nat_gateway_strategy" {
  description = <<-EOT
    How many NAT gateways to run.
      single - one shared gateway; cheapest, but a zone outage cuts egress for every private subnet.
      per_az - one per availability zone; required for a genuinely zone-independent data plane.
      none   - no egress; only useful when every workload is served by VPC endpoints.
  EOT
  type        = string
  default     = "per_az"

  validation {
    condition     = contains(["single", "per_az", "none"], var.nat_gateway_strategy)
    error_message = "nat_gateway_strategy must be one of: single, per_az, none."
  }
}

variable "cluster_name" {
  description = "EKS cluster name used for subnet discovery tags. Empty disables the tags."
  type        = string
  default     = ""
}

variable "flow_logs_enabled" {
  description = "Capture rejected-traffic VPC flow logs to CloudWatch."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention for the VPC flow log group."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Name prefix for the alarms and topic this module owns."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the Container Insights addon is installed on."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "Issuer host of the cluster OIDC provider, without the scheme."
  type        = string
}

variable "application_log_retention_days" {
  description = "Retention for the application log group written by Container Insights."
  type        = number
  default     = 30
}

variable "alarm_email_subscriptions" {
  description = "Email addresses subscribed to the alarm topic. Each requires manual confirmation."
  type        = list(string)
  default     = []
}

variable "db_instance_identifier" {
  description = "RDS instance to alarm on. Empty disables the database alarms."
  type        = string
  default     = ""
}

variable "db_max_connections" {
  description = "Connection ceiling for the instance class, used to derive the connection alarm threshold."
  type        = number
  default     = 100
}

variable "db_free_storage_bytes_threshold" {
  description = "Free storage below which the storage alarm fires."
  type        = number
  default     = 2147483648
}

variable "load_balancer_arn_suffix" {
  description = "ARN suffix of the ingress ALB, e.g. app/my-alb/0123456789abcdef. Empty disables the ALB alarms."
  type        = string
  default     = ""
}

variable "alb_5xx_threshold" {
  description = "Target 5xx responses in a five minute window before alarming."
  type        = number
  default     = 10
}

variable "alb_latency_threshold_seconds" {
  description = "p90 target response time in seconds before alarming."
  type        = number
  default     = 1.5
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
  default     = {}
}

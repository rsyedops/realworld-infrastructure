output "role_arn" {
  description = "ARN of the role GitHub Actions assumes."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the role GitHub Actions assumes."
  value       = aws_iam_role.this.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in use."
  value       = local.provider_arn
}

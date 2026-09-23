output "state_bucket" {
  description = "Set as the TF_STATE_BUCKET repository variable on the infrastructure repo."
  value       = aws_s3_bucket.state.id
}

output "terraform_role_arn" {
  description = "Set as the AWS_ROLE_ARN repository variable on the infrastructure repo."
  value       = aws_iam_role.terraform.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider in use. Pass to the dev environment as existing_github_oidc_provider_arn."
  value       = local.oidc_provider_arn
}

output "region" {
  description = "Region this environment is deployed in."
  value       = var.region
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets carrying the nodes and the database."
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Command that writes a kubeconfig entry for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by repository name."
  value       = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "Role GitHub Actions assumes via OIDC. Set as the AWS_ROLE_ARN repository variable."
  value       = module.github_oidc.role_arn
}

output "database_endpoint" {
  description = "RDS endpoint. Reachable only from inside the VPC."
  value       = module.rds.endpoint
}

output "database_name" {
  description = "Name of the application database."
  value       = module.rds.database_name
}

output "database_secret_name" {
  description = "Secrets Manager secret holding the database master credentials."
  value       = module.rds.master_user_secret_arn
}

output "application_secret_name" {
  description = "Name of the application secret. Seed JWT_SECRET into it before the first deploy."
  value       = aws_secretsmanager_secret.application.name
}

output "load_balancer_controller_role_arn" {
  description = "IRSA role for the AWS Load Balancer Controller service account."
  value       = module.irsa_load_balancer_controller.role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role for the External Secrets Operator service account."
  value       = module.irsa_external_secrets.role_arn
}


output "alarm_topic_arn" {
  description = "SNS topic CloudWatch alarms publish to."
  value       = module.observability.alarm_topic_arn
}

output "application_namespace" {
  description = "Namespace the application is deployed into."
  value       = local.app_namespace
}

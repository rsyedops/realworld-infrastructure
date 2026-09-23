output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA certificate for the API server."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group EKS manages for control plane to node traffic."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider backing IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "Issuer host of the cluster OIDC provider, without the scheme."
  value       = local.oidc_issuer_host
}

output "node_role_arn" {
  description = "IAM role assumed by the managed node groups."
  value       = aws_iam_role.node.arn
}

output "node_group_names" {
  description = "Names of the managed node groups."
  value       = [for ng in aws_eks_node_group.this : ng.node_group_name]
}

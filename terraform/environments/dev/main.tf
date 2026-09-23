data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Project     = var.project
  }

  # One repository per application repository. They are built and released
  # independently, so they get independent registries.
  ecr_repositories = ["${var.project}/frontend", "${var.project}/backend"]

  app_namespace = var.project
}

module "vpc" {
  source = "../../modules/vpc"

  name                    = local.name
  cidr_block              = var.vpc_cidr
  availability_zone_count = var.availability_zone_count
  nat_gateway_strategy    = var.nat_gateway_strategy
  cluster_name            = local.name

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs

  node_groups              = var.eks_node_groups
  cluster_admin_principals = concat(var.cluster_admin_principals, [module.github_oidc.role_arn])

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name               = local.name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Only traffic from a pod in this cluster can reach the database.
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  database_name  = replace(var.project, "-", "_")
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  multi_az       = var.db_multi_az

  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot

  tags = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = local.ecr_repositories
  force_delete = var.ecr_force_delete

  tags = local.common_tags
}

module "github_oidc" {
  source = "../../modules/iam-github-oidc"

  name = "${local.name}-github-deploy"

  create_oidc_provider = false
  oidc_provider_arn    = var.github_oidc_provider_arn

  subjects = [
    for repo in var.github_repositories : "repo:${repo}:ref:${var.github_deploy_ref}"
  ]

  ecr_repository_arns = values(module.ecr.repository_arns)
  eks_cluster_arns    = ["arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.name}"]

  tags = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  name              = local.name
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  alarm_email_subscriptions = var.alarm_email_subscriptions

  db_instance_identifier   = module.rds.instance_identifier
  load_balancer_arn_suffix = var.ingress_load_balancer_arn_suffix

  tags = local.common_tags
}

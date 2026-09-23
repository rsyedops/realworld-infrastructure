# Provisions and reconciles the ALB that fronts the ingress. The policy is the
# upstream one published with the controller release; narrowing it by hand tends
# to break on the next controller version.
module "irsa_load_balancer_controller" {
  source = "../../modules/iam-irsa"

  name              = "${local.name}-aws-load-balancer-controller"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = "kube-system"
  service_account   = "aws-load-balancer-controller"

  create_inline_policy = true
  inline_policy_json   = file("${path.module}/policies/aws-load-balancer-controller.json")

  tags = local.common_tags
}

data "aws_iam_policy_document" "external_secrets" {
  # Scoped to the two secrets the application needs, not to Secrets Manager as a whole.
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.application.arn,
      module.rds.master_user_secret_arn,
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["kms:Decrypt"]
    resources = [
      aws_kms_key.application_secrets.arn,
      module.rds.kms_key_arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.region}.amazonaws.com"]
    }
  }
}

module "irsa_external_secrets" {
  source = "../../modules/iam-irsa"

  name              = "${local.name}-external-secrets"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  # Bound to the application namespace rather than the operator: a namespaced
  # SecretStore can only reference a service account in its own namespace, and
  # scoping it here keeps the operator itself without AWS permissions.
  namespace       = local.app_namespace
  service_account = "conduit-secrets"

  create_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.external_secrets.json

  tags = local.common_tags
}

# Scoped by service and, where the API supports it, by resource. Terraform needs
# broad verbs inside each service because it creates and destroys whole stacks,
# but it has no access to services this project does not use.
#
# The wildcard warnings below are accepted deliberately. A role that provisions a
# VPC, a cluster and a database cannot be written without service level verbs,
# and most of the create APIs involved do not support resource level scoping at
# all. The parts that can be narrowed are: state access is limited to one bucket,
# and role management is limited to names beginning with the project prefix.
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "terraform" {
  statement {
    sid    = "State"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
  }

  # Networking, the cluster data plane, and the managed services this project
  # provisions. These APIs are largely not resource-scopable for create actions.
  statement {
    sid    = "Provision"
    effect = "Allow"
    actions = [
      "autoscaling:Describe*",
      "ec2:*",
      "ecr:*",
      "eks:*",
      "elasticloadbalancing:Describe*",
      "kms:*",
      "logs:*",
      "rds:*",
      "secretsmanager:*",
      "sns:*",
    ]
    resources = ["*"]
  }

  # Confined to the roles this project owns, so the pipeline cannot mint or
  # modify identities outside its own namespace.
  statement {
    sid    = "ProjectIdentities"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-*"]
  }

  # The cluster's IRSA provider is created per cluster and its name is not known
  # until EKS issues the OIDC issuer URL.
  statement {
    sid    = "IrsaProvider"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"]
  }

  statement {
    sid       = "ReadOnlyIam"
    effect    = "Allow"
    actions   = ["iam:ListRoles", "iam:ListOpenIDConnectProviders", "iam:GetPolicy", "iam:GetPolicyVersion"]
    resources = ["*"]
  }

  # EKS, RDS and the load balancer controller each create a service-linked role
  # on first use.
  statement {
    sid       = "ServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*"]
  }

  statement {
    sid       = "Identity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform" {
  name   = "terraform-deploy"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.terraform.json
}

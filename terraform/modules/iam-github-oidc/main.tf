locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.oidc_provider_arn
}

# Short-lived credentials minted per workflow run. No AWS access keys live in
# GitHub, so there is nothing to rotate and nothing to leak from a secret store.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC endpoint sits behind a public CA and AWS validates the chain
  # itself; this value is retained only because the API still requires it.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringLike so branch and environment patterns can be expressed, but the
    # repository is always pinned.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.subjects
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = var.max_session_duration

  tags = var.tags
}

data "aws_iam_policy_document" "deploy" {
  # The auth token is account-scoped and cannot be narrowed to a repository.
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [1] : []

    content {
      sid    = "EcrPush"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImageScanFindings",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
      ]
      resources = var.ecr_repository_arns
    }
  }

  # The deploy step reads the database endpoint and the ARN of the RDS-managed
  # secret so the manifests need no account-specific values committed.
  statement {
    sid       = "RdsDiscovery"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }

  # Only enough to assemble a kubeconfig. What the role may do inside the cluster
  # is a separate decision, made by an EKS access entry bound to this role.
  dynamic "statement" {
    for_each = length(var.eks_cluster_arns) > 0 ? [1] : []

    content {
      sid       = "EksDescribe"
      effect    = "Allow"
      actions   = ["eks:DescribeCluster"]
      resources = var.eks_cluster_arns
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.deploy.json
}

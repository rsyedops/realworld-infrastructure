locals {
  subnet_ids       = concat(var.private_subnet_ids, var.public_subnet_ids)
  oidc_issuer_host = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "secrets_kms" {
  statement {
    sid       = "AllowAccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowEksEnvelopeEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cluster.arn]
    }
  }
}

# Envelope-encrypts Kubernetes Secrets in etcd, so a control plane snapshot alone
# is not enough to read them.
resource "aws_kms_key" "secrets" {
  description             = "${var.name} EKS secret envelope encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.secrets_kms.json

  tags = merge(var.tags, { Name = "${var.name}-eks-secrets" })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name}-eks-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_security_group" "cluster" {
  name        = "${var.name}-cluster"
  description = "EKS control plane"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-cluster" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster_all" {
  security_group_id = aws_security_group.cluster.id
  description       = "Control plane egress to nodes and AWS APIs"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Created ahead of the cluster so retention applies from the first log event; EKS
# would otherwise create this group with no expiry.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.control_plane_log_retention_days

  tags = var.tags
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = local.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.secrets.arn
    }
    resources = ["secrets"]
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size
  labels         = each.value.labels

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  # Replacements come up before old nodes drain, so a version bump never drops
  # capacity below the desired size.
  update_config {
    max_unavailable_percentage = 33
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })

  lifecycle {
    # desired_size is owned by the autoscaler once the group is live.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

data "aws_partition" "current" {}

resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alarm_email_subscriptions)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

# Container Insights collects pod and node metrics plus container stdout,
# replacing a hand-rolled Fluent Bit and CloudWatch agent deployment with one
# managed addon.
data "aws_iam_policy_document" "cloudwatch_agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_agent" {
  name               = "${var.name}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_agent_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = var.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  service_account_role_arn    = aws_iam_role.cloudwatch_agent.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags
}

# The addon creates this group on first write; declaring it here attaches a
# retention policy so container logs do not accumulate indefinitely.
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.application_log_retention_days

  tags = var.tags
}

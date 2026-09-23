# Run once, locally, with your own credentials. Everything Terraform needs before
# the pipeline can authenticate or store state lives here. Its own state stays
# local, because there is no remote backend yet.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Access logging is skipped on purpose. It needs a second bucket to receive the
# logs, and the only writer here is the pipeline role, whose activity is already
# recorded in CloudTrail.
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # The demo is meant to be torn down, and the pipeline state is reproducible.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 rather than a customer managed key. A KMS key here would have to exist
# before the bucket that holds the state describing it, which is the kind of
# ordering problem bootstrap code should not have.
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.infrastructure_repository}:ref:${var.deploy_ref}"]
    }
  }
}

resource "aws_iam_role" "terraform" {
  name               = "${var.project}-terraform-deploy"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

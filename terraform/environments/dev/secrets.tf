# Container only. Terraform never writes a version, so no application secret
# material reaches the state file. Seed it once per environment with:
#   aws secretsmanager put-secret-value --secret-id <arn> \
#     --secret-string "{\"JWT_SECRET\":\"$(openssl rand -base64 48)\"}"
resource "aws_kms_key" "application_secrets" {
  description             = "${local.name} application secret encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(local.common_tags, { Name = "${local.name}-app-secrets" })
}

resource "aws_kms_alias" "application_secrets" {
  name          = "alias/${local.name}-app-secrets"
  target_key_id = aws_kms_key.application_secrets.key_id
}

resource "aws_secretsmanager_secret" "application" {
  name        = "${local.name}/application"
  description = "Application secrets for ${local.name}, consumed by External Secrets."
  kms_key_id  = aws_kms_key.application_secrets.arn

  recovery_window_in_days = 30

  tags = local.common_tags
}

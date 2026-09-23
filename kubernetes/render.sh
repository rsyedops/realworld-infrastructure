#!/usr/bin/env bash
# Fills in the values that only exist once the infrastructure has been applied.
# Everything here is read back from the live account, so no account-specific
# value is committed and no manual variable copying is required.
set -euo pipefail

PROJECT="${PROJECT:-conduit}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
NAME="${PROJECT}-${ENVIRONMENT}"
: "${AWS_REGION:?AWS_REGION must be set}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

read -r DB_HOST DB_NAME DB_SECRET_ARN < <(
  aws rds describe-db-instances \
    --db-instance-identifier "$NAME" \
    --query 'DBInstances[0].[Endpoint.Address,DBName,MasterUserSecret.SecretArn]' \
    --output text
)

export AWS_REGION DB_HOST DB_NAME DB_SECRET_ARN
export APP_SECRET_NAME="${NAME}/application"
export EXTERNAL_SECRETS_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${NAME}-external-secrets"

target="$(dirname "$0")/overlays/${ENVIRONMENT}/patch-external-secret.yaml"
tmp="$(mktemp)"
envsubst '$AWS_REGION $DB_HOST $DB_NAME $DB_SECRET_ARN $APP_SECRET_NAME $EXTERNAL_SECRETS_ROLE_ARN' \
  < "$target" > "$tmp"
mv "$tmp" "$target"

echo "rendered ${ENVIRONMENT}: db=${DB_HOST}/${DB_NAME}"

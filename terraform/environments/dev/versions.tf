terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0, < 6.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0, < 3.0.0"
    }
  }

  # State lives in S3 with lockfile-based locking, so no DynamoDB table is needed.
  # That is why this root requires Terraform 1.10 or newer; the bucket and key are
  # supplied by -backend-config at init.
  backend "s3" {}
}

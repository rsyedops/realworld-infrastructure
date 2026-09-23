resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.kms_key_arn == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(var.tags, { Name = each.value })
}

# Untagged layers accumulate on every rebuild; released images are capped so the
# registry does not grow without bound.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_image_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Retain the most recent ${var.max_tagged_images} released images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = var.release_tag_prefixes
          countType     = "imageCountMoreThan"
          countNumber   = var.max_tagged_images
        }
        action = { type = "expire" }
      },
    ]
  })
}

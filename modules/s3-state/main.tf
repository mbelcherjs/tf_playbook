# S3 State Module - Reusable module for creating S3 buckets with best practices

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = var.bucket_name
  })

  lifecycle {
    prevent_destroy = true
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "bucket" {
  count = var.lifecycle_enabled ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "lifecycle-rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    dynamic "expiration" {
      for_each = var.expiration_days != null ? [1] : []
      content {
        days = var.expiration_days
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = var.noncurrent_version_expiration_days != null ? [1] : []
      content {
        noncurrent_days = var.noncurrent_version_expiration_days
      }
    }

    dynamic "transition" {
      for_each = var.transition_to_ia_days != null ? [1] : []
      content {
        days          = var.transition_to_ia_days
        storage_class = "STANDARD_IA"
      }
    }

    dynamic "transition" {
      for_each = var.transition_to_glacier_days != null ? [1] : []
      content {
        days          = var.transition_to_glacier_days
        storage_class = "GLACIER"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.bucket]
}

# S3 Bucket Notification (optional)
resource "aws_s3_bucket_notification" "bucket_notification" {
  count = length(var.notification_configurations) > 0 ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  dynamic "lambda_function" {
    for_each = var.notification_configurations
    content {
      lambda_function_arn = lambda_function.value.lambda_function_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }
}
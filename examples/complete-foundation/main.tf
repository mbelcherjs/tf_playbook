# Complete Foundation Example
# This example demonstrates a complete AWS infrastructure foundation

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration - uncomment after setting up backend
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "examples/complete-foundation/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Example     = "complete-foundation"
    }
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Example     = "complete-foundation"
  }
}

# VPC with complete networking
module "vpc" {
  source = "../../modules/vpc"

  project_name         = "${var.project_name}-foundation"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_count  = 3
  private_subnet_count = 3
  enable_nat_gateway   = true
  nat_gateway_count    = 3 # One per AZ for high availability

  tags = local.common_tags
}

# Security groups for different tiers
module "security" {
  source = "../../modules/security"

  project_name      = "${var.project_name}-foundation"
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  enable_ssh_access = true
  ssh_cidr_blocks   = ["10.0.0.0/8"] # Restrict SSH to private networks

  tags = local.common_tags
}

# IAM roles for various services
module "iam" {
  source = "../../modules/iam"

  project_name       = "${var.project_name}-foundation"
  create_lambda_role = true
  lambda_vpc_access  = true
  create_ecs_roles   = true

  tags = local.common_tags
}

# Additional S3 buckets for application data
module "app_data_bucket" {
  source = "../../modules/s3-state"

  bucket_name                        = "${var.project_name}-app-data-${var.environment}-${random_id.bucket_suffix.hex}"
  versioning_enabled                 = true
  lifecycle_enabled                  = true
  transition_to_ia_days              = 30
  transition_to_glacier_days         = 90
  noncurrent_version_expiration_days = 365

  tags = merge(local.common_tags, {
    Purpose = "application-data"
  })
}

module "logs_bucket" {
  source = "../../modules/s3-state"

  bucket_name        = "${var.project_name}-logs-${var.environment}-${random_id.bucket_suffix.hex}"
  versioning_enabled = false
  lifecycle_enabled  = true
  expiration_days    = 30

  tags = merge(local.common_tags, {
    Purpose = "logs"
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/application/${var.project_name}-foundation"
  retention_in_days = 30

  tags = local.common_tags
}

# Parameter Store for configuration
resource "aws_ssm_parameter" "app_config" {
  name  = "/${var.project_name}/foundation/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "private_subnets" {
  name  = "/${var.project_name}/foundation/private_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.private_subnet_ids)

  tags = local.common_tags
}

resource "aws_ssm_parameter" "public_subnets" {
  name  = "/${var.project_name}/foundation/public_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.public_subnet_ids)

  tags = local.common_tags
}
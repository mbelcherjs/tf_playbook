# Development Environment Configuration
# This example shows how to use the foundational modules

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure after running the backend setup
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket-name"
  #   key            = "environments/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-locks-table"
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
    }
  }
}

# Local values for configuration
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  enable_nat_gateway   = var.enable_nat_gateway
  nat_gateway_count    = var.nat_gateway_count

  tags = local.common_tags
}

# Security Module
module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  enable_ssh_access = var.enable_ssh_access
  ssh_cidr_blocks   = var.ssh_cidr_blocks

  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name       = var.project_name
  create_lambda_role = var.create_lambda_role
  lambda_vpc_access  = var.lambda_vpc_access
  create_ecs_roles   = var.create_ecs_roles

  tags = local.common_tags
}
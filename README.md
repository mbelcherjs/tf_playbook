# Terraform Playbook

A comprehensive collection of Terraform templates for building foundational AWS infrastructure with proper state management.

## 🏗️ Architecture Overview

This repository provides a modular Terraform infrastructure foundation that includes:

- **S3 Remote State Backend** - Secure, versioned Terraform state storage
- **VPC Module** - Complete networking with public/private subnets and NAT gateways
- **Security Module** - Pre-configured security groups for common use cases
- **IAM Module** - Standard roles and policies for EC2, Lambda, and ECS
- **S3 Module** - Reusable S3 buckets with best practices

## 📁 Repository Structure

```
tf_playbook/
├── backend/                 # S3 + DynamoDB backend setup
├── modules/                 # Reusable Terraform modules
│   ├── vpc/                # VPC with subnets, NAT gateways, routing
│   ├── security/           # Security groups for web, SSH, database, etc.
│   ├── iam/                # IAM roles for EC2, Lambda, ECS
│   └── s3-state/           # S3 buckets with lifecycle and encryption
├── environments/           # Environment-specific configurations
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment
│   └── prod/              # Production environment
└── examples/              # Example implementations
    └── complete-foundation/ # Complete infrastructure example
```

## 🚀 Quick Start

### 1. Set Up Terraform State Backend

First, create the S3 bucket and DynamoDB table for storing Terraform state:

```bash
cd backend/
terraform init
terraform plan
terraform apply
```

After applying, note the output values for your backend configuration.

### 2. Configure Backend for Your Environment

Update your environment configuration (e.g., `environments/dev/main.tf`) with the backend details:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket-name"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-terraform-locks-table"
    encrypt        = true
  }
}
```

### 3. Deploy Foundation Infrastructure

```bash
cd environments/dev/
terraform init
terraform plan
terraform apply
```

## 📦 Modules

### VPC Module

Creates a complete VPC with public and private subnets across multiple AZs:

```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  project_name         = "my-project"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_count = 3
  private_subnet_count = 3
  enable_nat_gateway  = true
  nat_gateway_count   = 3
}
```

**Features:**
- Public and private subnets across multiple AZs
- Internet Gateway for public subnet internet access
- NAT Gateways for private subnet outbound connectivity
- Route tables with appropriate routing

### Security Module

Provides common security groups for different tiers:

```hcl
module "security" {
  source = "../../modules/security"
  
  project_name      = "my-project"
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = module.vpc.vpc_cidr_block
  enable_ssh_access = true
  ssh_cidr_blocks  = ["10.0.0.0/8"]
}
```

**Includes:**
- Web security group (HTTP/HTTPS)
- SSH security group (configurable CIDR blocks)
- Database security group (MySQL/PostgreSQL)
- Internal VPC communication security group
- Application Load Balancer security group

### IAM Module

Creates standard IAM roles and policies:

```hcl
module "iam" {
  source = "../../modules/iam"
  
  project_name       = "my-project"
  create_lambda_role = true
  lambda_vpc_access  = true
  create_ecs_roles   = true
}
```

**Provides:**
- EC2 instance role with CloudWatch Logs and SSM access
- Lambda execution role (optional)
- ECS task execution and task roles (optional)
- Instance profiles for EC2 instances

### S3 Module

Reusable S3 bucket configuration with security best practices:

```hcl
module "app_bucket" {
  source = "../../modules/s3-state"
  
  bucket_name        = "my-app-data-bucket"
  versioning_enabled = true
  lifecycle_enabled  = true
  transition_to_ia_days = 30
}
```

**Features:**
- Server-side encryption (AES256 or KMS)
- Versioning support
- Lifecycle management
- Public access blocking
- Optional event notifications

## 🌍 Environment Management

### Development Environment

```bash
cd environments/dev/
terraform workspace new dev  # Optional: use workspaces
terraform init
terraform apply
```

### Staging Environment

```bash
cd environments/staging/
terraform workspace new staging
terraform init
terraform apply
```

### Production Environment

```bash
cd environments/prod/
terraform workspace new prod
terraform init
terraform apply
```

## 🔧 Configuration Variables

### Common Variables

All modules support these common variables:

- `project_name` - Name prefix for all resources
- `tags` - Additional tags to apply to resources
- `aws_region` - AWS region for deployment

### VPC-Specific Variables

- `vpc_cidr` - CIDR block for VPC (default: "10.0.0.0/16")
- `public_subnet_count` - Number of public subnets (default: 2)
- `private_subnet_count` - Number of private subnets (default: 2)
- `enable_nat_gateway` - Enable NAT gateways (default: true)
- `nat_gateway_count` - Number of NAT gateways (default: 1)

### Security-Specific Variables

- `enable_ssh_access` - Create SSH security group (default: false)
- `ssh_cidr_blocks` - CIDR blocks for SSH access (default: ["0.0.0.0/0"])

## 📋 Examples

### Complete Foundation Example

See `examples/complete-foundation/` for a comprehensive example that demonstrates:

- Multi-AZ VPC with high availability
- Complete security group setup
- IAM roles for multiple services
- S3 buckets for different purposes
- CloudWatch logging
- SSM Parameter Store integration

```bash
cd examples/complete-foundation/
terraform init
terraform plan
terraform apply
```

## 🔒 Security Best Practices

This playbook implements several security best practices:

1. **S3 Buckets:**
   - Server-side encryption enabled
   - Public access blocked by default
   - Versioning enabled for state buckets
   - Lifecycle policies for cost optimization

2. **IAM:**
   - Least privilege principle
   - Service-specific roles
   - No inline policies in production

3. **VPC:**
   - Private subnets for sensitive resources
   - NAT gateways for controlled outbound access
   - Security groups with minimal required access

4. **State Management:**
   - Remote state in S3 with encryption
   - State locking with DynamoDB
   - Separate state files per environment

## 🔄 State Management

### Backend Configuration

The backend setup creates:
- S3 bucket with versioning and encryption
- DynamoDB table for state locking
- Proper IAM permissions

### State File Organization

```
terraform-state-bucket/
├── backend/terraform.tfstate           # Backend infrastructure state
├── environments/
│   ├── dev/terraform.tfstate          # Development environment
│   ├── staging/terraform.tfstate      # Staging environment
│   └── prod/terraform.tfstate         # Production environment
└── examples/
    └── complete-foundation/terraform.tfstate
```

## 🛠️ Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- AWS account with necessary service quotas

### Required AWS Permissions

The following AWS permissions are required:

- EC2: Full access for VPC, subnets, security groups
- IAM: Create and manage roles, policies, instance profiles
- S3: Create and manage buckets, bucket policies
- DynamoDB: Create and manage tables
- CloudWatch: Create log groups
- SSM: Create and manage parameters

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `terraform plan`
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

1. **Backend bucket already exists:** Ensure bucket names are unique globally
2. **Insufficient permissions:** Check AWS credentials and IAM permissions
3. **State lock conflicts:** Wait for locks to clear or force-unlock if necessary

### Getting Help

- Check the Terraform documentation
- Review AWS service documentation
- Open an issue in this repository for bugs or feature requests

---

**Note:** Always review and test Terraform plans before applying in production environments.

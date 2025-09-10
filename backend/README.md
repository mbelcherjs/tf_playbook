# Backend Setup

This directory contains the Terraform configuration for setting up the S3 backend and DynamoDB table required for storing Terraform state.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0 installed
- Appropriate AWS permissions (S3, DynamoDB, IAM)

## Usage

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Review the plan:**
   ```bash
   terraform plan
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply
   ```

4. **Note the outputs:**
   After applying, make note of the S3 bucket name and DynamoDB table name for use in other configurations.

## Outputs

- `s3_bucket_name` - The name of the S3 bucket created for state storage
- `dynamodb_table_name` - The name of the DynamoDB table for state locking
- `backend_config` - Complete backend configuration object

## Configuration Variables

- `aws_region` - AWS region for resources (default: us-east-1)
- `project_name` - Project name prefix (default: tf-playbook)

## Example terraform.tfvars

```hcl
aws_region   = "us-west-2"
project_name = "my-project"
```

## Security Features

- S3 bucket with server-side encryption
- Versioning enabled for state recovery
- Public access blocked
- DynamoDB table for state locking
- Lifecycle prevention on critical resources

## After Setup

Once this backend is created, you can use it in other Terraform configurations:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-bucket-name-from-output"
    key            = "path/to/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-table-name-from-output"
    encrypt        = true
  }
}
```

## Important Notes

- This configuration has `prevent_destroy = true` on the S3 bucket and DynamoDB table
- The bucket name includes a random suffix to ensure global uniqueness
- Run this setup before deploying any other infrastructure
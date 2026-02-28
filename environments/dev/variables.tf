# Variables for Development Environment

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "tf-playbook"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways"
  type        = number
  default     = 1
}

# Security Variables
variable "enable_ssh_access" {
  description = "Enable SSH access"
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# IAM Variables
variable "create_lambda_role" {
  description = "Create Lambda role"
  type        = bool
  default     = true
}

variable "lambda_vpc_access" {
  description = "Enable Lambda VPC access"
  type        = bool
  default     = true
}

variable "create_ecs_roles" {
  description = "Create ECS roles"
  type        = bool
  default     = true
}
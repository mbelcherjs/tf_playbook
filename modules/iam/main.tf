# IAM Module - Common IAM roles and policies

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# EC2 Instance Role
resource "aws_iam_role" "ec2_role" {
  name_prefix = "${var.project_name}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-role"
  })
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${var.project_name}-ec2-"
  role        = aws_iam_role.ec2_role.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-profile"
  })
}

# Basic EC2 Policy for CloudWatch Logs and SSM
resource "aws_iam_role_policy" "ec2_basic_policy" {
  name_prefix = "${var.project_name}-ec2-basic-"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

# Attach SSM Managed Instance Core policy
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_role" {
  count = var.create_lambda_role ? 1 : 0

  name_prefix = "${var.project_name}-lambda-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-lambda-role"
  })
}

# Lambda Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count = var.create_lambda_role ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Access Policy (if Lambda needs VPC access)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count = var.create_lambda_role && var.lambda_vpc_access ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  count = var.create_ecs_roles ? 1 : 0

  name_prefix = "${var.project_name}-ecs-task-execution-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-task-execution-role"
  })
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  count = var.create_ecs_roles ? 1 : 0

  name_prefix = "${var.project_name}-ecs-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-task-role"
  })
}

# ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  count = var.create_ecs_roles ? 1 : 0

  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
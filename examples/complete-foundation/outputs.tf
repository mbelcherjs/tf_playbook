output "foundation_summary" {
  description = "Complete foundation infrastructure summary"
  value = {
    # VPC Information
    vpc = {
      id                 = module.vpc.vpc_id
      cidr               = module.vpc.vpc_cidr_block
      public_subnet_ids  = module.vpc.public_subnet_ids
      private_subnet_ids = module.vpc.private_subnet_ids
      nat_gateway_ids    = module.vpc.nat_gateway_ids
    }

    # Security Groups
    security_groups = {
      web      = module.security.web_security_group_id
      ssh      = module.security.ssh_security_group_id
      database = module.security.database_security_group_id
      internal = module.security.internal_security_group_id
      alb      = module.security.alb_security_group_id
    }

    # IAM Roles
    iam_roles = {
      ec2_instance_profile_name   = module.iam.ec2_instance_profile_name
      lambda_role_arn             = module.iam.lambda_role_arn
      ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
      ecs_task_role_arn           = module.iam.ecs_task_role_arn
    }

    # S3 Buckets
    s3_buckets = {
      app_data_bucket = module.app_data_bucket.bucket_id
      logs_bucket     = module.logs_bucket.bucket_id
    }

    # CloudWatch
    cloudwatch = {
      log_group_name = aws_cloudwatch_log_group.app_logs.name
    }

    # SSM Parameters
    ssm_parameters = {
      vpc_id_parameter          = aws_ssm_parameter.app_config.name
      private_subnets_parameter = aws_ssm_parameter.private_subnets.name
      public_subnets_parameter  = aws_ssm_parameter.public_subnets.name
    }
  }
}

output "next_steps" {
  description = "Suggested next steps for using this foundation"
  value = [
    "1. Deploy EC2 instances using the created IAM instance profile and security groups",
    "2. Set up an Application Load Balancer in the public subnets with the ALB security group",
    "3. Deploy RDS databases in private subnets with the database security group",
    "4. Use the S3 buckets for application data and logs",
    "5. Configure applications to read configuration from SSM Parameter Store",
    "6. Use the CloudWatch log group for application logging"
  ]
}
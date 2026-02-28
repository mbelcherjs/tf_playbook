# Outputs for Development Environment

output "vpc_info" {
  description = "VPC information"
  value = {
    vpc_id              = module.vpc.vpc_id
    vpc_cidr            = module.vpc.vpc_cidr_block
    public_subnet_ids   = module.vpc.public_subnet_ids
    private_subnet_ids  = module.vpc.private_subnet_ids
    internet_gateway_id = module.vpc.internet_gateway_id
    nat_gateway_ids     = module.vpc.nat_gateway_ids
  }
}

output "security_groups" {
  description = "Security group information"
  value = {
    web_sg      = module.security.web_security_group_id
    ssh_sg      = module.security.ssh_security_group_id
    database_sg = module.security.database_security_group_id
    internal_sg = module.security.internal_security_group_id
    alb_sg      = module.security.alb_security_group_id
  }
}

output "iam_roles" {
  description = "IAM role information"
  value = {
    ec2_role_arn                = module.iam.ec2_role_arn
    ec2_instance_profile_name   = module.iam.ec2_instance_profile_name
    lambda_role_arn             = module.iam.lambda_role_arn
    ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
    ecs_task_role_arn           = module.iam.ecs_task_role_arn
  }
}

output "environment_summary" {
  description = "Summary of the environment"
  value = {
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region
    vpc_cidr     = var.vpc_cidr
  }
}
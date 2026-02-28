output "ec2_role_arn" {
  description = "ARN of the EC2 role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_role_name" {
  description = "Name of the EC2 role"
  value       = aws_iam_role.ec2_role.name
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda role"
  value       = var.create_lambda_role ? aws_iam_role.lambda_role[0].arn : null
}

output "lambda_role_name" {
  description = "Name of the Lambda role"
  value       = var.create_lambda_role ? aws_iam_role.lambda_role[0].name : null
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = var.create_ecs_roles ? aws_iam_role.ecs_task_execution_role[0].arn : null
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = var.create_ecs_roles ? aws_iam_role.ecs_task_role[0].arn : null
}
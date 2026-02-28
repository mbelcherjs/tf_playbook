output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "ssh_security_group_id" {
  description = "ID of the SSH security group"
  value       = var.enable_ssh_access ? aws_security_group.ssh[0].id : null
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "internal_security_group_id" {
  description = "ID of the internal security group"
  value       = aws_security_group.internal.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    web      = aws_security_group.web.id
    ssh      = var.enable_ssh_access ? aws_security_group.ssh[0].id : null
    database = aws_security_group.database.id
    internal = aws_security_group.internal.id
    alb      = aws_security_group.alb.id
  }
}
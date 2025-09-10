variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "create_lambda_role" {
  description = "Create Lambda execution role"
  type        = bool
  default     = false
}

variable "lambda_vpc_access" {
  description = "Enable VPC access for Lambda role"
  type        = bool
  default     = false
}

variable "create_ecs_roles" {
  description = "Create ECS task execution and task roles"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
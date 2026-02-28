variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption"
  type        = string
  default     = null
}

variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

variable "lifecycle_enabled" {
  description = "Enable lifecycle management"
  type        = bool
  default     = false
}

variable "expiration_days" {
  description = "Number of days after which objects expire"
  type        = number
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after which noncurrent object versions expire"
  type        = number
  default     = null
}

variable "transition_to_ia_days" {
  description = "Number of days after which objects transition to Standard-IA"
  type        = number
  default     = null
}

variable "transition_to_glacier_days" {
  description = "Number of days after which objects transition to Glacier"
  type        = number
  default     = null
}

variable "notification_configurations" {
  description = "List of S3 bucket notification configurations"
  type = list(object({
    lambda_function_arn = string
    events              = list(string)
    filter_prefix       = optional(string)
    filter_suffix       = optional(string)
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
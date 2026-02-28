output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.bucket.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "Route 53 Hosted Zone ID of the S3 bucket"
  value       = aws_s3_bucket.bucket.hosted_zone_id
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.bucket.region
}
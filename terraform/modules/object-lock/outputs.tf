# Outputs

output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "object_lock_mode" {
  description = "The object lock mode"
  value       = var.object_lock_mode
}

output "retention_days" {
  description = "The retention period in days"
  value       = var.retention_days
}

output "retention_years" {
  description = "The retention period in years"
  value       = var.retention_years
}

output "logging_bucket_id" {
  description = "The name of the logging bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.logging[0].id : null
}

output "compliance_level" {
  description = "The compliance level of the bucket"
  value       = var.compliance_level
}

output "retention_period" {
  description = "The retention period"
  value = var.retention_days != null ? "${var.retention_days} days" : "${var.retention_years} years"
}

output "logging_bucket_arn" {
  description = "The ARN of the logging bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.logging[0].arn : null
}

output "versioning_status" {
  description = "The versioning status (always Enabled for Object Lock)"
  value       = "Enabled"
}

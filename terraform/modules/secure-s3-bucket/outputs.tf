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

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.this.region
}

output "bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region"
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "versioning_status" {
  description = "The versioning state of the bucket"
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

output "encryption_algorithm" {
  description = "The server-side encryption algorithm used"
  value       = [for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm][0]
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = var.kms_master_key_id
}

output "logging_bucket_id" {
  description = "The name of the logging bucket"
  value       = var.enable_access_logging && var.logging_bucket_name == "" ? aws_s3_bucket.logging[0].id : null
}

output "logging_bucket_arn" {
  description = "The ARN of the logging bucket"
  value       = var.enable_access_logging && var.logging_bucket_name == "" ? aws_s3_bucket.logging[0].arn : null
}

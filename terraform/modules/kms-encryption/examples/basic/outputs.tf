# Outputs
output "kms_key_id" {
  description = "The ID of the KMS key"
  value       = module.kms_s3_encryption.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = module.kms_s3_encryption.key_arn
}

output "kms_key_alias" {
  description = "The alias of the KMS key"
  value       = module.kms_s3_encryption.key_alias
}

output "test_bucket_name" {
  description = "Name of the test S3 bucket"
  value       = aws_s3_bucket.test.id
}

output "test_bucket_arn" {
  description = "ARN of the test S3 bucket"
  value       = aws_s3_bucket.test.arn
}

output "encryption_enabled" {
  description = "Confirmation that encryption is enabled"
  value       = "Bucket is encrypted with KMS key: ${module.kms_s3_encryption.key_alias}"
}

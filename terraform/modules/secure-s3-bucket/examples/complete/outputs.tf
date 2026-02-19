output "kms_key_id" {
  description = "KMS key ID"
  value       = module.kms_s3_key.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = module.kms_s3_key.key_arn
}

output "kms_key_alias" {
  description = "KMS key alias"
  value       = module.kms_s3_key.key_alias
}

output "basic_bucket_name" {
  description = "Basic bucket name"
  value       = module.basic_bucket.bucket_id
}

output "basic_bucket_arn" {
  description = "Basic bucket ARN"
  value       = module.basic_bucket.bucket_arn
}

output "advanced_bucket_name" {
  description = "Advanced bucket name"
  value       = module.advanced_bucket.bucket_id
}

output "advanced_bucket_arn" {
  description = "Advanced bucket ARN"
  value       = module.advanced_bucket.bucket_arn
}

output "cors_bucket_name" {
  description = "CORS bucket name"
  value       = module.cors_bucket.bucket_id
}

output "logging_bucket_name" {
  description = "Logging bucket name (for basic bucket)"
  value       = module.basic_bucket.logging_bucket_id
}

output "test_file_url" {
  description = "S3 URL of test file in basic bucket"
  value       = "s3://${module.basic_bucket.bucket_id}/${aws_s3_object.test_basic.key}"
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value       = <<-EOT
    Deployment Summary
    
    KMS Key:
    - ID: ${module.kms_s3_key.key_id}
    - Alias: ${module.kms_s3_key.key_alias}
    - Rotation: Enabled
    
    Buckets Created:
    1. Basic Bucket: ${module.basic_bucket.bucket_id}
       - Encryption: KMS
       - Versioning: Enabled
       - Logging: Enabled
    
    2. Advanced Bucket: ${module.advanced_bucket.bucket_id}
       - Encryption: KMS
       - Versioning: Enabled
       - Logging: Enabled
       - Lifecycle: 4 transitions
       - Monitoring: Enabled
    
    3. CORS Bucket: ${module.cors_bucket.bucket_id}
       - Encryption: KMS
       - CORS: Enabled
       - Versioning: Enabled
    
    4. Logging Bucket: ${module.basic_bucket.logging_bucket_id}
       - Purpose: Store access logs
       - Retention: 90 days
    
    Test Files Uploaded:
    - Basic: s3://${module.basic_bucket.bucket_id}/${aws_s3_object.test_basic.key}
    - Advanced: s3://${module.advanced_bucket.bucket_id}/${aws_s3_object.test_advanced.key}
    
    Next Steps:
    1. Verify encryption: aws s3api head-object --bucket ${module.basic_bucket.bucket_id} --key ${aws_s3_object.test_basic.key}
    2. Check versioning: aws s3api list-object-versions --bucket ${module.basic_bucket.bucket_id}
    3. View metrics: AWS Console → S3 → Metrics
    4. Check logs: s3://${module.basic_bucket.logging_bucket_id}/
  EOT
}

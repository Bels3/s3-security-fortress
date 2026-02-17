#Outputs
output "bucket_name" {
  description = "The S3 bucket name"
  value       = module.data_bucket.bucket_id
}

output "bucket_arn" {
  description = "The S3 bucket ARN"
  value       = module.data_bucket.bucket_arn
}

output "readonly_access_point_arn" {
  description = "Read-only access point ARN"
  value       = module.readonly_access_point.access_point_arn
}

output "readonly_access_point_alias" {
  description = "Read-only access point alias"
  value       = module.readonly_access_point.access_point_alias
}

output "upload_access_point_arn" {
  description = "Upload access point ARN"
  value       = module.upload_access_point.access_point_arn
}

output "upload_access_point_alias" {
  description = "Upload access point alias"
  value       = module.upload_access_point.access_point_alias
}

output "admin_access_point_arn" {
  description = "Admin access point ARN"
  value       = module.admin_access_point.access_point_arn
}

output "application_access_point_arn" {
  description = "Application access point ARN"
  value       = module.application_access_point.access_point_arn
}

output "application_role_arn" {
  description = "IAM role ARN for application access"
  value       = module.application_access_point.example_role_arn
}

output "test_commands" {
  description = "Commands to test access points"
  value = <<-EOT
    
    Test Commands
    
    # List files via read-only access point
    aws s3 ls s3://${module.readonly_access_point.access_point_alias}/
    
    # Download file via read-only access point
    aws s3 cp s3://${module.readonly_access_point.access_point_alias}/public/readme.txt ./
    
    # Upload file via upload access point
    echo "test" > upload-test.txt
    aws s3 cp upload-test.txt s3://${module.upload_access_point.access_point_alias}/uploads/
    
    # List all access points
    aws s3control list-access-points --account-id ${data.aws_caller_identity.current.account_id}
    
    # Get access point policy
    aws s3control get-access-point-policy \
      --account-id ${data.aws_caller_identity.current.account_id} \
      --name ${module.readonly_access_point.access_point_id}
    
  EOT
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = <<-EOT
    
    Deployment Summary - Access Points
    
    S3 Bucket:
    - Name: ${module.data_bucket.bucket_id}
    - Encryption: KMS
    - Versioning: Enabled
    
    Access Points Created:
    
    1. Read-Only Access Point
       - ARN: ${module.readonly_access_point.access_point_arn}
       - Alias: ${module.readonly_access_point.access_point_alias}
       - Permissions: GetObject, ListBucket
       - Network: Public Internet (with SSL)
       - Use Case: Public downloads
    
    2. Upload Access Point
       - ARN: ${module.upload_access_point.access_point_arn}
       - Alias: ${module.upload_access_point.access_point_alias}
       - Permissions: PutObject
       - Network: IP Restricted
       - Use Case: User uploads from office
    
    3. Admin Access Point
       - ARN: ${module.admin_access_point.access_point_arn}
       - Alias: ${module.admin_access_point.access_point_alias}
       - Permissions: Full (s3:*)
       - Network: Authenticated only
       - Use Case: Administrative access
    
    4. Application Access Point
       - ARN: ${module.application_access_point.access_point_arn}
       - Alias: ${module.application_access_point.access_point_alias}
       - Permissions: Read/Write
       - IAM Role: ${module.application_access_point.example_role_arn}
       - Use Case: EC2 application access
    
    Test Files Created:
    - public/readme.txt (via read-only AP)
    - uploads/test-upload.txt (via upload AP)
    
    Architecture:
    
    ┌────────────────────────────────────────┐
    │          S3 Bucket                     │
    │    (${module.data_bucket.bucket_id})   │
    └─────────────┬──────────────────────────┘
                  │
          ┌───────┼───────────┬───────────┐
          │       │           │           │
    ┌────▼─┐   ┌──▼───┐ ┌───▼────┐ ┌──▼─────┐
    │Read-  │  │Upload│  │Admin   │  │App     │
    │Only   │  │AP    │  │AP      │  │AP      │
    │AP     │  │      │  │        │  │        │
    └───────┘  └──────┘  └────────┘  └────────┘
    (Public)   (IP Restr)(Auth Only) (IAM Role)
    
    Next Steps:
    1. Test access points with provided commands
    2. Update your diagram in eraser.io
    3. Verify monitoring in CloudWatch
    4. Check access point policies
    
  EOT
}

# Complete S3 Security Fortress - All Phases Integrated
# This example demonstrates all modules working together

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure this after backend setup
    # bucket         = "your-state-bucket"
    # key            = "complete-integration/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Phase 1: KMS Encryption

module "kms_master_key" {
  source = "../../modules/kms-encryption"

  environment     = var.environment
  purpose         = "s3-master"
  key_name        = "${var.environment}-s3-master-encryption-key"
  key_description = "Master KMS key for S3 Security Fortress"

  enable_key_rotation     = true
  deletion_window_in_days = 30

  key_administrators = [data.aws_caller_identity.current.arn]
  key_users          = [data.aws_caller_identity.current.arn]

  allow_cloudtrail          = true
  cloudtrail_log_group_name = module.monitoring.log_group_name
  cloudtrail_log_group_arn  = module.monitoring.log_group_arn

  tags = {
    Project = "S3SecurityFortress"
    Phase   = "1-KMS"
  }
}

# Phase 2: Secure S3 Buckets
# Standard secure bucket
module "data_bucket" {
  source = "../../modules/secure-s3-bucket"

  environment = var.environment
  purpose     = "application-data"

  kms_master_key_id  = module.kms_master_key.key_arn
  bucket_key_enabled = true
  versioning_enabled = true

  enable_access_logging = true
  enable_metrics        = true

  lifecycle_rules = [
    {
      id      = "intelligent-tiering"
      enabled = true

      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" }
      ]
    }
  ]

  tags = {
    Project = "S3SecurityFortress"
    Phase   = "2-SecureS3"
  }
}

# Phase 3: S3 Access Points
# Read-only access point
module "readonly_access_point" {
  source = "../../modules/s3-access-points"

  environment = var.environment
  purpose     = "readonly"
  bucket_name = module.data_bucket.bucket_id

  allowed_actions = [
    "s3:GetObject",
    "s3:ListBucket"
  ]

  require_secure_transport = true
  enable_monitoring        = true

  tags = {
    Project = "S3SecurityFortress"
    Phase   = "3-AccessPoints"
  }
}

# Upload access point
module "upload_access_point" {
  source = "../../modules/s3-access-points"

  environment = var.environment
  purpose     = "uploads"
  bucket_name = module.data_bucket.bucket_id

  allowed_actions = [
    "s3:PutObject"
  ]

  require_secure_transport = true
  deny_unencrypted_uploads = true
  enable_monitoring        = true

  tags = {
    Project = "S3SecurityFortress"
    Phase   = "3-AccessPoints"
  }
}

# Phase 4: Object Lock Bucket
module "compliance_bucket" {
  source = "../../modules/object-lock"

  environment = var.environment
  purpose     = "compliance-data"

  object_lock_mode = "COMPLIANCE"
  retention_years  = 7
  compliance_level = "SEC17a-4"

  kms_master_key_id = module.kms_master_key.key_arn

  enable_access_logging = true
  enable_monitoring     = true
  enable_inventory      = true

  lifecycle_rules = [
    {
      id      = "archive-old-records"
      enabled = true

      transitions = [
        { days = 2556, storage_class = "GLACIER" }
      ]
    }
  ]

  tags = {
    Project    = "S3SecurityFortress"
    Phase      = "4-ObjectLock"
    Compliance = "SEC17a-4"
  }
}

# Phase 5: Presigned URL Access (The API Layer)
module "presigned_access" {
  source = "../../modules/presigned-access"

  environment = var.environment
  bucket_name = module.data_bucket.bucket_id
  kms_key_id  = module.kms_master_key.key_arn

  # Security Settings
  upload_expiration_seconds = 3600
  max_upload_size_mb        = 10

  tags = {
    Project = "S3SecurityFortress"
    Phase   = "5-APIGateway"
  }
}

# Phase 6: Monitoring & Compliance
module "monitoring" {
  source = "../../modules/monitoring-compliance"

  environment = var.environment

  kms_key_id = module.kms_master_key.key_arn

  # Monitor all created buckets
  monitored_bucket_arns = [
    module.data_bucket.bucket_arn,
    module.compliance_bucket.bucket_arn
  ]

  # CloudTrail settings
  enable_multi_region_trail       = true
  enable_advanced_event_selectors = true
  cloudtrail_log_retention_days   = 365

  # AWS Config
  enable_aws_config = true

  # CloudWatch
  enable_cloudwatch_dashboard = true

  # Alerts
  enable_sns_alerts     = true
  alert_email_addresses = var.alert_emails

  tags = {
    Project = "S3SecurityFortress"
    Phase   = "6-Monitoring"
  }
}

# Test Data Upload
resource "aws_s3_object" "test_file" {
  bucket  = module.data_bucket.bucket_id
  key     = "test/integration-test.txt"
  content = <<-EOF
    S3 Security Fortress - Integration Test
    
    Created: ${timestamp()}
    Environment: ${var.environment}
    
    Phases Integrated:
    ✓ Phase 1: KMS Encryption
    ✓ Phase 2: Secure S3 Bucket
    ✓ Phase 3: Access Points
    ✓ Phase 4: Object Lock
    ✓ Phase 6: Monitoring & Compliance
    
    Security Features:
    - KMS Encryption: ${module.kms_master_key.key_arn}
    - Versioning: Enabled
    - Access Logging: Enabled
    - CloudTrail: ${module.monitoring.cloudtrail_name}
    - AWS Config: ${module.monitoring.config_recorder_name}
  EOF

  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_master_key.key_arn
}

# Outputs
output "summary" {
  description = "Complete deployment summary"
  value       = <<-EOT
    
    ╔═══════════════════════════════════════════════════════════════╗
    ║         S3 SECURITY FORTRESS - DEPLOYMENT COMPLETE            ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    📊 PROJECT STATUS: 100% Complete
    
    ═══════════════════════════════════════════════════════════════
    PHASE 1: KMS ENCRYPTION
    ═══════════════════════════════════════════════════════════════
    KMS Key ID:     ${module.kms_master_key.key_id}
    Key Alias:      ${module.kms_master_key.key_alias}
    Rotation:       Enabled (Annual)
    
    ═══════════════════════════════════════════════════════════════
    PHASE 2: SECURE S3 BUCKETS
    ═══════════════════════════════════════════════════════════════
    Data Bucket:    ${module.data_bucket.bucket_id}
    Encryption:     KMS (aws:kms)
    Versioning:     Enabled
    Logging:        Enabled
    
    ═══════════════════════════════════════════════════════════════
    PHASE 3: ACCESS POINTS
    ═══════════════════════════════════════════════════════════════
    Read-Only AP:   ${module.readonly_access_point.access_point_arn}
    Upload AP:      ${module.upload_access_point.access_point_arn}
    
    ═══════════════════════════════════════════════════════════════
    PHASE 4: OBJECT LOCK
    ═══════════════════════════════════════════════════════════════
    Compliance Bucket: ${module.compliance_bucket.bucket_id}
    Lock Mode:      COMPLIANCE
    Retention:      7 years
    Standard:       SEC 17a-4
    
    ═══════════════════════════════════════════════════════════════
    PHASE 5: PRESIGNED ACCESS (API)
    ═══════════════════════════════════════════════════════════════
    Upload Endpoint:   ${module.presigned_access.upload_endpoint}
    Download Endpoint: ${module.presigned_access.download_endpoint}
    Lambda Functions:  2 (Active)
    
    ═══════════════════════════════════════════════════════════════
    PHASE 6: MONITORING & COMPLIANCE
    ═══════════════════════════════════════════════════════════════
    CloudTrail:     ${module.monitoring.cloudtrail_name}
    Config Recorder: ${module.monitoring.config_recorder_name}
    Dashboard:      ${module.monitoring.dashboard_name}
    SNS Topic:      ${module.monitoring.sns_topic_arn}
    
    ═══════════════════════════════════════════════════════════════
    📈 NEXT STEPS
    ═══════════════════════════════════════════════════════════════
    1. Confirm SNS email subscriptions
    2. Review CloudWatch Dashboard
    3. Check AWS Config compliance
    4. Test access points
    5. Run integration tests
    
    ═══════════════════════════════════════════════════════════════
    📚 DOCUMENTATION
    ═══════════════════════════════════════════════════════════════
    CloudWatch Dashboard: 
      https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${module.monitoring.dashboard_name}
    
    Config Compliance:
      https://console.aws.amazon.com/config/home?region=${data.aws_region.current.name}
    
    CloudTrail Events:
      https://console.aws.amazon.com/cloudtrail/home?region=${data.aws_region.current.name}
  EOT
}

output "kms_key_arn" {
  value = module.kms_master_key.key_arn
}

output "data_bucket_name" {
  value = module.data_bucket.bucket_id
}

output "compliance_bucket_name" {
  value = module.compliance_bucket.bucket_id
}

output "cloudtrail_name" {
  value = module.monitoring.cloudtrail_name
}

output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${module.monitoring.dashboard_name}"
}

#Complete example showing Object Lock with different modes
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for Encryption

module "kms_key" {
  source = "../../../kms-encryption"

  environment     = var.environment
  purpose         = "object-lock"
  key_name        = "${var.environment}-object-lock-key"
  key_description = "KMS key for object lock bucket encryption"

  enable_key_rotation     = true
  deletion_window_in_days = 30

  key_administrators = [data.aws_caller_identity.current.arn]
  key_users          = [data.aws_caller_identity.current.arn]

  tags = {
    Example = "ObjectLock-Complete"
  }
}

# Example 1: Governance Mode (Testing)

module "governance_bucket" {
  source = "../.."

  environment = var.environment
  purpose     = "governance-test"

  # Governance mode - can be bypassed with permission
  object_lock_mode = "GOVERNANCE"
  retention_days   = 30 # 30 days retention for testing

  # Security
  kms_master_key_id = module.kms_key.key_arn

  # Logging
  enable_access_logging = true

  # Monitoring
  enable_monitoring = true
  enable_inventory  = true

  tags = {
    Example     = "ObjectLock-Complete"
    Mode        = "Governance"
    Environment = "Testing"
  }
}

# Example 2: Compliance Mode (Production)

module "compliance_bucket" {
  source = "../.."

  environment = var.environment
  purpose     = "compliance-records"

  # Compliance mode - CANNOT be bypassed
  object_lock_mode = "COMPLIANCE"
  retention_years  = 7 # 7 years for regulatory compliance
  compliance_level = "SEC17a-4"

  # Maximum security
  kms_master_key_id  = module.kms_key.key_arn
  mfa_delete_enabled = false # Set to true with MFA in production

  # Require object lock on all uploads
  require_object_lock_on_upload = true

  # Comprehensive logging
  enable_access_logging  = true
  logging_retention_days = 2555 # 7 years

  # Monitoring
  enable_monitoring   = true
  enable_metrics      = true
  enable_inventory    = true
  inventory_frequency = "Daily"

  # Lifecycle (applies after retention period)
  lifecycle_rules = [
    {
      id      = "archive-old-records"
      enabled = true

      # Transition to Glacier after retention period
      transitions = [
        {
          days          = 2556 # After 7 years + 1 day
          storage_class = "GLACIER"
        },
        {
          days          = 3650 # After 10 years
          storage_class = "DEEP_ARCHIVE"
        }
      ]
    }
  ]

  tags = {
    Example       = "ObjectLock-Complete"
    Mode          = "Compliance"
    Compliance    = "SEC17a-4"
    DataRetention = "7years"
    CriticalData  = "true"
  }
}

# Example 3: Audit Logs (Short Retention)

module "audit_logs_bucket" {
  source = "../.."

  environment = var.environment
  purpose     = "audit-logs"

  # Compliance mode for audit integrity
  object_lock_mode = "COMPLIANCE"
  retention_days   = 90 # 90 days retention
  compliance_level = "SOC2"

  # Security
  kms_master_key_id = module.kms_key.key_arn

  # Logging
  enable_access_logging  = true
  logging_retention_days = 365

  # Monitoring
  enable_monitoring = true

  # Lifecycle - transition to IA after 30 days
  lifecycle_rules = [
    {
      id      = "cost-optimization"
      enabled = true

      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]

      # Expire after retention + grace period
      expiration_days = 180
    }
  ]

  tags = {
    Example    = "ObjectLock-Complete"
    Mode       = "Compliance"
    Purpose    = "AuditLogs"
    Compliance = "SOC2"
  }
}

# Upload Test Files

# Test file for governance bucket
resource "aws_s3_object" "governance_test" {
  bucket  = module.governance_bucket.bucket_id
  key     = "test/governance-test.txt"
  content = <<-EOF
    Governance Mode Test File
    Created: ${timestamp()}
    Retention: 30 days
    Mode: GOVERNANCE
    Can be deleted with: s3:BypassGovernanceRetention permission
  EOF

  # Encryption
  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_key.key_arn

  # Object lock (optional - uses bucket default if not specified)
  object_lock_mode              = "GOVERNANCE"
  object_lock_retain_until_date = timeadd(timestamp(), "720h") # 30 days from now
}

# Test file for compliance bucket
resource "aws_s3_object" "compliance_test" {
  bucket  = module.compliance_bucket.bucket_id
  key     = "records/2024/compliance-record.txt"
  content = <<-EOF
    Compliance Mode Test File
    Created: ${timestamp()}
    Retention: 7 years
    Mode: COMPLIANCE
    CANNOT be deleted until: ${timeadd(timestamp(), "61320h")}
    Even root account cannot override this lock!
  EOF

  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_key.key_arn

  # Compliance lock
  object_lock_mode              = "COMPLIANCE"
  object_lock_retain_until_date = timeadd(timestamp(), "61320h") # 7 years
}

# Test file for audit logs
resource "aws_s3_object" "audit_log_test" {
  bucket  = module.audit_logs_bucket.bucket_id
  key     = "logs/2024-02-11/app.log"
  content = <<-EOF
    [2024-02-11 10:00:00] INFO: Application started
    [2024-02-11 10:00:01] INFO: User login: user@example.com
    [2024-02-11 10:00:02] INFO: Action: view_dashboard
    Retention: 90 days
    Mode: COMPLIANCE
  EOF

  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_key.key_arn

  object_lock_mode              = "COMPLIANCE"
  object_lock_retain_until_date = timeadd(timestamp(), "2160h") # 90 days
}

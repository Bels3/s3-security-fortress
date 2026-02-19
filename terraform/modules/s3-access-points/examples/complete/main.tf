# Complete example showing S3 bucket with multiple access points
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

# KMS Key (from Phase 1)
module "kms_key" {
  source = "../../../kms-encryption"

  environment     = var.environment
  purpose         = "s3"
  key_name        = "${var.environment}-s3-encryption-key"
  key_description = "KMS key for S3 bucket encryption"

  enable_key_rotation     = true
  deletion_window_in_days = 30

  key_administrators = [data.aws_caller_identity.current.arn]
  key_users          = [data.aws_caller_identity.current.arn]

  tags = {
    Example = "AccessPoints-Complete"
  }
}

# Secure S3 Bucket (from Phase 2)
module "data_bucket" {
  source = "../../../secure-s3-bucket"

  environment = var.environment
  purpose     = "multi-access-data"

  # Security
  kms_master_key_id  = module.kms_key.key_arn
  bucket_key_enabled = true
  versioning_enabled = true

  # Logging
  enable_access_logging = true

  # Lifecycle
  lifecycle_rules = [
    {
      id      = "transition-old-data"
      enabled = true

      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
    }
  ]

  tags = {
    Example   = "AccessPoints-Complete"
    Component = "DataBucket"
  }
}

# Access Point 1: Read-Only (Public Internet)
module "readonly_access_point" {
  source = "../.."

  environment = var.environment
  purpose     = "readonly-downloads"
  bucket_name = module.data_bucket.bucket_id

  # Permissions
  allowed_actions = [
    "s3:GetObject",
    "s3:ListBucket"
  ]

  # Security
  require_secure_transport = true

  # No VPC restriction - accessible from internet
  # But with security controls

  # Monitoring
  enable_monitoring = true

  tags = {
    Example     = "AccessPoints-Complete"
    AccessType  = "ReadOnly"
    NetworkType = "Public"
  }
}

# Access Point 2: Upload-Only with IP Restriction
module "upload_access_point" {
  source = "../.."

  environment = var.environment
  purpose     = "uploads"
  bucket_name = module.data_bucket.bucket_id

  # Write-only access
  allowed_actions = [
    "s3:PutObject",
    "s3:PutObjectAcl"
  ]

  # IP whitelist (example IPs - replace with your IPs)
  source_ip_whitelist = var.office_ip_ranges

  # Security
  require_secure_transport = true
  deny_unencrypted_uploads = true

  # Monitoring with stricter thresholds
  enable_monitoring             = true
  unauthorized_access_threshold = 5 # Alert faster

  tags = {
    Example     = "AccessPoints-Complete"
    AccessType  = "WriteOnly"
    NetworkType = "IPRestricted"
  }
}

# Access Point 3: Full Access for Current User

module "admin_access_point" {
  source = "../.."

  environment = var.environment
  purpose     = "admin"
  bucket_name = module.data_bucket.bucket_id

  # Full access
  allowed_actions = [
    "s3:*"
  ]

  # Only specific principals
  allowed_principals = [
    data.aws_caller_identity.current.arn
  ]

  # Security
  require_secure_transport = true
  require_mfa              = false # Set to true in production with MFA setup

  # Monitoring
  enable_monitoring = true

  tags = {
    Example     = "AccessPoints-Complete"
    AccessType  = "Admin"
    NetworkType = "Authenticated"
  }
}

# Create Example IAM Role
module "application_access_point" {
  source = "../.."

  environment = var.environment
  purpose     = "application"
  bucket_name = module.data_bucket.bucket_id

  # Application needs read/write
  allowed_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket"
  ]

  # Create example role that can use this access point
  create_example_iam_role        = true
  example_role_service_principal = "ec2.amazonaws.com"

  # Security
  require_secure_transport = true
  deny_unencrypted_uploads = true

  tags = {
    Example    = "AccessPoints-Complete"
    AccessType = "Application"
    Purpose    = "EC2Application"
  }
}

# Upload Test Files
# Test file for readonly access
resource "aws_s3_object" "test_readonly" {
  # FIX: Use the ARN output from the module directly
  bucket  = module.readonly_access_point.access_point_arn
  key     = "public/readme.txt"
  content = <<-EOF
    This file is accessible via the read-only access point.
    Access Point: ${module.readonly_access_point.access_point_arn}
    Created: ${timestamp()}
  EOF

  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_key.key_arn
}

# Test file for upload access point
resource "aws_s3_object" "test_upload" {
  # FIX: Use the ARN output from the module directly
  bucket  = module.upload_access_point.access_point_arn
  key     = "uploads/test-upload.txt"
  content = <<-EOF
    This file was uploaded via the upload access point.
    Access Point: ${module.upload_access_point.access_point_arn}
    Created: ${timestamp()}
  EOF

  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_key.key_arn
}


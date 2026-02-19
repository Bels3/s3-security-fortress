# Complete example showing KMS + Secure S3 Bucket integration
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

# Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for S3 Encryption
module "kms_s3_key" {
  source = "../../../kms-encryption"

  environment     = var.environment
  purpose         = "s3"
  key_name        = "${var.environment}-s3-master-key"
  key_description = "Master KMS key for S3 bucket encryption"

  # Security settings
  enable_key_rotation     = true
  deletion_window_in_days = 30

  # Access control - current user as admin and user
  key_administrators = [data.aws_caller_identity.current.arn]
  key_users          = [data.aws_caller_identity.current.arn]

  # Allow S3 service
  allow_cloudtrail = false

  tags = {
    Example   = "Complete-S3-Integration"
    Component = "Encryption"
  }
}

# Secure S3 Bucket - Basic Configuration
module "basic_bucket" {
  source = "../.."

  environment = var.environment
  purpose     = "basic-data"

  # Use KMS encryption
  kms_master_key_id  = module.kms_s3_key.key_arn
  bucket_key_enabled = true # Reduce KMS costs

  # Security basics
  versioning_enabled    = true
  enable_access_logging = true

  tags = {
    Example   = "Complete-S3-Integration"
    Component = "BasicBucket"
    Owner     = var.owner_email
  }
}

# Secure S3 Bucket - Advanced Configuration
module "advanced_bucket" {
  source = "../.."

  environment         = var.environment
  purpose             = "advanced-data"
  security_level      = "critical"
  data_classification = "restricted"

  # KMS encryption
  kms_master_key_id  = module.kms_s3_key.key_arn
  bucket_key_enabled = true

  # Maximum security
  versioning_enabled            = true
  mfa_delete_enabled            = false # Set to true in prod with MFA
  enforce_encryption_in_transit = true

  # All public access blocked
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Comprehensive logging
  enable_access_logging  = true
  logging_retention_days = 90

  # Monitoring
  enable_metrics      = true
  enable_inventory    = true
  inventory_frequency = "Weekly"

  # Lifecycle management for cost optimization
  lifecycle_rules = [
    {
      id      = "intelligent-lifecycle"
      enabled = true

      # Transition to cheaper storage classes
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 180
          storage_class = "DEEP_ARCHIVE"
        }
      ]

      # Clean up old versions
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]

      noncurrent_version_expiration_days = 90

      # Clean up incomplete uploads
      abort_incomplete_multipart_upload_days = 7
    },
    {
      id              = "cleanup-temp-files"
      enabled         = true
      filter_prefix   = "temp/"
      expiration_days = 7
    }
  ]

  # Custom bucket policies
  custom_bucket_policy_statements = [
    {
      sid       = "AllowKMSPutOnly"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["arn:aws:s3:::${var.environment}-advanced-data-${data.aws_caller_identity.current.account_id}/*"]
      principals = [{
        type        = "AWS"
        identifiers = [data.aws_caller_identity.current.arn]
      }]
      conditions = [{
        test     = "StringLike"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms"]
      }]
    },
    {
      sid       = "AllowSimpleGet"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.environment}-advanced-data-${data.aws_caller_identity.current.account_id}/*"]
      principals = [{
        type        = "AWS"
        identifiers = [data.aws_caller_identity.current.arn]
      }]
      # We must include an empty list to satisfy the module's for_each
      conditions = []
    }
  ]

  tags = {
    Example     = "Complete-S3-Integration"
    Component   = "AdvancedBucket"
    Compliance  = "SOC2-HIPAA"
    BackupLevel = "Critical"
    Owner       = var.owner_email
  }
}

# Secure S3 Bucket - With CORS
module "cors_bucket" {
  source = "../.."

  environment = var.environment
  purpose     = "api-uploads"

  # Encryption
  kms_master_key_id = module.kms_s3_key.key_arn

  # Versioning
  versioning_enabled = true

  # CORS for API access
  cors_rules = [
    {
      allowed_methods = ["GET", "POST", "PUT"]
      allowed_origins = ["https://example.com", "https://app.example.com"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  ]

  # Lifecycle - clean up old uploads
  lifecycle_rules = [
    {
      id              = "expire-uploads"
      enabled         = true
      filter_prefix   = "uploads/"
      expiration_days = 30
    }
  ]

  tags = {
    Example   = "Complete-S3-Integration"
    Component = "CORSBucket"
    Purpose   = "APIUploads"
  }
}

# Test File Upload
# Create a test file to upload
resource "local_file" "test_file" {
  content  = "This is a test file created at ${timestamp()}"
  filename = "${path.module}/test-file.txt"
}

# Upload test file to basic bucket
resource "aws_s3_object" "test_basic" {
  bucket = module.basic_bucket.bucket_id
  key    = "test-files/test-file.txt"
  source = local_file.test_file.filename

  # Explicit KMS encryption
  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_s3_key.key_arn

  # Metadata
  metadata = {
    uploaded-by = "terraform"
    environment = var.environment
  }

}

# Upload test file to advanced bucket
resource "aws_s3_object" "test_advanced" {
  bucket = module.advanced_bucket.bucket_id
  key    = "test-files/test-file.txt"
  source = local_file.test_file.filename

  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms_s3_key.key_arn

  # Object tags
  tags = {
    Classification = "Test"
    Purpose        = "Verification"
  }
}


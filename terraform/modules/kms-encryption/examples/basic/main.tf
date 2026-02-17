# Basic working example of the KMS encryption module
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
# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Create KMS Key using our module

module "kms_s3_encryption" {
  source = "../.."  # Path to module
  
  # Basic configuration
  environment     = var.environment
  purpose         = "s3"
  key_name        = "${var.environment}-s3-encryption-key"
  key_description = "KMS key for S3 bucket encryption in ${var.environment}"
  
  # Security settings
  enable_key_rotation     = true   # IMPORTANT: Always enable in production
  deletion_window_in_days = 30     # Maximum protection window
  multi_region            = false  # Single region for this example
  
  # Access control - Replace with your actual ARNs
  key_administrators = [
    # Current user/role as administrator
    data.aws_caller_identity.current.arn
  ]
  
  key_users = [
    # Current user/role as user
    data.aws_caller_identity.current.arn,
    # Add S3 service principal would go here when integrated
  ]
  
  # Service integration
  allow_cloudtrail      = false
  allow_cloudwatch_logs = false
  
  # Monitoring
  enable_monitoring    = false  # Disable for basic example
  alarm_sns_topic_arns = []     # Add SNS topics if monitoring enabled
  
  # Tags
  tags = {
    Example     = "KMS-Basic"
    Terraform   = "true"
    Owner       = var.owner_email
    CostCenter  = var.cost_center
  }
}

# Test S3 Bucket using the KMS key

# Create a test bucket to demonstrate KMS encryption
resource "aws_s3_bucket" "test" {
  bucket = "${var.environment}-kms-test-bucket-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "KMS Test Bucket"
    Environment = var.environment
    Example     = "KMS-Basic"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "test" {
  bucket = aws_s3_bucket.test.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure encryption using our KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "test" {
  bucket = aws_s3_bucket.test.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms_s3_encryption.key_arn
    }
    bucket_key_enabled = true  # Reduces KMS costs
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "test" {
  bucket = aws_s3_bucket.test.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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

# Use existing KMS key and bucket from previous phases
data "aws_s3_bucket" "existing" {
  bucket = var.bucket_name
}

data "aws_kms_key" "existing" {
  key_id = var.kms_key_id
}

# Create presigned URLs module
module "presigned_urls" {
  source = "../.."
  
  environment   = var.environment
  bucket_name   = data.aws_s3_bucket.existing.id
  kms_key_id    = data.aws_kms_key.existing.arn
  
  # Expiration times
  upload_expiration_seconds   = 300  # 5 minutes
  download_expiration_seconds = 300  # 5 minutes
  
  # Upload restrictions
  max_upload_size_mb = 10
  allowed_content_types = [
    "image/jpeg",
    "image/png",
    "application/pdf",
    "text/plain"
  ]
  
  # Lambda configuration
  lambda_timeout     = 10
  lambda_memory_size = 128
  
  # API Gateway
  create_api_gateway        = true
  api_gateway_authorization = "NONE"  # Change to AWS_IAM for production
  
  # Monitoring
  enable_monitoring = true
  log_retention_days = 7
  
  tags = {
    Example = "Presigned-URLs-Complete"
    Module  = "presigned-access"
  }
}



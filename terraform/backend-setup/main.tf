# This creates the S3 bucket and DynamoDB table for Terraform state management
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

  default_tags {
    tags = {
      Project     = "S3SecurityFortress"
      ManagedBy   = "Terraform"
      Purpose     = "TerraformBackend"
      Environment = "shared"
    }
  }
}

# S3 Bucket for Terraform State
# This bucket stores the terraform.tfstate files
# It's separate from our application buckets
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name        = "Terraform State Bucket"
    Description = "Stores Terraform state files"
  }
}

# Enable versioning - critical for state files!
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest using AES256
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access - state files contain sensitive data!
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging for audit trail
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-access-logs/"
}

# Lifecycle policy to manage old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90  # Keep old versions for 90 days
    }
  }

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"  # Move to cheaper storage after 30 days
    }
  }
}

# S3 Bucket for Access Logs
# Separate bucket for logging - AWS best practice
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "${var.state_bucket_name}-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Logs"
    Description = "Access logs for Terraform state bucket"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for logs - delete after retention period
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90  # Keep logs for 90 days
    }
  }

  rule {
    id     = "transition-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = var.lock_table_name
  billing_mode   = "PAY_PER_REQUEST"  # No need to provision capacity
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Enable encryption at rest
  server_side_encryption {
    enabled = true
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Description = "Prevents concurrent state modifications"
  }
}

# IAM Policy for Backend Access

# This policy can be attached to users/roles that need to use Terraform
data "aws_iam_policy_document" "terraform_backend_policy" {
  # Allow state file operations
  statement {
    sid    = "AllowStateFileAccess"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]

    resources = [
      aws_s3_bucket.terraform_state.arn
    ]
  }

  statement {
    sid    = "AllowStateFileOperations"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }

  # Allow state locking
  statement {
    sid    = "AllowStateLocking"
    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]

    resources = [
      aws_dynamodb_table.terraform_state_lock.arn
    ]
  }
}

resource "aws_iam_policy" "terraform_backend_policy" {
  name        = "TerraformBackendAccess"
  description = "Allows access to Terraform state backend"
  policy      = data.aws_iam_policy_document.terraform_backend_policy.json

  tags = {
    Name        = "Terraform Backend Access Policy"
    Description = "Grants necessary permissions for Terraform operations"
  }
}

# Outputs
output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.arn
}

output "backend_policy_arn" {
  description = "ARN of the IAM policy for backend access"
  value       = aws_iam_policy.terraform_backend_policy.arn
}

output "backend_config" {
  description = "Backend configuration to use in other Terraform projects"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
    region         = var.aws_region
    encrypt        = true
  }
}

# Instructions for Next Steps

output "next_steps" {
  description = "Instructions for using this backend"
  value = <<-EOT
    
    ✅ Backend Setup Complete!
    
    Add this to your Terraform configurations:
    
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "environments/ENV_NAME/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
        encrypt        = true
      }
    }
    
    Replace ENV_NAME with: dev, staging, or prod
    
    Next: Deploy your first secure S3 bucket!
    cd terraform/environments/dev
    terraform init
    terraform plan
    
  EOT
}

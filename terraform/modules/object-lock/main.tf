# Object Lock Module - WORM Storage for Compliance
# Implements Write-Once-Read-Many storage with retention policies
# Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.environment}-${var.purpose}-locked-${data.aws_caller_identity.current.account_id}"
  
  common_tags = merge(
    {
      Name              = local.bucket_name
      Environment       = var.environment
      Purpose           = var.purpose
      ManagedBy         = "Terraform"
      Module            = "object-lock"
      ObjectLockMode    = var.object_lock_mode
      RetentionPeriod   = var.retention_days != null ? "${var.retention_days} days" : var.retention_years != null ? "${var.retention_years} years" : "N/A"
      ComplianceLevel   = var.compliance_level
    },
    var.tags
  )
}

# S3 Bucket with Object Lock
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
  
  # Object Lock MUST be enabled at creation time
  object_lock_enabled = true
  
  # Prevent accidental deletion
  force_destroy = var.force_destroy
  
  tags = local.common_tags
}

# Versioning (Required for Object Lock)
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  
  versioning_configuration {
    status = "Enabled"  # Required for Object Lock
    
    # MFA delete adds additional protection
    mfa_delete = var.mfa_delete_enabled ? "Enabled" : "Disabled"
  }
}

# Object Lock Configuration
resource "aws_s3_bucket_object_lock_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  
  # Object Lock must be enabled on bucket first
  rule {
    default_retention {
      mode = var.object_lock_mode  # GOVERNANCE or COMPLIANCE
      
      # Retention period - use days OR years (not both)
      days  = var.retention_days
      years = var.retention_years
    }
  }
  
  depends_on = [aws_s3_bucket_versioning.this]
}

# Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_master_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_master_key_id != "" ? var.kms_master_key_id : null
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id
  
  block_public_acls       = true  # Always true for locked buckets
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Policy
data "aws_iam_policy_document" "bucket_policy" {
  # Enforce SSL/TLS
  statement {
    sid    = "EnforceSSLOnly"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:*"]
    
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
    
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  
  # Require Object Lock on uploads (optional additional control)
  dynamic "statement" {
    for_each = var.require_object_lock_on_upload ? [1] : []
    
    content {
      sid    = "RequireObjectLockOnUpload"
      effect = "Deny"
      
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      
      actions = ["s3:PutObject"]
      
      resources = ["${aws_s3_bucket.this.arn}/*"]
      
      condition {
        test     = "Null"
        variable = "s3:object-lock-retain-until-date"
        values   = ["true"]
      }
    }
  }
  
  # Additional custom statements
  dynamic "statement" {
    for_each = var.custom_bucket_policy_statements
    
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
      
      dynamic "principals" {
        for_each = lookup(statement.value, "principals", [])
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
      
      dynamic "condition" {
        for_each = lookup(statement.value, "conditions", [])
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Access Logging
resource "aws_s3_bucket" "logging" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = "${local.bucket_name}-logs"
  
  tags = merge(
    local.common_tags,
    {
      Name    = "${local.bucket_name}-logs"
      Purpose = "AccessLogging"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logging" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logging" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    
    filter {}
    
    expiration {
      days = var.logging_retention_days
    }
  }
}

resource "aws_s3_bucket_logging" "this" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.this.id
  
  target_bucket = aws_s3_bucket.logging[0].id
  target_prefix = "access-logs/"
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
  
  dynamic "rule" {
    for_each = var.lifecycle_rules
    
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"
      
      filter {}  # Empty filter applies to all objects
      
      # Note: Lifecycle rules cannot delete objects under retention
      # They only apply after retention period expires
      
      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", null) != null ? rule.value.transitions : []
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
      
      # Expiration only works after retention period
      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", null) != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }
      
      dynamic "noncurrent_version_transition" {
        for_each = lookup(rule.value, "noncurrent_version_transitions", null) != null ? rule.value.noncurrent_version_transitions : []
        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }
      
      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_version_expiration_days", null) != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
    }
  }
  
  depends_on = [aws_s3_bucket_versioning.this]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "object_lock_bypass_attempts" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.bucket_name}-lock-bypass-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on attempts to bypass object lock"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    BucketName = aws_s3_bucket.this.id
  }
  
  alarm_actions = var.alarm_sns_topic_arns
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_delete_attempts" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${local.bucket_name}-delete-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DeleteRequests"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on any delete attempts on locked bucket"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    BucketName = aws_s3_bucket.this.id
  }
  
  alarm_actions = var.alarm_sns_topic_arns
  
  tags = local.common_tags
}

# Bucket Metrics
resource "aws_s3_bucket_metric" "this" {
  count  = var.enable_metrics ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucket"
}

# Inventory Configuration
resource "aws_s3_bucket_inventory" "this" {
  count  = var.enable_inventory ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "ObjectLockInventory"
  
  included_object_versions = "All"
  
  schedule {
    frequency = var.inventory_frequency
  }
  
  destination {
    bucket {
      format     = "CSV"
      bucket_arn = var.inventory_destination_bucket_arn != "" ? var.inventory_destination_bucket_arn : aws_s3_bucket.this.arn
      prefix     = "inventory/"
      
      dynamic "encryption" {
        for_each = var.kms_master_key_id != "" ? [1] : []
        content {
          sse_kms {
            key_id = var.kms_master_key_id
          }
        }
      }
    }
  }
  
  optional_fields = [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag",
    "ObjectLockRetainUntilDate",
    "ObjectLockMode",
    "ObjectLockLegalHoldStatus"
  ]
}

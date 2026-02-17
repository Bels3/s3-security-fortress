# Secure S3 Bucket Module - Production-Ready Implementation
# Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Generate bucket name if not provided
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.environment}-${var.purpose}-${data.aws_caller_identity.current.account_id}"
  
  # Common tags
  common_tags = merge(
    {
      Name              = local.bucket_name
      Environment       = var.environment
      Purpose           = var.purpose
      ManagedBy         = "Terraform"
      Module            = "secure-s3-bucket"
      SecurityLevel     = var.security_level
      DataClassification = var.data_classification
    },
    var.tags
  )
  
  # Logging bucket name
  logging_bucket_name = var.logging_bucket_name != "" ? var.logging_bucket_name : "${local.bucket_name}-logs"
}

# S3 Bucket

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  
  tags = local.common_tags
}

# Versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  
  versioning_configuration {
    status     = var.versioning_enabled ? "Enabled" : "Suspended"
    mfa_delete = var.mfa_delete_enabled ? "Enabled" : "Disabled"
  }
}

# Server-Side Encryption
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

# Block Public Access
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id
  
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
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
  
  # Enforce encryption on uploads
  dynamic "statement" {
    for_each = var.enforce_encryption_in_transit ? [1] : []
    
    content {
      sid    = "DenyUnencryptedObjectUploads"
      effect = "Deny"
      
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      
      actions = ["s3:PutObject"]
      
      resources = ["${aws_s3_bucket.this.arn}/*"]
      
      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = var.kms_master_key_id != "" ? ["aws:kms"] : ["AES256", "aws:kms"]
      }
    }
  }
  
  # Deny insecure TLS versions
  statement {
    sid    = "DenyInsecureTLS"
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
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
  
  # Additional custom policy statements
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

# Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
  
  dynamic "rule" {
    for_each = var.lifecycle_rules
    
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      # Use ONE filter block that optionally takes a prefix
      filter {
        prefix = lookup(rule.value, "filter_prefix", "")
      }
      
      # Transitions
      dynamic "transition" {
        for_each = try(rule.value.transitions, []) == null ? [] : try(rule.value.transitions, [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
      
      # Expiration
      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", null) != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }
      
      # Non-current version transitions
      dynamic "noncurrent_version_transition" {
       for_each = try(rule.value.noncurrent_version_transitions, []) == null ? [] : try(rule.value.noncurrent_version_transitions, [])
        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }
      
      # Non-current version expiration
      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_version_expiration_days", null) != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
      
      # Abort incomplete multipart uploads
      dynamic "abort_incomplete_multipart_upload" {
        for_each = lookup(rule.value, "abort_incomplete_multipart_upload_days", null) != null ? [1] : []
        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }
    }
  }
}

# Access Logging
resource "aws_s3_bucket" "logging" {
  count  = var.enable_access_logging && var.logging_bucket_name == "" ? 1 : 0
  bucket = local.logging_bucket_name
  
  tags = merge(
    local.common_tags,
    {
      Name    = local.logging_bucket_name
      Purpose = "AccessLogging"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logging" {
  count  = var.enable_access_logging && var.logging_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logging" {
  count  = var.enable_access_logging && var.logging_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  count  = var.enable_access_logging && var.logging_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle for logging bucket
resource "aws_s3_bucket_lifecycle_configuration" "logging" {
  count  = var.enable_access_logging && var.logging_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    
    filter {}
    
    expiration {
      days = var.logging_retention_days
    }
    
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

# Enable access logging
resource "aws_s3_bucket_logging" "this" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.this.id
  
  target_bucket = var.logging_bucket_name != "" ? var.logging_bucket_name : aws_s3_bucket.logging[0].id
  target_prefix = var.logging_prefix != "" ? var.logging_prefix : "access-logs/${local.bucket_name}/"
}

# CORS Configuration

resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
  
  dynamic "cors_rule" {
    for_each = var.cors_rules
    
    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
}

# Intelligent Tiering

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  count  = var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucket"
  
  status = "Enabled"
  
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# Replication Configuration

resource "aws_s3_bucket_replication_configuration" "this" {
  count  = var.enable_replication ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = var.replication_role_arn
  
  rule {
    id     = "replicate-all"
    status = "Enabled"
    
    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = var.replication_storage_class
      
      dynamic "encryption_configuration" {
        for_each = var.replication_kms_key_id != "" ? [1] : []
        content {
          replica_kms_key_id = var.replication_kms_key_id
        }
      }
    }
    
    dynamic "source_selection_criteria" {
      for_each = var.kms_master_key_id != "" ? [1] : []
      content {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }
    }
  }
  
  depends_on = [aws_s3_bucket_versioning.this]
}

# Object Ownership

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  
  rule {
    object_ownership = var.object_ownership
  }
}

# Request Metrics

resource "aws_s3_bucket_metric" "this" {
  count  = var.enable_metrics ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucket"
}

# Inventory Configuration

resource "aws_s3_bucket_inventory" "this" {
  count  = var.enable_inventory ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucketInventory"
  
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
    "IsMultipartUploaded",
    "ReplicationStatus",
    "EncryptionStatus"
  ]
}



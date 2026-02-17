# KMS Key Module - Customer Managed Keys for S3 Encryption
# This module creates and manages KMS keys with best practices
locals {
  # Generate unique alias name
  key_alias = var.key_alias != "" ? var.key_alias : "alias/${var.environment}-${var.purpose}-key"
  
  # Common tags merged with custom tags
  common_tags = merge(
    {
      Name        = var.key_name
      Environment = var.environment
      Purpose     = var.purpose
      ManagedBy   = "Terraform"
      Module      = "kms-encryption"
    },
    var.tags
  )
}

# KMS Customer Managed Key

resource "aws_kms_key" "this" {
  description = var.key_description
  
  # Key rotation - CRITICAL for security
  # Automatically rotates key material every 365 days
  enable_key_rotation = var.enable_key_rotation
  
  # Deletion window - safety net against accidental deletion
  # 7-30 days, defaults to 30
  deletion_window_in_days = var.deletion_window_in_days
  
  # Multi-region key for cross-region replication if needed
  multi_region = var.multi_region
  
  # Key policy - who can use and manage this key
  policy = data.aws_iam_policy_document.kms_key_policy.json
  
  tags = local.common_tags
}

# KMS Key Alias
# Alias makes it easier to reference keys
# Format: alias/env-purpose-key
resource "aws_kms_alias" "this" {
  name          = local.key_alias
  target_key_id = aws_kms_key.this.key_id
}

# KMS Key Policy

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  # Statement 1: Root account has full control
  # This is required by AWS and allows IAM policies to work
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    
    actions = ["kms:*"]
    
    resources = ["*"]
  }
  
  # Statement 2: Key administrators can manage but not use key
  statement {
    sid    = "Allow Key Administrators"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = var.key_administrators
    }
    
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    
    resources = ["*"]
  }
  
  # Statement 3: Key users can encrypt/decrypt
  statement {
    sid    = "Allow Key Usage"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = var.key_users
    }
    
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]
    
    resources = ["*"]
    
    # Optional: Restrict usage to specific encryption contexts
    dynamic "condition" {
      for_each = length(var.encryption_context_keys) > 0 ? [1] : []
      
      content {
        test     = "StringEquals"
        variable = "kms:EncryptionContext:${var.encryption_context_keys[0]}"
        values   = var.encryption_context_values
      }
    }
  }
  
  # Statement 4: Allow S3 service to use key
  statement {
    sid    = "Allow S3 Service"
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    
    resources = ["*"]
    
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  
  # Statement 5: Allow CloudTrail to use key for log encryption
  dynamic "statement" {
    for_each = var.allow_cloudtrail ? [1] : []
    
    content {
      sid    = "Allow CloudTrail"
      effect = "Allow"
      
      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }
      
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey*"
      ]
      
      resources = ["*"]
      
      condition {
        test     = "StringLike"
        variable = "kms:EncryptionContext:aws:cloudtrail:arn"
        values = [
          "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
        ]
      }
    }
  }
  
  # Statement 6: Allow CloudWatch Logs
  dynamic "statement" {
    for_each = var.allow_cloudwatch_logs ? [1] : []
    
    content {
      sid    = "Allow CloudWatch Logs"
      effect = "Allow"
      
      principals {
        type        = "Service"
        identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
      }
      
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:CreateGrant"
      ]
      
      resources = ["*"]
      
      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        ]
      }
    }
  }
  
  # Statement 7: Deny unencrypted uploads (defense in depth)
  dynamic "statement" {
    for_each = var.deny_unencrypted_uploads ? [1] : []
    
    content {
      sid    = "Deny Unencrypted Uploads"
      effect = "Deny"
      
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      
      actions = [
        "kms:Decrypt"
      ]
      
      resources = ["*"]
      
      condition {
        test     = "StringNotEquals"
        variable = "kms:ViaService"
        values = [
          "s3.${data.aws_region.current.name}.amazonaws.com"
        ]
      }
    }
  }
}

# CloudWatch Alarms for Key Usage

# Monitor key usage for anomalies
resource "aws_cloudwatch_log_metric_filter" "kms_key_deletion_attempts" {
  #count = var.enable_monitoring ? 1 : 0
  # ONLY create this if we explicitly enable monitoring AND have a log group
  count = (var.allow_cloudtrail && var.cloudtrail_log_group_name != "") ? 1 : 0
  
  name           = "${var.key_name}-deletion-attempts"
  log_group_name = var.cloudtrail_log_group_name
  pattern = "[eventName = ScheduleKeyDeletion || eventName = DisableKey]"
  
  depends_on = [var.cloudtrail_log_group_arn]
  
  metric_transformation {
    name      = "KMSKeyDeletionAttempts"
    namespace = "KMS/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "kms_key_deletion_alarm" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.key_name}-deletion-attempt"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KMSKeyDeletionAttempts"
  namespace           = "KMS/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on KMS key deletion attempts"
  treat_missing_data  = "notBreaching"
  
  alarm_actions = var.alarm_sns_topic_arns
  
  tags = local.common_tags
}

# KMS Grant for S3 Bucket

# Grants allow S3 to use the key without requiring bucket policy changes
resource "aws_kms_grant" "s3_grant" {
  count = var.create_s3_grant ? 1 : 0
  
  name              = "${var.key_name}-s3-grant"
  key_id            = aws_kms_key.this.key_id
  grantee_principal = "s3.amazonaws.com"
  
  operations = [
    "Encrypt",
    "Decrypt",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "ReEncryptFrom",
    "ReEncryptTo",
    "DescribeKey"
  ]
  
  constraints {
    encryption_context_equals = var.grant_encryption_context
  }
}

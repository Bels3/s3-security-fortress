# Monitoring & Compliance Module - CloudTrail, Config, and CloudWatch
# Provides complete audit trail and compliance monitoring
# Data Sources

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local Variables
locals {
  trail_name = var.trail_name != "" ? var.trail_name : "${var.environment}-s3-security-trail"

  common_tags = merge(
    {
      Name        = local.trail_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "monitoring-compliance"
    },
    var.tags
  )
}

# CloudTrail S3 Bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.environment}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  tags = merge(
    local.common_tags,
    {
      Purpose = "CloudTrailLogs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : null
    }
    bucket_key_enabled = true
  }
}

# CloudTrail bucket policy
data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:GetBucketAcl"]

    resources = [aws_s3_bucket.cloudtrail.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = ["${aws_s3_bucket.cloudtrail.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

# Lifecycle for CloudTrail logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    filter {}

    expiration {
      days = var.cloudtrail_log_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CloudTrail

resource "aws_cloudtrail" "this" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = var.enable_multi_region_trail
  enable_logging                = true

  # KMS encryption for CloudTrail logs
  kms_key_id = var.kms_key_id

  # Advanced event selectors for more granular control
  dynamic "advanced_event_selector" {
    for_each = var.enable_advanced_event_selectors ? [1] : []

    content {
      name = "Log all S3 data events"

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }

      field_selector {
        field  = "resources.type"
        equals = ["AWS::S3::Object"]
      }

      field_selector {
        field       = "resources.ARN"
        starts_with = var.monitored_bucket_arns
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
  enable_log_file_validation = true
  sns_topic_name = aws_sns_topic.trail_notifications.name
  cloud_watch_logs_group_arn  = var.enable_cloudwatch_logs ? "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*" : null
  cloud_watch_logs_role_arn   = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail_cloudwatch[0].arn : null
  tags = local.common_tags
}

resource "aws_sns_topic" "trail_notifications" {
  name = "${var.environment}-cloudtrail-notifications"
  kms_master_key_id = "alias/aws/sns" # Encrypt the topic
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.kms_key_id

  tags = local.common_tags
}

# IAM role for CloudTrail to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name = "${local.trail_name}-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name = "${local.trail_name}-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}

# AWS Config
# S3 bucket for Config
resource "aws_s3_bucket" "config" {
  count = var.enable_aws_config ? 1 : 0

  bucket        = "${var.environment}-aws-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy

  tags = merge(
    local.common_tags,
    {
      Purpose = "AWSConfig"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "config" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Config bucket policy
data "aws_iam_policy_document" "config_bucket_policy" {
  count = var.enable_aws_config ? 1 : 0

  statement {
    sid    = "AWSConfigBucketPermissionsCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["s3:GetBucketAcl"]

    resources = [aws_s3_bucket.config[0].arn]
  }

  statement {
    sid    = "AWSConfigBucketExistenceCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["s3:ListBucket"]

    resources = [aws_s3_bucket.config[0].arn]
  }

  statement {
    sid    = "AWSConfigBucketWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = ["${aws_s3_bucket.config[0].arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  policy = data.aws_iam_policy_document.config_bucket_policy[0].json
}

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_aws_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-config-s3-policy"
  role = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.config[0].arn,
          "${aws_s3_bucket.config[0].arn}/*"
        ]
      }
    ]
  })
}

# Config Recorder
resource "aws_config_configuration_recorder" "this" {
  count = var.enable_aws_config ? 1 : 0

  name     = "${var.environment}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Config Delivery Channel
resource "aws_config_delivery_channel" "this" {
  count = var.enable_aws_config ? 1 : 0

  name           = "${var.environment}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].bucket

  depends_on = [aws_config_configuration_recorder.this]
}

# Start Config Recorder
resource "aws_config_configuration_recorder_status" "this" {
  count = var.enable_aws_config ? 1 : 0

  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

# AWS Config Rules for S3
# Rule: S3 bucket encryption enabled
resource "aws_config_config_rule" "s3_bucket_encryption" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-s3-bucket-encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# Rule: S3 bucket versioning enabled
resource "aws_config_config_rule" "s3_bucket_versioning" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-s3-bucket-versioning"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# Rule: S3 bucket public read prohibited
resource "aws_config_config_rule" "s3_bucket_public_read" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# Rule: S3 bucket public write prohibited
resource "aws_config_config_rule" "s3_bucket_public_write" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# Rule: S3 bucket logging enabled
resource "aws_config_config_rule" "s3_bucket_logging" {
  count = var.enable_aws_config ? 1 : 0

  name = "${var.environment}-s3-bucket-logging-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LOGGING_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "s3_security" {
  count = var.enable_cloudwatch_dashboard ? 1 : 0

  dashboard_name = "${var.environment}-s3-security-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", { stat = "Average" }],
            [".", "BucketSizeBytes", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "S3 Storage Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "AllRequests", { stat = "Sum" }],
            [".", "GetRequests", { stat = "Sum" }],
            [".", "PutRequests", { stat = "Sum" }],
            [".", "DeleteRequests", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "S3 Request Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "4xxErrors", { stat = "Sum" }],
            [".", "5xxErrors", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "S3 Error Metrics"
        }
      }
    ]
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  count = var.enable_sns_alerts ? 1 : 0

  name              = "${var.environment}-s3-security-alerts"
  kms_master_key_id = var.kms_key_id

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alert_email" {
  count = var.enable_sns_alerts && length(var.alert_email_addresses) > 0 ? length(var.alert_email_addresses) : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

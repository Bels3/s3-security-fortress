# S3 Access Points Module - Network-Isolated Access to S3 Buckets
# Provides dedicated, policy-controlled entry points to S3 buckets
# Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Generate access point name if not provided
  access_point_name = var.access_point_name != "" ? var.access_point_name : "${var.environment}-${var.purpose}-ap"

  # Common tags
  common_tags = merge(
    {
      Name        = local.access_point_name
      Environment = var.environment
      Purpose     = var.purpose
      ManagedBy   = "Terraform"
      Module      = "s3-access-points"
      NetworkType = var.vpc_configuration != null ? "VPC" : "Internet"
    },
    var.tags
  )
}

# S3 Access Point
resource "aws_s3_access_point" "this" {
  bucket = var.bucket_name
  name   = local.access_point_name

  # VPC configuration (optional - for VPC-restricted access)
  dynamic "vpc_configuration" {
    for_each = var.vpc_configuration != null ? [var.vpc_configuration] : []

    content {
      vpc_id = vpc_configuration.value.vpc_id
    }
  }

  # Public access block settings
  public_access_block_configuration {
    block_public_acls       = var.block_public_acls
    block_public_policy     = var.block_public_policy
    ignore_public_acls      = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets
  }

}

# Access Point Policy
data "aws_iam_policy_document" "access_point_policy" {
  # Default policy - deny all except what's explicitly allowed
  # Allow specific principals if provided
  dynamic "statement" {
    for_each = length(var.allowed_principals) > 0 ? [1] : []

    content {
      sid    = "AllowSpecificPrincipals"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.allowed_principals
      }

      actions = var.allowed_actions

      resources = [
        "arn:${data.aws_partition.current.partition}:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:accesspoint/${local.access_point_name}",
        "arn:${data.aws_partition.current.partition}:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:accesspoint/${local.access_point_name}/object/*"
      ]

      # Conditions
      dynamic "condition" {
        for_each = var.require_secure_transport ? [1] : []
        content {
          test     = "Bool"
          variable = "aws:SecureTransport"
          values   = ["true"]
        }
      }

      dynamic "condition" {
        for_each = length(var.source_ip_whitelist) > 0 ? [1] : []
        content {
          test     = "IpAddress"
          variable = "aws:SourceIp"
          values   = var.source_ip_whitelist
        }
      }

      dynamic "condition" {
        for_each = var.require_mfa ? [1] : []
        content {
          test     = "Bool"
          variable = "aws:MultiFactorAuthPresent"
          values   = ["true"]
        }
      }
    }
  }

  # Deny unencrypted uploads
  dynamic "statement" {
    for_each = var.deny_unencrypted_uploads ? [1] : []

    content {
      sid    = "DenyUnencryptedUploads"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions = ["s3:PutObject"]

      resources = [
        "arn:${data.aws_partition.current.partition}:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:accesspoint/${local.access_point_name}/object/*"
      ]

      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms", "AES256"]
      }
    }
  }

  # Additional custom statements
  dynamic "statement" {
    for_each = var.custom_policy_statements

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

# Attach policy to access point
resource "aws_s3control_access_point_policy" "this" {
  access_point_arn = aws_s3_access_point.this.arn
  policy           = data.aws_iam_policy_document.access_point_policy.json
}

# Multi-Region Access Point (Optional)

resource "aws_s3control_multi_region_access_point" "this" {
  count = var.create_multi_region_access_point ? 1 : 0

  details {
    name = "${local.access_point_name}-mrap"

    dynamic "region" {
      for_each = var.multi_region_buckets

      content {
        bucket = region.value
      }
    }

    public_access_block {
      block_public_acls       = var.block_public_acls
      block_public_policy     = var.block_public_policy
      ignore_public_acls      = var.ignore_public_acls
      restrict_public_buckets = var.restrict_public_buckets
    }
  }
}

# VPC Endpoint for S3 (if VPC configuration
resource "aws_vpc_endpoint" "s3" {
  count = var.vpc_configuration != null && var.create_vpc_endpoint ? 1 : 0

  vpc_id            = var.vpc_configuration.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.vpc_endpoint_route_table_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${local.access_point_name}-s3-endpoint"
    }
  )
}

# VPC Endpoint Policy
resource "aws_vpc_endpoint_policy" "s3" {
  count = var.vpc_configuration != null && var.create_vpc_endpoint ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccessPointAccess"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_access_point.this.arn,
          "${aws_s3_access_point.this.arn}/*",
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# CloudWatch Alarms (Optional)
resource "aws_cloudwatch_metric_alarm" "unauthorized_access" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.access_point_name}-unauthorized-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.unauthorized_access_threshold
  alarm_description   = "Alert on unauthorized access attempts via access point"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AccessPointName = local.access_point_name
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "high_request_rate" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.access_point_name}-high-request-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "AllRequests"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.request_rate_threshold
  alarm_description   = "Alert on unusual request rate via access point"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AccessPointName = local.access_point_name
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = local.common_tags
}

# IAM Role for Access Point Access (Example)
resource "aws_iam_role" "access_point_user" {
  count = var.create_example_iam_role ? 1 : 0

  name = "${local.access_point_name}-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.example_role_service_principal
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "access_point_user" {
  count = var.create_example_iam_role ? 1 : 0

  name = "${local.access_point_name}-access"
  role = aws_iam_role.access_point_user[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = var.allowed_actions
        Resource = [
          aws_s3_access_point.this.arn,
          "${aws_s3_access_point.this.arn}/object/*"
        ]
      }
    ]
  })
}

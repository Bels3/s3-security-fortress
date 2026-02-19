# Presigned URLs Module - Lambda functions for temporary S3 access
# Generates presigned URLs for uploads and downloads

# Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local Variables
locals {
  function_name_upload   = "${var.environment}-presigned-upload"
  function_name_download = "${var.environment}-presigned-download"

  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "presigned-access"
    },
    var.tags
  )
}

# Lambda Function - Generate Upload URLs
# Package Lambda function
data "archive_file" "upload_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda_upload.zip"

  source {
    content  = file("${path.module}/lambda/upload.py")
    filename = "upload.py"
  }
}

# Lambda function
resource "aws_lambda_function" "upload" {
  # checkov:skip=CKV_AWS_117: Lambda does not require VPC access; it only interacts with S3/KMS via public endpoints.
  # checkov:skip=CKV_AWS_116: DLQ not required for synchronous pre-signed URL generation.
  # checkov:skip=CKV_AWS_115: Concurrency limit not required for this low-traffic security demo.
  # checkov:skip=CKV_AWS_50:  X-Ray tracing is disabled to reduce project cost.
  # checkov:skip=CKV_AWS_272: Code signing is not implemented for this development environment.
  filename         = data.archive_file.upload_lambda.output_path
  function_name    = local.function_name_upload
  role             = aws_iam_role.lambda_upload.arn
  handler          = "upload.lambda_handler"
  source_code_hash = data.archive_file.upload_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      BUCKET_NAME           = var.bucket_name
      EXPIRATION_TIME       = var.upload_expiration_seconds
      MAX_FILE_SIZE         = var.max_upload_size_mb
      ALLOWED_CONTENT_TYPES = jsonencode(var.allowed_content_types)
      KMS_KEY_ID            = var.kms_key_id
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = local.function_name_upload
      Purpose = "GenerateUploadURLs"
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/${local.function_name_upload}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# Lambda Function - Generate Download URLs
# Package Lambda function
data "archive_file" "download_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda_download.zip"

  source {
    content  = file("${path.module}/lambda/download.py")
    filename = "download.py"
  }
}

# Lambda function
resource "aws_lambda_function" "download" {
  filename         = data.archive_file.download_lambda.output_path
  function_name    = local.function_name_download
  role             = aws_iam_role.lambda_download.arn
  handler          = "download.lambda_handler"
  source_code_hash = data.archive_file.download_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      BUCKET_NAME     = var.bucket_name
      EXPIRATION_TIME = var.download_expiration_seconds
      KMS_KEY_ID      = var.kms_key_id
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = local.function_name_download
      Purpose = "GenerateDownloadURLs"
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "download_lambda" {
  name              = "/aws/lambda/${local.function_name_download}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# IAM Role for Upload Lambda
resource "aws_iam_role" "lambda_upload" {
  name = "${local.function_name_upload}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for upload Lambda
resource "aws_iam_role_policy" "lambda_upload" {
  name = "${local.function_name_upload}-policy"
  role = aws_iam_role.lambda_upload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_id != "" ? var.kms_key_id : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      },
      {
      Action = ["logs:CreateLogGroup"]
      Effect = "Allow"
      Resource = "*"
      }
    ]
  })
}

# IAM Role for Download Lambda

resource "aws_iam_role" "lambda_download" {
  name = "${local.function_name_download}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for download Lambda
resource "aws_iam_role_policy" "lambda_download" {
  name = "${local.function_name_download}-policy"
  role = aws_iam_role.lambda_download.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.bucket_name}" # Bucket level
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}/*" # Object level
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_id != "" ? var.kms_key_id : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*"
      }
    ]
  })
}

# API Gateway (Optional)
resource "aws_api_gateway_rest_api" "this" {
  count = var.create_api_gateway ? 1 : 0

  name        = "${var.environment}-presigned-urls-api"
  description = "API for generating presigned URLs"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Upload endpoint
resource "aws_api_gateway_resource" "upload" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_rest_api.this[0].root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.upload[0].id
  http_method   = "POST"
  authorization = var.api_gateway_authorization
  authorizer_id = var.api_gateway_authorizer_id
}

resource "aws_api_gateway_integration" "upload" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.upload[0].id
  http_method             = aws_api_gateway_method.upload[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload.invoke_arn
}

# Download endpoint
resource "aws_api_gateway_resource" "download" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_rest_api.this[0].root_resource_id
  path_part   = "download"
}

resource "aws_api_gateway_method" "download" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.download[0].id
  http_method   = "POST"
  authorization = var.api_gateway_authorization
  authorizer_id = var.api_gateway_authorizer_id
}

resource "aws_api_gateway_integration" "download" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.download[0].id
  http_method             = aws_api_gateway_method.download[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.download.invoke_arn
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "this" {
  count = var.create_api_gateway ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload[0].id,
      aws_api_gateway_method.upload[0].id,
      aws_api_gateway_integration.upload[0].id,
      aws_api_gateway_resource.download[0].id,
      aws_api_gateway_method.download[0].id,
      aws_api_gateway_integration.download[0].id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.upload,
    aws_api_gateway_integration.download
  ]
}

resource "aws_api_gateway_stage" "this" {
  count = var.create_api_gateway ? 1 : 0

  deployment_id = aws_api_gateway_deployment.this[0].id
  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  stage_name    = var.environment

  tags = local.common_tags
  lifecycle {
    create_before_destroy = true
  }
  xray_tracing_enabled = true
  
  # Note: Caching can be expensive, but required for the check
  #cache_cluster_enabled = true
  #cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format          = jsonencode({ requestId="$context.requestId", ip="$context.identity.sourceIp", user="$context.identity.user", requestTime="$context.requestTime", httpMethod="$context.httpMethod", resourcePath="$context.resourcePath", status="$context.status" })
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api-gw/${var.environment}-presigned-api"
  retention_in_days = 7
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this[0].id
  stage_name  = aws_api_gateway_stage.this[0].stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "upload_api_gateway" {
  count = var.create_api_gateway ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[0].execution_arn}/*/*"
}

resource "aws_lambda_permission" "download_api_gateway" {
  count = var.create_api_gateway ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.download.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[0].execution_arn}/*/*"
}

# CloudWatch Alarms

resource "aws_cloudwatch_metric_alarm" "upload_lambda_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.function_name_upload}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on Lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.upload.function_name
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "download_lambda_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.function_name_download}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on Lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.download.function_name
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = local.common_tags
}

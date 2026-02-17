variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for presigned URLs"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (optional)"
  type        = string
  default     = ""
}

variable "upload_expiration_seconds" {
  description = "Upload URL expiration time in seconds"
  type        = number
  default     = 300  # 5 minutes
}

variable "download_expiration_seconds" {
  description = "Download URL expiration time in seconds"
  type        = number
  default     = 300  # 5 minutes
}

variable "max_upload_size_mb" {
  description = "Maximum upload file size in MB"
  type        = number
  default     = 10
}

variable "allowed_content_types" {
  description = "List of allowed content types (empty = all allowed)"
  type        = list(string)
  default     = []
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 10
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "create_api_gateway" {
  description = "Create API Gateway for Lambda functions"
  type        = bool
  default     = true
}

variable "api_gateway_authorization" {
  description = "API Gateway authorization type (NONE, AWS_IAM, CUSTOM)"
  type        = string
  default     = "NONE"
}

variable "api_gateway_authorizer_id" {
  description = "API Gateway authorizer ID (if using CUSTOM)"
  type        = string
  default     = null
}

variable "enable_monitoring" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for alarms"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

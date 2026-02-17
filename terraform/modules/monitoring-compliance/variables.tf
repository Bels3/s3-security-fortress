variable "environment" {
  description = "Environment name"
  type        = string
}

variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = ""
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = ""
}

variable "monitored_bucket_arns" {
  description = "List of S3 bucket ARNs to monitor"
  type        = list(string)
  default     = []
}

variable "enable_multi_region_trail" {
  description = "Enable multi-region CloudTrail"
  type        = bool
  default     = true
}

variable "enable_advanced_event_selectors" {
  description = "Enable advanced event selectors"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Send CloudTrail logs to CloudWatch"
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 90
}

variable "cloudtrail_log_retention_days" {
  description = "CloudTrail S3 log retention"
  type        = number
  default     = 365
}

variable "enable_aws_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "enable_sns_alerts" {
  description = "Enable SNS alerts"
  type        = bool
  default     = true
}

variable "alert_email_addresses" {
  description = "Email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "force_destroy" {
  description = "Allow destroy with objects"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

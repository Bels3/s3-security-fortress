variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "purpose" {
  description = "Purpose of the KMS key (e.g., s3, rds, secrets)"
  type        = string

  validation {
    condition     = length(var.purpose) > 0 && length(var.purpose) <= 50
    error_message = "Purpose must be between 1 and 50 characters"
  }
}

# Key Configuration
variable "key_name" {
  description = "Friendly name for the KMS key"
  type        = string
  default     = ""
}

variable "key_description" {
  description = "Description of the KMS key"
  type        = string
  default     = "KMS key for encryption"
}

variable "key_alias" {
  description = "Alias for the KMS key (if empty, will be generated)"
  type        = string
  default     = ""

  validation {
    condition     = var.key_alias == "" || can(regex("^alias/", var.key_alias))
    error_message = "Key alias must start with 'alias/' or be empty"
  }
}

# Security Settings
variable "enable_key_rotation" {
  description = "Enable automatic key rotation (highly recommended)"
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "Waiting period before key deletion (7-30 days)"
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "Deletion window must be between 7 and 30 days"
  }
}

variable "multi_region" {
  description = "Create multi-region key for cross-region replication"
  type        = bool
  default     = false
}

# Access Control

variable "key_administrators" {
  description = "List of IAM ARNs that can administer the key"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.key_administrators : can(regex("^arn:aws:iam::", arn))
    ])
    error_message = "All administrators must be valid IAM ARNs"
  }
}

variable "key_users" {
  description = "List of IAM ARNs that can use the key"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.key_users : can(regex("^arn:aws:iam::", arn))
    ])
    error_message = "All users must be valid IAM ARNs"
  }
}

# Service Integration

variable "allow_cloudtrail" {
  description = "Allow CloudTrail to use this key"
  type        = bool
  default     = false
}

variable "allow_cloudwatch_logs" {
  description = "Allow CloudWatch Logs to use this key"
  type        = bool
  default     = false
}

variable "allow_sns" {
  description = "Allow SNS to use this key"
  type        = bool
  default     = false
}

# Encryption Context

variable "encryption_context_keys" {
  description = "List of encryption context keys to require"
  type        = list(string)
  default     = []
}

variable "encryption_context_values" {
  description = "List of encryption context values to require"
  type        = list(string)
  default     = []
}

# Advanced Security

variable "deny_unencrypted_uploads" {
  description = "Deny key usage for unencrypted uploads"
  type        = bool
  default     = false
}

# Monitoring

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs for alarms"
  type        = list(string)
  default     = []
}

# Grants

variable "create_s3_grant" {
  description = "Create KMS grant for S3 service"
  type        = bool
  default     = false
}

variable "grant_encryption_context" {
  description = "Encryption context for KMS grants"
  type        = map(string)
  default     = {}
}

# Tags

variable "tags" {
  description = "Additional tags for the KMS key"
  type        = map(string)
  default     = {}
}

variable "cloudtrail_log_group_name" {
  description = "The name of the CloudWatch Log Group for CloudTrail"
  type        = string
  default     = ""
}

variable "cloudtrail_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for CloudTrail"
  type        = string
  default     = ""
}

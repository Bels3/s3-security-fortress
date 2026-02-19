#Required Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "purpose" {
  description = "Purpose of the bucket (e.g., audit-logs, compliance-data)"
  type        = string
}

# Bucket Configuration

variable "bucket_name" {
  description = "Name of the S3 bucket (if empty, will be auto-generated)"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Allow destroying bucket even with objects (NOT recommended for locked buckets)"
  type        = bool
  default     = false
}

# Object Lock Configuration

variable "object_lock_mode" {
  description = "Object lock mode: GOVERNANCE or COMPLIANCE"
  type        = string

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "Object lock mode must be GOVERNANCE or COMPLIANCE"
  }
}

variable "retention_days" {
  description = "Retention period in days (use this OR retention_years, not both)"
  type        = number
  default     = null

  validation {
    condition     = var.retention_days == null || (var.retention_days >= 1 && var.retention_days <= 36500)
    error_message = "Retention days must be between 1 and 36500 (100 years)"
  }
}

variable "retention_years" {
  description = "Retention period in years (use this OR retention_days, not both)"
  type        = number
  default     = null

  validation {
    condition     = var.retention_years == null || (var.retention_years >= 1 && var.retention_years <= 100)
    error_message = "Retention years must be between 1 and 100"
  }
}

variable "compliance_level" {
  description = "Compliance level (SEC17a-4, FINRA4511, HIPAA, GDPR, Custom)"
  type        = string
  default     = "Custom"
}

# Security Configuration

variable "mfa_delete_enabled" {
  description = "Require MFA for object deletion (additional protection)"
  type        = bool
  default     = false
}

variable "require_object_lock_on_upload" {
  description = "Require all uploads to specify object lock retention"
  type        = bool
  default     = false
}

variable "kms_master_key_id" {
  description = "ARN of KMS key for bucket encryption"
  type        = string
  default     = ""
}

variable "bucket_key_enabled" {
  description = "Enable S3 Bucket Keys to reduce KMS costs"
  type        = bool
  default     = true
}

# Bucket Policy

variable "custom_bucket_policy_statements" {
  description = "Additional custom bucket policy statements"
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = []
}

# Logging

variable "enable_access_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "logging_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 2555 # 7 years (common compliance requirement)
}

# Lifecycle

variable "lifecycle_rules" {
  description = "Lifecycle rules (only apply after retention period expires)"
  type = list(object({
    id                                 = string
    enabled                            = bool
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
  }))
  default = []
}

# Monitoring

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for CloudWatch alarms"
  type        = list(string)
  default     = []
}

variable "enable_metrics" {
  description = "Enable CloudWatch request metrics"
  type        = bool
  default     = true
}

variable "enable_inventory" {
  description = "Enable S3 inventory (tracks object lock status)"
  type        = bool
  default     = true
}

variable "inventory_frequency" {
  description = "Inventory frequency (Daily or Weekly)"
  type        = string
  default     = "Daily"

  validation {
    condition     = contains(["Daily", "Weekly"], var.inventory_frequency)
    error_message = "Inventory frequency must be Daily or Weekly"
  }
}

variable "inventory_destination_bucket_arn" {
  description = "ARN of bucket for inventory reports"
  type        = string
  default     = ""
}

# Tags

variable "tags" {
  description = "Additional tags for the bucket"
  type        = map(string)
  default     = {}
}

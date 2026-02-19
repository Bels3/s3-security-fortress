variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "purpose" {
  description = "Purpose of the bucket (e.g., data, backups, logs)"
  type        = string

  validation {
    condition     = length(var.purpose) > 0 && length(var.purpose) <= 50
    error_message = "Purpose must be between 1 and 50 characters"
  }
}

# Bucket Configuration
variable "bucket_name" {
  description = "Name of the S3 bucket (if empty, will be auto-generated)"
  type        = string
  default     = ""

  validation {
    condition = var.bucket_name == "" || (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    )
    error_message = "Bucket name must be 3-63 characters, lowercase, numbers, and hyphens only"
  }
}

variable "force_destroy" {
  description = "Allow destroying bucket even if it contains objects (USE WITH CAUTION)"
  type        = bool
  default     = false
}

# Security Configuration
variable "security_level" {
  description = "Security level (standard, high, critical)"
  type        = string
  default     = "high"

  validation {
    condition     = contains(["standard", "high", "critical"], var.security_level)
    error_message = "Security level must be standard, high, or critical"
  }
}

variable "data_classification" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "confidential"

  validation {
    condition = contains(
      ["public", "internal", "confidential", "restricted"],
      var.data_classification
    )
    error_message = "Data classification must be public, internal, confidential, or restricted"
  }
}

# Versioning
variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "mfa_delete_enabled" {
  description = "Enable MFA delete (requires MFA to delete objects)"
  type        = bool
  default     = false
}

# Encryption
variable "kms_master_key_id" {
  description = "ARN of KMS key for bucket encryption (leave empty for AES256)"
  type        = string
  default     = ""
}

variable "bucket_key_enabled" {
  description = "Enable S3 Bucket Keys to reduce KMS costs"
  type        = bool
  default     = true
}

variable "enforce_encryption_in_transit" {
  description = "Enforce encryption in transit (deny unencrypted uploads)"
  type        = bool
  default     = true
}

# Public Access Block
variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
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

# Lifecycle Rules
variable "lifecycle_rules" {
  description = "List of lifecycle rules for the bucket"
  type = list(object({
    id                                     = string
    enabled                                = bool
    filter_prefix                          = optional(string)
    expiration_days                        = optional(number)
    noncurrent_version_expiration_days     = optional(number)
    abort_incomplete_multipart_upload_days = optional(number)
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

# Access Logging
variable "enable_access_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "logging_bucket_name" {
  description = "Name of the bucket to store access logs (if empty, creates new bucket)"
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for access log objects"
  type        = string
  default     = ""
}

variable "logging_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 90

  validation {
    condition     = var.logging_retention_days >= 1 && var.logging_retention_days <= 365
    error_message = "Logging retention must be between 1 and 365 days"
  }
}

# CORS Configuration
variable "cors_rules" {
  description = "CORS rules for the bucket"
  type = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

# Intelligent Tiering
variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent-Tiering"
  type        = bool
  default     = false
}

# Replication
variable "enable_replication" {
  description = "Enable S3 replication"
  type        = bool
  default     = false
}

variable "replication_role_arn" {
  description = "ARN of IAM role for replication"
  type        = string
  default     = ""
}

variable "replication_destination_bucket_arn" {
  description = "ARN of destination bucket for replication"
  type        = string
  default     = ""
}

variable "replication_storage_class" {
  description = "Storage class for replicated objects"
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains(
      ["STANDARD", "REDUCED_REDUNDANCY", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER", "DEEP_ARCHIVE"],
      var.replication_storage_class
    )
    error_message = "Invalid storage class for replication"
  }
}

variable "replication_kms_key_id" {
  description = "KMS key ID for encrypting replicated objects"
  type        = string
  default     = ""
}

# Object Ownership
variable "object_ownership" {
  description = "Object ownership setting"
  type        = string
  default     = "BucketOwnerEnforced"

  validation {
    condition = contains(
      ["BucketOwnerPreferred", "ObjectWriter", "BucketOwnerEnforced"],
      var.object_ownership
    )
    error_message = "Object ownership must be BucketOwnerPreferred, ObjectWriter, or BucketOwnerEnforced"
  }
}

# Monitoring
variable "enable_metrics" {
  description = "Enable CloudWatch request metrics"
  type        = bool
  default     = true
}

variable "enable_inventory" {
  description = "Enable S3 inventory"
  type        = bool
  default     = false
}

variable "inventory_frequency" {
  description = "Inventory frequency (Daily or Weekly)"
  type        = string
  default     = "Weekly"

  validation {
    condition     = contains(["Daily", "Weekly"], var.inventory_frequency)
    error_message = "Inventory frequency must be Daily or Weekly"
  }
}

variable "inventory_destination_bucket_arn" {
  description = "ARN of bucket for inventory reports (if empty, uses same bucket)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Additional tags for the bucket"
  type        = map(string)
  default     = {}
}

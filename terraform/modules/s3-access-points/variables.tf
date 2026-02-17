# Required Variables

variable "bucket_name" {
  description = "Name of the S3 bucket to create access point for"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "purpose" {
  description = "Purpose of the access point (e.g., analytics, uploads, reports)"
  type        = string
}

# Access Point Configuration

variable "access_point_name" {
  description = "Name of the access point (if empty, will be auto-generated)"
  type        = string
  default     = ""
  
  validation {
    condition = var.access_point_name == "" || (
      length(var.access_point_name) >= 3 &&
      length(var.access_point_name) <= 50 &&
      can(regex("^[a-z0-9-]+$", var.access_point_name))
    )
    error_message = "Access point name must be 3-50 characters, lowercase, numbers, and hyphens only"
  }
}

variable "access_point_policy" {
  description = "Custom access point policy (JSON). If empty, uses default policy"
  type        = string
  default     = ""
}

# VPC Configuration

variable "vpc_configuration" {
  description = "VPC configuration for restricting access point to specific VPC"
  type = object({
    vpc_id = string
  })
  default = null
}

variable "create_vpc_endpoint" {
  description = "Create VPC endpoint for S3 access"
  type        = bool
  default     = false
}

variable "vpc_endpoint_route_table_ids" {
  description = "Route table IDs to associate with VPC endpoint"
  type        = list(string)
  default     = []
}

# Public Access Block

variable "block_public_acls" {
  description = "Block public ACLs on access point"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public policies on access point"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs on access point"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies on access point"
  type        = bool
  default     = true
}

# Access Control

variable "allowed_principals" {
  description = "List of IAM principal ARNs allowed to use this access point"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for arn in var.allowed_principals : can(regex("^arn:aws:iam::", arn))
    ])
    error_message = "All principals must be valid IAM ARNs"
  }
}

variable "allowed_actions" {
  description = "List of S3 actions allowed through this access point"
  type        = list(string)
  default     = ["s3:GetObject", "s3:ListBucket"]
}

variable "source_ip_whitelist" {
  description = "List of source IPs/CIDRs allowed to access this access point"
  type        = list(string)
  default     = []
}

variable "require_secure_transport" {
  description = "Require SSL/TLS for all requests"
  type        = bool
  default     = true
}

variable "require_mfa" {
  description = "Require MFA for access"
  type        = bool
  default     = false
}

variable "deny_unencrypted_uploads" {
  description = "Deny uploads without encryption"
  type        = bool
  default     = true
}

# Custom Policy Statements

variable "custom_policy_statements" {
  description = "Additional custom policy statements for the access point"
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

# Multi-Region Access Point

variable "create_multi_region_access_point" {
  description = "Create a multi-region access point"
  type        = bool
  default     = false
}

variable "multi_region_buckets" {
  description = "List of bucket names for multi-region access point"
  type        = list(string)
  default     = []
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

variable "unauthorized_access_threshold" {
  description = "Threshold for unauthorized access alarm (4xx errors)"
  type        = number
  default     = 10
}

variable "request_rate_threshold" {
  description = "Threshold for high request rate alarm"
  type        = number
  default     = 10000
}

# Example IAM Role

variable "create_example_iam_role" {
  description = "Create an example IAM role for access point access"
  type        = bool
  default     = false
}

variable "example_role_service_principal" {
  description = "Service principal for example IAM role"
  type        = string
  default     = "ec2.amazonaws.com"
}

# Tags

variable "tags" {
  description = "Additional tags for the access point"
  type        = map(string)
  default     = {}
}


variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be valid (e.g., us-east-1, eu-west-1)"
  }
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state (must be globally unique)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase, numbers, and hyphens only"
  }
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-lock"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.lock_table_name))
    error_message = "Table name must be 3-255 characters, alphanumeric, underscores, dots, and hyphens"
  }
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB"
  type        = bool
  default     = true
}

variable "state_file_retention_days" {
  description = "Number of days to retain old state file versions"
  type        = number
  default     = 90
  
  validation {
    condition     = var.state_file_retention_days >= 30 && var.state_file_retention_days <= 365
    error_message = "Retention period must be between 30 and 365 days"
  }
}

variable "log_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 90
  
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 365
    error_message = "Log retention must be between 30 and 365 days"
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "S3SecurityFortress"
    ManagedBy = "Terraform"
    Purpose   = "BackendInfrastructure"
  }
}





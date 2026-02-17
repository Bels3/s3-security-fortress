variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "bucket_name" {
  description = "S3 bucket name (from Phase 2)"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID or alias (from Phase 1)"
  type        = string
}

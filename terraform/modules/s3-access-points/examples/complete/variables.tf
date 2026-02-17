#variables.tf

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

variable "office_ip_ranges" {
  description = "Office IP ranges for upload access point"
  type        = list(string)
  default = [
    "0.0.0.0/0"  # Replace with your actual office IPs in production
  ]
}

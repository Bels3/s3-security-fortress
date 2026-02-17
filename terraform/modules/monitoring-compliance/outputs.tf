#Outputs
output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.this.name
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.id
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = var.enable_aws_config ? aws_config_configuration_recorder.this[0].name : null
}

output "config_bucket_name" {
  description = "Name of the AWS Config S3 bucket"
  value       = var.enable_aws_config ? aws_s3_bucket.config[0].id : null
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.enable_cloudwatch_dashboard ? aws_cloudwatch_dashboard.s3_security[0].dashboard_name : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = var.enable_sns_alerts ? aws_sns_topic.alerts[0].arn : null
}

output "log_group_name" {
  description = "The name of the CloudWatch Log Group for CloudTrail"
  value       = try(aws_cloudwatch_log_group.cloudtrail[0].name, "")
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for CloudTrail"
  value       = try(aws_cloudwatch_log_group.cloudtrail[0].arn, "")
}

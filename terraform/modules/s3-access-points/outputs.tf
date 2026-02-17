output "access_point_id" {
  description = "The ID of the access point"
  value       = aws_s3_access_point.this.id
}

output "access_point_arn" {
  description = "The ARN of the access point"
  value       = aws_s3_access_point.this.arn
}

output "access_point_alias" {
  description = "The alias of the access point"
  value       = aws_s3_access_point.this.alias
}

output "access_point_domain_name" {
  description = "The DNS domain name of the access point"
  value       = aws_s3_access_point.this.domain_name
}

output "access_point_endpoints" {
  description = "The VPC endpoints for the access point"
  value       = aws_s3_access_point.this.endpoints
}

output "multi_region_access_point_arn" {
  description = "The ARN of the multi-region access point"
  value       = var.create_multi_region_access_point ? aws_s3control_multi_region_access_point.this[0].arn : null
}

output "multi_region_access_point_alias" {
  description = "The alias of the multi-region access point"
  value       = var.create_multi_region_access_point ? aws_s3control_multi_region_access_point.this[0].alias : null
}

output "vpc_endpoint_id" {
  description = "The ID of the VPC endpoint"
  value       = var.vpc_configuration != null && var.create_vpc_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "example_role_arn" {
  description = "The ARN of the example IAM role for access point access"
  value       = var.create_example_iam_role ? aws_iam_role.access_point_user[0].arn : null
}

output "access_point_policy" {
  description = "The policy document for the access point"
  value       = data.aws_iam_policy_document.access_point_policy.json
  sensitive   = true
}



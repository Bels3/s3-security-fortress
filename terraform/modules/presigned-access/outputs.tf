# Outputs
output "upload_lambda_function_name" {
  description = "Name of the upload Lambda function"
  value       = aws_lambda_function.upload.function_name
}

output "upload_lambda_function_arn" {
  description = "ARN of the upload Lambda function"
  value       = aws_lambda_function.upload.arn
}

output "download_lambda_function_name" {
  description = "Name of the download Lambda function"
  value       = aws_lambda_function.download.function_name
}

output "download_lambda_function_arn" {
  description = "ARN of the download Lambda function"
  value       = aws_lambda_function.download.arn
}

output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = var.create_api_gateway ? "${aws_api_gateway_stage.this[0].invoke_url}" : null
}

output "upload_endpoint" {
  description = "Full URL for upload endpoint"
  value       = var.create_api_gateway ? "${aws_api_gateway_stage.this[0].invoke_url}/upload" : null
}

output "download_endpoint" {
  description = "Full URL for download endpoint"
  value       = var.create_api_gateway ? "${aws_api_gateway_stage.this[0].invoke_url}/download" : null
}

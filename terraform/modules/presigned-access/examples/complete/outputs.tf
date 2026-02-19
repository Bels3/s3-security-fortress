# Outputs
output "api_gateway_url" {
  description = "API Gateway base URL"
  value       = module.presigned_urls.api_gateway_url
}

output "upload_endpoint" {
  description = "Upload endpoint URL"
  value       = module.presigned_urls.upload_endpoint
}

output "download_endpoint" {
  description = "Download endpoint URL"
  value       = module.presigned_urls.download_endpoint
}

output "upload_lambda_name" {
  description = "Upload Lambda function name"
  value       = module.presigned_urls.upload_lambda_function_name
}

output "download_lambda_name" {
  description = "Download Lambda function name"
  value       = module.presigned_urls.download_lambda_function_name
}

output "bucket_name" {
  value       = var.bucket_name
  description = "The name of the S3 bucket used for testing"
}

output "test_commands" {
  description = "Commands to test the API"
  value       = <<-EOT
    
    ========================================
    Test Commands
    ========================================
    
    # Get the API endpoints
    UPLOAD_URL="${module.presigned_urls.upload_endpoint}"
    DOWNLOAD_URL="${module.presigned_urls.download_endpoint}"
    
    # Test 1: Generate upload URL
    curl -X POST "$UPLOAD_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "filename": "test.txt",
        "content_type": "text/plain",
        "metadata": {"user_id": "123"}
      }'
    
    # Test 2: Upload file using presigned URL
    # (Use the URL from Test 1 response)
    
    # Test 3: Generate download URL
    curl -X POST "$DOWNLOAD_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "object_key": "uploads/2024/02/13/120000/test.txt"
      }'
    
    # Test 4: Download file using presigned URL
    # (Use the URL from Test 3 response)
    
    ========================================
  EOT
}

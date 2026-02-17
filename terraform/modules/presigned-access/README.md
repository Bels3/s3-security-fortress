# Presigned URLs Module
## Overview
This module creates Lambda functions that generate presigned URLs for secure, temporary S3 access without requiring AWS credentials.

### Use Cases
✅ **Web Application Uploads**
- Users upload profile photos
- Document submissions
- File sharing

✅ **Mobile App Downloads**
- Temporary access to private content
- Premium content delivery
- Secure file downloads

✅ **API Integrations**
- Third-party uploads
- Webhook file delivery
- Secure data exchange

---
## What Are Presigned URLs?
### The Problem
```
❌ Bad Approach:
User needs to upload file to S3
→ Give user your AWS credentials
→ Security risk! Credentials could be stolen
→ No expiration, unlimited access
```

### The Solution
```
✅ Presigned URLs:
User needs to upload file
→ Your API generates temporary URL (valid 5 min)
→ User uploads directly to S3 using URL
→ URL expires after 5 minutes
→ No AWS credentials needed by user
```

### How It Works
```
┌─────────────┐
│   User      │
└──────┬──────┘
       │ 1. Request upload URL
              ↓
┌─────────────┐
│ API Gateway │
└──────┬──────┘
       │ 2. Invoke Lambda
              ↓
┌─────────────┐
│  Lambda     │
└──────┬──────┘
       │ 3. Generate presigned URL
       │    (signed with AWS credentials)
              ↓
┌─────────────┐
│   User      │
└──────┬──────┘
       │ 4. Upload directly to S3 using URL
              ↓
┌─────────────┐
│     S3      │ 5. Validates signature, accepts upload
└─────────────┘
```
---

## Module Features
### Security Features
✅ **Time-Limited Access**
- URLs expire after configurable time (default: 5 minutes)
- No long-lived credentials needed

✅ **File Size Limits**
- Prevent abuse with max file size (default: 10MB)
- Configurable per use case

✅ **Content Type Validation**
- Restrict to specific file types
- Example: Only allow images, PDFs

✅ **KMS Encryption**
- Automatic encryption at rest
- Uses your KMS key

✅ **Metadata Support**
- Add custom metadata to uploads
- Track user_id, upload_source, etc.

### Monitoring Features
✅ **CloudWatch Logs**
- All Lambda invocations logged
- Debug issues easily

✅ **CloudWatch Alarms**
- Alert on errors
- Monitor usage patterns

✅ **API Gateway Metrics**
- Request count
- Latency
- Error rates

---

## Setup Instructions
### Prerequisites

- S3 bucket created (from Phase 2)
- KMS key created (from Phase 1)
- AWS CLI configured
- Terraform >= 1.6.0

### File Structure
Create this structure:

```
terraform/modules/presigned-access/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── README.md
└── lambda/
    ├── upload.py
    └── download.py
```

### Step 1: Create Lambda Directory

```bash
cd terraform/modules/presigned-access
mkdir lambda
```

### Step 2: Create Lambda Functions

**File: `lambda/upload.py`**

```python
# Copy the upload.py code from the artifact
```

**File: `lambda/download.py`**

```python
# Copy the download.py code from the artifact
```

### Step 3: Create Example

**File: `examples/complete/main.tf`**

```hcl
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# Use existing KMS key and bucket from previous phases
data "aws_s3_bucket" "existing" {
  bucket = var.bucket_name
}

data "aws_kms_key" "existing" {
  key_id = var.kms_key_id
}

# Create presigned URLs module
module "presigned_urls" {
  source = "../.."
  
  environment   = var.environment
  bucket_name   = data.aws_s3_bucket.existing.id
  kms_key_id    = data.aws_kms_key.existing.arn
  
  # Expiration times
  upload_expiration_seconds   = 300  # 5 minutes
  download_expiration_seconds = 300  # 5 minutes
  
  # Upload restrictions
  max_upload_size_mb = 10
  allowed_content_types = [
    "image/jpeg",
    "image/png",
    "application/pdf",
    "text/plain"
  ]
  
  # Lambda configuration
  lambda_timeout     = 10
  lambda_memory_size = 128
  
  # API Gateway
  create_api_gateway        = true
  api_gateway_authorization = "NONE"  # Change to AWS_IAM for production
  
  # Monitoring
  enable_monitoring = true
  log_retention_days = 7
  
  tags = {
    Example = "Presigned-URLs-Complete"
    Module  = "presigned-access"
  }
}

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

output "test_commands" {
  description = "Commands to test the API"
  value = <<-EOT
    
    Test Commands
    
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
```

**File: `examples/complete/variables.tf`**

```hcl
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
```

**File: `examples/complete/terraform.tfvars.example`**

```hcl
aws_region  = "us-east-1"
environment = "dev"
bucket_name = "your-bucket-name-here"  # From Phase 2
kms_key_id  = "alias/dev-s3-key"       # From Phase 1
```

---

## Testing Guide
### Deployment

```bash
# Navigate to example
cd terraform/modules/presigned-access/examples/complete

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your bucket and KMS key
nano terraform.tfvars

# Initialize
terraform init

# Deploy
terraform apply
```

### Test 1: Generate Upload URL via API

```bash
# Get the upload endpoint
UPLOAD_URL=$(terraform output -raw upload_endpoint)

# Generate presigned upload URL
curl -X POST "$UPLOAD_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.txt",
    "content_type": "text/plain",
    "metadata": {
      "user_id": "test-user-123",
      "source": "api-test"
    }
  }' | jq '.'
```

**Expected Response:**
```json
{
  "upload_url": "https://my-bucket.s3.amazonaws.com/",
  "fields": {
    "key": "uploads/2024/02/13/120000/test.txt",
    "x-amz-algorithm": "AWS4-HMAC-SHA256",
    "x-amz-credential": "...",
    "x-amz-date": "20240213T120000Z",
    "policy": "...",
    "x-amz-signature": "...",
    "Content-Type": "text/plain",
    "x-amz-server-side-encryption": "aws:kms"
  },
  "object_key": "uploads/2024/02/13/120000/test.txt",
  "expires_in": 300,
  "max_file_size_mb": 10
}
```

### Test 2: Upload File Using Presigned URL
```bash
# Create test file
echo "This is a test upload via presigned URL" > test.txt

# Extract upload URL and fields from previous response
# Save response to file first
curl -X POST "$UPLOAD_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.txt",
    "content_type": "text/plain"
  }' > upload_response.json

# Upload using the presigned URL
UPLOAD_ENDPOINT=$(jq -r '.upload_url' upload_response.json)
KEY=$(jq -r '.fields.key' upload_response.json)
POLICY=$(jq -r '.fields.policy' upload_response.json)
SIGNATURE=$(jq -r '.fields["x-amz-signature"]' upload_response.json)
CREDENTIAL=$(jq -r '.fields["x-amz-credential"]' upload_response.json)
DATE=$(jq -r '.fields["x-amz-date"]' upload_response.json)
ALGORITHM=$(jq -r '.fields["x-amz-algorithm"]' upload_response.json)

# Perform upload
curl -X POST "$UPLOAD_ENDPOINT" \
  -F "key=$KEY" \
  -F "x-amz-algorithm=$ALGORITHM" \
  -F "x-amz-credential=$CREDENTIAL" \
  -F "x-amz-date=$DATE" \
  -F "policy=$POLICY" \
  -F "x-amz-signature=$SIGNATURE" \
  -F "Content-Type=text/plain" \
  -F "file=@test.txt"
```

**Expected**: HTTP 204 (success, no content)

### Test 3: Verify Upload in S3
```bash
# Get bucket name
BUCKET=$(terraform output -raw bucket_name 2>/dev/null || echo "your-bucket-name")

# List uploaded files
aws s3 ls s3://$BUCKET/uploads/ --recursive

# Check file metadata
OBJECT_KEY=$(jq -r '.object_key' upload_response.json)
aws s3api head-object --bucket $BUCKET --key "$OBJECT_KEY"
```

**Should show:**
- ServerSideEncryption: aws:kms
- Metadata with your custom fields
- Content-Type: text/plain

### Test 4: Generate Download URL
```bash
# Get download endpoint
DOWNLOAD_URL=$(terraform output -raw download_endpoint)

# Generate presigned download URL
curl -X POST "$DOWNLOAD_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"object_key\": \"$OBJECT_KEY\",
    \"response_content_disposition\": \"attachment; filename=downloaded-test.txt\"
  }" | jq '.'
```

**Expected Response:**
```json
{
  "download_url": "https://my-bucket.s3.amazonaws.com/uploads/2024/.../test.txt?X-Amz-Algorithm=...",
  "object_key": "uploads/2024/02/13/120000/test.txt",
  "expires_in": 300
}
```

### Test 5: Download File Using Presigned URL

```bash
# Save response
curl -X POST "$DOWNLOAD_URL" \
  -H "Content-Type: application/json" \
  -d "{\"object_key\": \"$OBJECT_KEY\"}" > download_response.json

# Extract download URL
PRESIGNED_DOWNLOAD_URL=$(jq -r '.download_url' download_response.json)

# Download file
curl "$PRESIGNED_DOWNLOAD_URL" -o downloaded.txt

# Verify content
cat downloaded.txt

# Should match original file
diff test.txt downloaded.txt
```

### Test 6: Test Lambda Functions Directly

```bash
# Get Lambda function names
UPLOAD_LAMBDA=$(terraform output -raw upload_lambda_name)
DOWNLOAD_LAMBDA=$(terraform output -raw download_lambda_name)

# Test upload Lambda
aws lambda invoke \
  --function-name "$UPLOAD_LAMBDA" \
  --payload '{
    "filename": "direct-test.txt",
    "content_type": "text/plain"
  }' \
  upload_lambda_response.json

cat upload_lambda_response.json | jq '.'

# Test download Lambda
aws lambda invoke \
  --function-name "$DOWNLOAD_LAMBDA" \
  --payload "{
    \"object_key\": \"$OBJECT_KEY\"
  }" \
  download_lambda_response.json

cat download_lambda_response.json | jq '.'
```

### Test 7: Test URL Expiration

```bash
# Generate upload URL
curl -X POST "$UPLOAD_URL" \
  -H "Content-Type: application/json" \
  -d '{"filename": "expire-test.txt", "content_type": "text/plain"}' \
  > expire_test.json

# Wait 6 minutes (URL expires after 5)
echo "Waiting 6 minutes for URL to expire..."
sleep 360

# Try to use expired URL (should fail)
EXPIRED_URL=$(jq -r '.upload_url' expire_test.json)
curl -X POST "$EXPIRED_URL" \
  -F "key=$(jq -r '.fields.key' expire_test.json)" \
  -F "file=@test.txt"

# Expected: Error about expired URL
```

### Test 8: Test File Size Limit

```bash
# Create file larger than 10MB
dd if=/dev/zero of=large.txt bs=1M count=11

# Try to upload (should be rejected by S3)
curl -X POST "$UPLOAD_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "large.txt",
    "content_type": "text/plain"
  }' > large_response.json

# Try upload with the presigned URL
# Should fail with EntityTooLarge error
```

### Test 9: Test Content Type Restriction

```bash
# Try to upload disallowed content type
curl -X POST "$UPLOAD_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "bad.exe",
    "content_type": "application/x-msdownload"
  }'

# Expected: 400 error "Content type not allowed"
```

### Test 10: Check CloudWatch Logs

```bash
# View upload Lambda logs
aws logs tail "/aws/lambda/$UPLOAD_LAMBDA" --follow

# View download Lambda logs
aws logs tail "/aws/lambda/$DOWNLOAD_LAMBDA" --follow

# Check for errors in last hour
aws logs filter-log-events \
  --log-group-name "/aws/lambda/$UPLOAD_LAMBDA" \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"
```

---

## API Reference
### Upload Endpoint

**POST** `/upload`

**Request Body:**
```json
{
  "filename": "document.pdf",
  "content_type": "application/pdf",
  "metadata": {
    "user_id": "123",
    "project": "ABC"
  }
}
```

**Response:**
```json
{
  "upload_url": "https://...",
  "fields": { ... },
  "object_key": "uploads/2024/.../document.pdf",
  "expires_in": 300,
  "max_file_size_mb": 10
}
```

### Download Endpoint

**POST** `/download`

**Request Body:**
```json
{
  "object_key": "uploads/2024/02/13/120000/document.pdf",
  "response_content_disposition": "attachment; filename=download.pdf"
}
```

**Response:**
```json
{
  "download_url": "https://...",
  "object_key": "uploads/.../document.pdf",
  "expires_in": 300
}
```

---

## Security Considerations
### Production Checklist

✅ **Enable Authentication**
```hcl
api_gateway_authorization = "AWS_IAM"
# or use API keys, Cognito, Lambda authorizer
```

✅ **HTTPS Only**
- API Gateway uses HTTPS by default
- Presigned URLs use HTTPS

✅ **Rate Limiting**
```hcl
# Add API Gateway usage plan
resource "aws_api_gateway_usage_plan" "this" {
  name = "rate-limit-plan"
  
  quota_settings {
    limit  = 1000
    period = "DAY"
  }
  
  throttle_settings {
    burst_limit = 10
    rate_limit  = 5
  }
}
```

✅ **CORS Configuration**
```python
# In Lambda response
'Access-Control-Allow-Origin': 'https://yourdomain.com'
# NOT '*' in production
```

✅ **CloudTrail Logging**
- Enable S3 data events
- Log all API calls

## Troubleshooting

### Issue: Lambda function not found

**Error**: `Error creating zip file`

**Solution**:
```bash
# Ensure lambda directory exists
mkdir -p lambda

# Ensure Python files exist
ls lambda/upload.py lambda/download.py
```

### Issue: Upload fails with SignatureDoesNotMatch

**Cause**: Clock skew or wrong credentials

**Solution**:
```bash
# Sync your system time
sudo ntpdate -s time.nist.gov

# Regenerate the presigned URL
```

### Issue: Access Denied on upload

**Cause**: Lambda doesn't have S3 permissions

**Solution**: Check IAM role has `s3:PutObject` permission

### Issue: Cannot download - object not found

**Cause**: Wrong object_key

**Solution**:
```bash
# List all objects
aws s3 ls s3://bucket/uploads/ --recursive

# Use exact key from list
```

## Cost Analysis
### Monthly Costs (Low Usage)
```
API Gateway:
- First 1M requests: FREE
- Then $3.50 per million

Lambda:
- First 1M requests: FREE
- 128MB, 10ms avg: $0.0000002 per request
- 10,000 requests/month: $0.002

CloudWatch Logs:
- Ingestion: $0.50/GB
- Storage: $0.03/GB/month
- ~100MB logs: $0.053

Total: ~$0.56/month (under 10k requests)
```

### Monthly Costs (High Usage)
```
100,000 requests/month:

API Gateway: $0.35
Lambda: $0.02
CloudWatch: $0.50

Total: ~$0.87/month
```

**Presigned URLs themselves: FREE!**
- Just S3 storage and request costs
- No data transfer through Lambda

## Best Practices
### 1. Short Expiration Times

```hcl
upload_expiration_seconds = 300    # 5 minutes
download_expiration_seconds = 300  # 5 minutes
```

### 2. File Size Limits

```hcl
max_upload_size_mb = 10  # Prevent abuse
```

### 3. Content Type Restrictions

```hcl
allowed_content_types = [
  "image/jpeg",
  "image/png",
  "application/pdf"
]
```

### 4. Add Metadata
```json
{
  "metadata": {
    "user_id": "123",
    "upload_timestamp": "2024-02-13T12:00:00Z",
    "source": "web-app"
  }
}
```

### 5. Monitor Usage

- Set up CloudWatch alarms
- Track error rates
- Monitor costs

---

## Next Steps

1. ✅ Deploy and test all 10 tests
2. ✅ Update your eraser.io diagram
3. ✅ Document in your GitHub README
4. ⏭️ Integrate with your application
5. ⏭️ Add authentication (production)
6. ⏭️ Set up monitoring alerts

## Additional Resources

- [AWS Presigned URLs Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [API Gateway Security](https://docs.aws.amazon.com/apigateway/latest/developerguide/security.html)


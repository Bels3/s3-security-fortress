# KMS Encryption Module - Basic Example
This example demonstrates how to:
1. Create a KMS customer-managed key
2. Enable automatic key rotation
3. Use the key to encrypt an S3 bucket
4. Implement proper access controls

## Prerequisites
- AWS CLI configured with credentials
- Terraform >= 1.6.0
- Appropriate AWS permissions (KMS, S3, IAM)

## What Gets Created

| Resource | Purpose |
|----------|---------|
| KMS Key | Customer-managed encryption key |
| KMS Alias | Easy reference to the key |
| S3 Bucket | Test bucket using KMS encryption |
| Bucket Encryption | KMS-based encryption configuration |

## Cost Estimate

**Monthly Cost: ~$1.05**
- KMS Key: $1.00/month
- S3 Storage: ~$0.023/GB (first 5GB free)
- KMS API calls: ~$0.03/10k requests (first 20k free)

## Quick Start
### Step 1: Navigate to Example Directory
```bash
cd terraform/modules/kms-encryption/examples/basic
```

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Review Plan
```bash
terraform plan
```

Expected output:
```
Plan: 6 to add, 0 to change, 0 to destroy.
```

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted.

### Step 5: Verify Deployment

```bash
# View outputs
terraform output

# Test the bucket encryption
aws s3api head-bucket \
  --bucket $(terraform output -raw test_bucket_name) \
  --query ServerSideEncryptionConfiguration
```

## Testing the KMS Key

### Upload an Encrypted File

```bash
BUCKET=$(terraform output -raw test_bucket_name)
KEY_ID=$(terraform output -raw kms_key_id)

# Create a test file
echo "This is sensitive data" > test-file.txt

# Upload with KMS encryption (should work)
aws s3 cp test-file.txt s3://$BUCKET/test-file.txt \
  --server-side-encryption aws:kms \
  --ssekms-key-id $KEY_ID

# Verify encryption
aws s3api head-object \
  --bucket $BUCKET \
  --key test-file.txt \
  --query ServerSideEncryption
```

Expected output: `"aws:kms"`

### Try Uploading Without Encryption (Should Fail)
```bash
# This should fail because bucket requires KMS
aws s3 cp test-file.txt s3://$BUCKET/unencrypted.txt
```

### Download and Decrypt
```bash
# Download (automatically decrypts if you have permissions)
aws s3 cp s3://$BUCKET/test-file.txt downloaded-file.txt

# Verify content
cat downloaded-file.txt
```

## Verify Key Rotation
```bash
KEY_ID=$(terraform output -raw kms_key_id)

# Check rotation status
aws kms get-key-rotation-status --key-id $KEY_ID
```

Expected output:
```json
{
    "KeyRotationEnabled": true
}
```

## Verify Access Controls
### Test Key Description

```bash
KEY_ID=$(terraform output -raw kms_key_id)

# Describe key (should work - you're an administrator)
aws kms describe-key --key-id $KEY_ID
```

### Test Encryption
```bash
# Encrypt data (should work - you're a user)
aws kms encrypt \
  --key-id $KEY_ID \
  --plaintext "Hello World" \
  --query CiphertextBlob \
  --output text
```

## Monitoring
### View KMS Key Usage

```bash
# Get key metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/KMS \
  --metric-name NumberOfKmsApiRequests \
  --dimensions Name=KeyId,Value=$(terraform output -raw kms_key_id) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

### Check CloudTrail Logs
```bash
# View recent KMS API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$(terraform output -raw kms_key_arn) \
  --max-results 10
```

## Clean Up
### Important: Read Before Destroying

⚠️ **Warning**: Deleting a KMS key is a two-step process:
1. Terraform schedules deletion (30-day window)
2. After 30 days, AWS permanently deletes the key

During the 30-day window:
- You can cancel deletion
- You can still decrypt data
- You cannot encrypt new data

### Destroy Resources
```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy
```

Type `yes` when prompted.

### Verify Deletion
```bash
KEY_ID=$(terraform output -raw kms_key_id)

# Check key state
aws kms describe-key --key-id $KEY_ID
```

Expected output:
```json
{
    "KeyMetadata": {
        "KeyState": "PendingDeletion",
        "DeletionDate": "2024-XX-XX"
    }
}
```

### Cancel Deletion (if needed)
```bash
KEY_ID=<your-key-id>

aws kms cancel-key-deletion --key-id $KEY_ID
```

## Troubleshooting
### Issue: Access Denied when creating key

**Error**:
```
Error: error creating KMS Key: AccessDeniedException
```

**Solution**:
```bash
# Check your IAM permissions
aws iam get-user

# Ensure you have kms:CreateKey permission
# Or use a role with KMS admin access
```

### Issue: Bucket upload fails with encryption error
**Error**:
```
Error: Access Denied when uploading to S3
```

**Solution**:
```bash
# Verify you're listed as a key user
KEY_ID=$(terraform output -raw kms_key_id)
aws kms get-key-policy --key-id $KEY_ID --policy-name default

# Check your IAM permissions for S3 and KMS
```

### Issue: Cannot destroy - key in use
**Error**:
```
Error: error disabling KMS key: Key is still in use
```

**Solution**:
```bash
# Delete all objects in the bucket first
BUCKET=$(terraform output -raw test_bucket_name)
aws s3 rm s3://$BUCKET --recursive

# Then destroy
terraform destroy
```

## Additional Resources
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [S3 Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingEncryption.html)
- [Key Rotation](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)


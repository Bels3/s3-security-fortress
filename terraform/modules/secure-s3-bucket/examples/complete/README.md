#This example demonstrates the full integration of KMS encryption with secure S3 buckets.
## What Gets Created
1. **KMS Key**
   - Customer-managed key
   - Automatic rotation enabled
   - Used for all bucket encryption

2. **Basic Bucket**
   - KMS encryption
   - Versioning enabled
   - Access logging enabled
   - S3 Bucket Keys (cost optimization)

3. **Advanced Bucket**
   - All basic features
   - Lifecycle rules (4 transitions)
   - CloudWatch metrics
   - S3 inventory
   - Custom bucket policies
   - Critical security level

4. **CORS Bucket**
   - KMS encryption
   - CORS configuration
   - Upload lifecycle rules

5. **Logging Bucket**
   - Stores access logs
   - 90-day retention
   - Lifecycle management

6. **Test Files**
   - Uploaded to verify encryption
   - Metadata included

## Cost Estimate
**Monthly Cost: ~$3-5**
| Resource | Cost |
|----------|------|
| KMS Key | $1.00 |
| S3 Storage (5GB) | ~$0.12 |
| KMS API calls | ~$0.01 |
| S3 Requests | ~$0.01 |
| Logging | ~$0.05 |
| **Total** | **~$1.19** |

## Deployment
```bash
# Navigate to example
cd terraform/modules/secure-s3-bucket/examples/complete

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

## Testing
### 1. Verify KMS Encryption
```bash
KMS_KEY_ID=$(terraform output -raw kms_key_id)

# Check key exists
aws kms describe-key --key-id $KMS_KEY_ID

# Check rotation
aws kms get-key-rotation-status --key-id $KMS_KEY_ID
```

### 2. Verify Bucket Encryption
```bash
BUCKET=$(terraform output -raw basic_bucket_name)

# Check bucket encryption configuration
aws s3api get-bucket-encryption --bucket $BUCKET

# Check test file encryption
aws s3api head-object \
  --bucket $BUCKET \
  --key test-files/test-file.txt \
  | grep -i encryption
```

### 3. Test Upload & Download
```bash
BUCKET=$(terraform output -raw basic_bucket_name)

# Upload a file
echo "Manual test file" > manual-test.txt
aws s3 cp manual-test.txt s3://$BUCKET/manual-test.txt

# Verify it's encrypted
aws s3api head-object --bucket $BUCKET --key manual-test.txt

# Download and verify
aws s3 cp s3://$BUCKET/manual-test.txt downloaded.txt
cat downloaded.txt
```

### 4. Test Versioning
```bash
BUCKET=$(terraform output -raw basic_bucket_name)

# Upload version 1
echo "Version 1" > version-test.txt
aws s3 cp version-test.txt s3://$BUCKET/version-test.txt

# Upload version 2
echo "Version 2" > version-test.txt
aws s3 cp version-test.txt s3://$BUCKET/version-test.txt

# List all versions
aws s3api list-object-versions \
  --bucket $BUCKET \
  --prefix version-test.txt
```

### 5. Test Access Logging
```bash
BUCKET=$(terraform output -raw basic_bucket_name)
LOG_BUCKET=$(terraform output -raw logging_bucket_name)

# Wait a few minutes for logs to be delivered
sleep 300

# Check for log files
aws s3 ls s3://$LOG_BUCKET/access-logs/$BUCKET/
```

### 6. Check Lifecycle Rules
```bash
BUCKET=$(terraform output -raw advanced_bucket_name)

# View lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET
```

### 7. Test CORS
```bash
BUCKET=$(terraform output -raw cors_bucket_name)

# Check CORS configuration
aws s3api get-bucket-cors --bucket $BUCKET
```

## Verification Checklist
After deployment, verify:
- [ ] KMS key created with rotation enabled
- [ ] All 3 buckets created successfully
- [ ] Logging bucket created
- [ ] Test files uploaded and encrypted
- [ ] Versioning working on all buckets
- [ ] Encryption verified on test files
- [ ] Lifecycle rules configured correctly
- [ ] Access logging enabled
- [ ] CloudWatch metrics available
- [ ] CORS configured on CORS bucket

## Clean Up
```bash
# Remove test files first
rm -f test-file.txt manual-test.txt version-test.txt downloaded.txt

# Destroy infrastructure
terraform destroy
```

**Note**: If you get errors about non-empty buckets:

```bash
# Empty all buckets first
BASIC=$(terraform output -raw basic_bucket_name)
ADVANCED=$(terraform output -raw advanced_bucket_name)
CORS=$(terraform output -raw cors_bucket_name)
LOGS=$(terraform output -raw logging_bucket_name)

aws s3 rm s3://$BASIC --recursive
aws s3 rm s3://$ADVANCED --recursive
aws s3 rm s3://$CORS --recursive
aws s3 rm s3://$LOGS --recursive

# Then destroy
terraform destroy
```

## Troubleshooting
### Issue: Cannot upload file
**Error**: `Access Denied`

**Solution**:
```bash
# Check KMS key policy
aws kms get-key-policy --key-id $KMS_KEY_ID --policy-name default

# Ensure you're in key_users list
```

### Issue: Logging not working
**Check**:
```bash
# Verify logging configuration
aws s3api get-bucket-logging --bucket $BUCKET

# Check log bucket permissions
aws s3api get-bucket-acl --bucket $LOG_BUCKET
```

## Additional Resources
- [KMS + S3 Encryption Guide](../../kms-encryption/README.md)
- [S3 Lifecycle Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 Logging Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html)

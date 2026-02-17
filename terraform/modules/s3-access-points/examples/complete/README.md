# Access Points Complete Example
## What Gets Created
1. **KMS Key** - Encryption for all data
2. **S3 Bucket** - Central data bucket
3. **4 Access Points**:
   - Read-only (public internet)
   - Upload-only (IP restricted)
   - Admin (authenticated only)
   - Application (with IAM role)
4. **Test Files** - Demonstrate access
5. **IAM Role** - Example application access

## Cost Estimate
**Monthly Cost: ~$2-3**
- KMS Key: $1.00
- S3 Storage: ~$0.50
- Access Points: FREE
- Monitoring: ~$0.50
- Total: ~$2.00

## Deployment
```bash
cd terraform/modules/s3-access-points/examples/complete
terraform init
terraform apply
```

## Testing
### Test 1: Read-Only Access Point
```bash
# Get the alias
READONLY_AP=$(terraform output -raw readonly_access_point_alias)

# List files
aws s3 ls s3://$READONLY_AP/

# Download file
aws s3 cp s3://$READONLY_AP/public/readme.txt ./

# Try to upload (should fail - read-only)
echo "test" > test.txt
aws s3 cp test.txt s3://$READONLY_AP/test.txt  # Should fail ✗
```

### Test 2: Upload Access Point
```bash
# Get the alias
UPLOAD_AP=$(terraform output -raw upload_access_point_alias)

# Upload file (should work)
echo "New upload" > upload.txt
aws s3 cp upload.txt s3://$UPLOAD_AP/uploads/

# Try to download (should fail - write-only)
aws s3 cp s3://$UPLOAD_AP/uploads/upload.txt ./  # Should fail ✗
```

### Test 3: Admin Access Point
```bash
# Get the alias
ADMIN_AP=$(terraform output -raw admin_access_point_alias)

# Full access - should work
aws s3 ls s3://$ADMIN_AP/
aws s3 cp test.txt s3://$ADMIN_AP/admin/test.txt
aws s3 cp s3://$ADMIN_AP/admin/test.txt ./
```

### Test 4: Verify Policies
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AP_NAME=$(terraform output -raw readonly_access_point_arn | rev | cut -d/ -f1 | rev)

# Get access point policy
aws s3control get-access-point-policy \
  --account-id $ACCOUNT_ID \
  --name $AP_NAME

# Get access point configuration
aws s3control get-access-point \
  --account-id $ACCOUNT_ID \
  --name $AP_NAME
```

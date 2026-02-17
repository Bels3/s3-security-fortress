# Object Lock Complete Example
## Overview
This example demonstrates S3 Object Lock in both GOVERNANCE and COMPLIANCE modes with real-world use cases.

## What Gets Created
### 1. **KMS Key**
- Customer-managed key for encryption
- Automatic rotation enabled
- Used by all three buckets

### 2. **Governance Mode Bucket**
- **Purpose**: Testing and internal policies
- **Retention**: 30 days
- **Can bypass**: Yes (with `s3:BypassGovernanceRetention` permission)
- **Use case**: Development, internal data

### 3. **Compliance Mode Bucket**
- **Purpose**: Regulatory compliance (SEC 17a-4)
- **Retention**: 7 years
- **Can bypass**: NO (immutable until retention expires)
- **Use case**: Financial records, legal documents

### 4. **Audit Logs Bucket**
- **Purpose**: Audit trails (SOC 2)
- **Retention**: 90 days
- **Can bypass**: NO (compliance mode)
- **Use case**: Application logs, access logs

### 5. **Test Files**
- One file in each bucket demonstrating retention
- Pre-configured with Object Lock

---

## Prerequisites
- AWS CLI configured
- Terraform >= 1.6.0
- AWS account with appropriate permissions
- **Budget alert recommended** (storage accumulates!)

---

## Deployment
### Step 1: Navigate to Example
```bash
cd terraform/modules/object-lock/examples/complete
```

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Review Plan
```bash
terraform plan
```

**Expected resources**: ~15-20 resources
### Step 4: Deploy
```bash
terraform apply
```

Type `yes` when prompted.

**⏱️ Deployment time**: ~2-3 minutes
---

## Testing Guide
### Test 1: Understanding Delete Markers vs Version Deletion
**IMPORTANT**: Object Lock protects VERSIONS, not delete markers!
```bash
# Get bucket name
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# List files
aws s3 ls s3://$GOV_BUCKET/test/

# Add delete marker (this is ALLOWED even with Object Lock)
aws s3 rm s3://$GOV_BUCKET/test/governance-test.txt
```
**Result**: ✅ Success (file appears deleted, but versions are protected)

**Explanation**: This adds a "delete marker" which hides the file, but doesn't actually delete the data. Object Lock allows this.
---

### Test 2: Try to Delete a Specific VERSION (Real Test)
```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# Get the version ID of the latest version
VERSION_ID=$(aws s3api list-object-versions \
  --bucket $GOV_BUCKET \
  --prefix test/governance-test.txt \
  --query 'Versions[0].VersionId' \
  --output text)

echo "Trying to delete version: $VERSION_ID"

# Try to delete the ACTUAL VERSION (not just add marker)
aws s3api delete-object \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt \
  --version-id $VERSION_ID
```

**Expected Result**: 
- ✅ **Access Denied** - if Object Lock retention was applied
- ❌ **Success** - if Object Lock retention was NOT applied to this version

**This is the REAL test of Object Lock!**

---

### Test 3: Check If Object Lock Was Applied

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)
VERSION_ID=$(aws s3api list-object-versions \
  --bucket $GOV_BUCKET \
  --prefix test/governance-test.txt \
  --query 'Versions[0].VersionId' \
  --output text)

# Check Object Lock status
aws s3api head-object \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt \
  --version-id $VERSION_ID | grep ObjectLock
```

**Look for**:
- `ObjectLockMode`: GOVERNANCE or COMPLIANCE
- `ObjectLockRetainUntilDate`: Protection date
- If these are MISSING, retention wasn't applied to this version

---

### Test 4: Upload File WITH Explicit Object Lock

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# Create test file
echo "Locked file - $(date)" > locked-test.txt

# Upload with EXPLICIT Object Lock retention
aws s3api put-object \
  --bucket $GOV_BUCKET \
  --key test/locked-file.txt \
  --body locked-test.txt \
  --object-lock-mode GOVERNANCE \
  --object-lock-retain-until-date $(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)

echo "File uploaded with Object Lock!"

# Verify lock was applied
aws s3api head-object \
  --bucket $GOV_BUCKET \
  --key test/locked-file.txt | grep ObjectLock
```

**Expected**: Should show ObjectLockMode and RetainUntilDate

---

### Test 5: Try to Delete Locked Version

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# Get version ID
VERSION_ID=$(aws s3api list-object-versions \
  --bucket $GOV_BUCKET \
  --prefix test/locked-file.txt \
  --query 'Versions[0].VersionId' \
  --output text)

# Try to delete VERSION (should fail)
aws s3api delete-object \
  --bucket $GOV_BUCKET \
  --key test/locked-file.txt \
  --version-id $VERSION_ID
```

**Expected**: ❌ Access Denied (Object Lock protection working!)

---

### Test 6: Governance Mode - Bypass with Permission

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)
VERSION_ID=$(aws s3api list-object-versions \
  --bucket $GOV_BUCKET \
  --prefix test/locked-file.txt \
  --query 'Versions[0].VersionId' \
  --output text)

# Delete with bypass flag (Governance mode only)
aws s3api delete-object \
  --bucket $GOV_BUCKET \
  --key test/locked-file.txt \
  --version-id $VERSION_ID \
  --bypass-governance-retention
```

**Expected**: ✅ Success (Governance allows bypass with permission)

---

### Test 3: Compliance Mode - Try Everything

```bash
# Get bucket name
COMP_BUCKET=$(terraform output -raw compliance_bucket_name)

# List files
aws s3 ls s3://$COMP_BUCKET/records/2024/

# Try to delete (should fail)
aws s3 rm s3://$COMP_BUCKET/records/2024/compliance-record.txt

# Expected error: Access Denied

# Try with bypass (should STILL fail)
aws s3api delete-object \
  --bucket $COMP_BUCKET \
  --key records/2024/compliance-record.txt \
  --bypass-governance-retention

# Expected error: Still Access Denied (Compliance mode!)
```

**Result**: ❌ Cannot delete - even with bypass! This is COMPLIANCE mode.

---

### Test 4: Check Object Lock Status

```bash
COMP_BUCKET=$(terraform output -raw compliance_bucket_name)

# Get object metadata
aws s3api head-object \
  --bucket $COMP_BUCKET \
  --key records/2024/compliance-record.txt

# Look for these fields:
# - ObjectLockMode: COMPLIANCE
# - ObjectLockRetainUntilDate: 2031-XX-XX (7 years from now)
# - ObjectLockLegalHoldStatus: OFF
```

**You should see**:
```json
{
  "ObjectLockMode": "COMPLIANCE",
  "ObjectLockRetainUntilDate": "2031-02-13T10:00:00Z",
  "ObjectLockLegalHoldStatus": "OFF"
}
```

---

### Test 5: Try to Extend Retention (Allowed)

```bash
COMP_BUCKET=$(terraform output -raw compliance_bucket_name)

# Calculate new date (8 years from now)
NEW_DATE=$(date -u -d '+8 years' +%Y-%m-%dT%H:%M:%SZ)

# Extend retention (should work)
aws s3api put-object-retention \
  --bucket $COMP_BUCKET \
  --key records/2024/compliance-record.txt \
  --retention Mode=COMPLIANCE,RetainUntilDate=$NEW_DATE

# Expected: Success
```

**Result**: ✅ Retention extended (can always extend, never reduce)

---

### Test 6: Add Legal Hold

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# Add legal hold
aws s3api put-object-legal-hold \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt \
  --legal-hold Status=ON

# Check status
aws s3api get-object-legal-hold \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt

# Expected: Status=ON
```

**Result**: ✅ Legal hold added (indefinite retention)

---

### Test 7: Try to Delete with Legal Hold

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# Try to delete (should fail even in Governance mode)
aws s3api delete-object \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt \
  --bypass-governance-retention

# Expected error: Access Denied (Legal Hold prevents deletion)
```

**Result**: ❌ Cannot delete (Legal Hold overrides everything)

---

### Test 8: Remove Legal Hold

```bash
GOV_BUCKET=$(terraform output -raw governance_bucket_name)

# Remove legal hold
aws s3api put-object-legal-hold \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt \
  --legal-hold Status=OFF

# Now can delete with bypass
aws s3api delete-object \
  --bucket $GOV_BUCKET \
  --key test/governance-test.txt \
  --bypass-governance-retention

# Expected: Success
```

**Result**: ✅ Deleted after legal hold removed

---

### Test 9: Check Inventory Reports

```bash
COMP_BUCKET=$(terraform output -raw compliance_bucket_name)

# List inventory configurations
aws s3api list-bucket-inventory-configurations \
  --bucket $COMP_BUCKET

# After 24-48 hours, check for inventory files
aws s3 ls s3://$COMP_BUCKET/inventory/ --recursive

# Download latest inventory
# (Will show Object Lock status for all objects)
```

---

### Test 10: Verify Monitoring

```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms | grep object-lock

# Check metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name DeleteRequests \
  --dimensions Name=BucketName,Value=$COMP_BUCKET \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

---

## Understanding The Results

### Governance vs Compliance Summary

| Action | Governance | Compliance |
|--------|-----------|------------|
| Delete without bypass | ❌ Denied | ❌ Denied |
| Delete with bypass | ✅ Allowed | ❌ Denied |
| Extend retention | ✅ Allowed | ✅ Allowed |
| Reduce retention | ✅ Allowed | ❌ Denied |
| Root can override | ✅ Yes | ❌ No |

### Legal Hold Summary

| Feature | Description |
|---------|-------------|
| **Duration** | Indefinite (until removed) |
| **Can bypass?** | No (must remove hold first) |
| **Works with** | Both Governance and Compliance |
| **Use case** | Litigation, investigations |

---

## Cost Breakdown

### Monthly Costs (Example)

```
KMS Key:                         $1.00
S3 Storage:
├─ Governance bucket (1GB)       $0.023
├─ Compliance bucket (5GB)       $0.115
└─ Audit logs (2GB)              $0.046

Monitoring & Logging:            $0.30
Inventory Reports:               $0.10

Total:                           ~$1.58/month
```

**Important**: Storage accumulates! Plan for growth.

```
Year 1: 10GB = $0.23/month
Year 7: 70GB = $1.61/month
```

---

## Troubleshooting

### Issue: Cannot deploy

**Error**: `object_lock_enabled must be set at bucket creation`

**Solution**: Object Lock MUST be enabled when bucket is created. You cannot add it later.

---

### Issue: Cannot delete bucket

**Error**: `BucketNotEmpty`

**Cause**: Objects are under retention

**Solution**: 
- Wait for retention to expire, OR
- For Governance mode only:
```bash
aws s3api delete-objects \
  --bucket $BUCKET \
  --delete "$(aws s3api list-object-versions \
    --bucket $BUCKET \
    --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)" \
  --bypass-governance-retention
```

---

### Issue: Policy error on apply

**Error**: `MalformedPolicy: Conditions do not apply`

**Solution**: This is fixed in the updated module. Re-download the latest module code.

---

### Issue: Cannot modify retention

**Error**: `AccessDenied` when trying to reduce retention

**Cause**: Compliance mode prevents reduction

**Solution**: Can only extend, never reduce. This is by design.

---

## Cleanup

### ⚠️ Important Notes Before Cleanup

1. **Compliance buckets** cannot be deleted until retention expires
2. **Governance buckets** can be deleted with bypass permission
3. **Consider costs** of keeping data

### Option 1: Wait for Retention to Expire

For compliance bucket, wait 7 years (not practical for testing!)

### Option 2: Delete What You Can

```bash
# Get bucket names
GOV_BUCKET=$(terraform output -raw governance_bucket_name)
AUDIT_BUCKET=$(terraform output -raw audit_logs_bucket_name)

# Delete governance bucket objects (with bypass)
aws s3api list-object-versions \
  --bucket $GOV_BUCKET \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output json | \
  jq -r '.[] | "\(.Key) \(.VersionId)"' | \
  while read key version; do
    aws s3api delete-object \
      --bucket $GOV_BUCKET \
      --key "$key" \
      --version-id "$version" \
      --bypass-governance-retention
  done

# Delete audit logs bucket objects (with bypass)
# (Same process for audit bucket)

# Destroy infrastructure
terraform destroy
```

### Option 3: Keep Compliance Bucket

```bash
# Remove only governance and audit buckets from state
terraform state rm module.governance_bucket
terraform state rm module.audit_logs_bucket

# Destroy rest
terraform destroy

# Note: Compliance bucket will remain in AWS
# You'll need to manually delete it after retention expires
```

---

## Real-World Usage Patterns

### Pattern 1: Financial Records

```hcl
# 6-year SEC 17a-4 compliance
module "trading_records" {
  source = "../../"
  
  purpose           = "trading-records"
  object_lock_mode  = "COMPLIANCE"
  retention_years   = 6
  compliance_level  = "SEC17a-4"
  
  lifecycle_rules = [{
    transitions = [
      { days = 2191, storage_class = "GLACIER" }
    ]
  }]
}
```

### Pattern 2: HIPAA Healthcare

```hcl
# 6-year HIPAA retention
module "patient_records" {
  source = "../../"
  
  purpose           = "patient-records"
  object_lock_mode  = "COMPLIANCE"
  retention_years   = 6
  compliance_level  = "HIPAA"
  
  kms_master_key_id = module.hipaa_kms_key.key_arn
  mfa_delete_enabled = true
}
```

### Pattern 3: Audit Logs

```hcl
# 1-year SOC 2 audit logs
module "application_logs" {
  source = "../../"
  
  purpose           = "app-audit-logs"
  object_lock_mode  = "COMPLIANCE"
  retention_days    = 365
  compliance_level  = "SOC2"
  
  lifecycle_rules = [{
    transitions = [
      { days = 90, storage_class = "STANDARD_IA" }
    ]
    expiration_days = 400  # After retention + grace
  }]
}
```

---

## Verification Checklist

After deployment and testing:

- [ ] All three buckets created
- [ ] KMS key with rotation enabled
- [ ] Versioning enabled on all buckets
- [ ] Test files uploaded
- [ ] Governance mode tested (can bypass)
- [ ] Compliance mode tested (cannot bypass)
- [ ] Legal hold tested
- [ ] Retention extension tested
- [ ] CloudWatch alarms configured
- [ ] Inventory reports configured
- [ ] Access logging enabled
- [ ] Understand cost implications

---

## Next Steps

1. ✅ Test all Object Lock features
2. ✅ Understand Governance vs Compliance
3. ✅ Update your eraser.io diagram
4. ⏭️ Continue to Phase 5: Presigned URLs
5. ⏭️ Document learnings for LinkedIn/Medium

---

## Additional Resources

- [AWS Object Lock Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html)
- [SEC 17a-4 Compliance Guide](https://www.sec.gov/rules/interp/2003/34-47806.htm)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [Object Lock Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock-overview.html)

---

## Questions?

If you encounter issues:
1. Check the troubleshooting section above
2. Review CloudWatch logs
3. Verify IAM permissions
4. Check S3 bucket policies

**Happy testing!** 🔒

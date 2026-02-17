#Object Lock Module
## Overview
This module creates S3 buckets with Object Lock enabled, providing WORM (Write Once Read Many) storage for compliance and data protection.

## What is Object Lock?
**Object Lock prevents objects from being deleted or modified** for a specified retention period.

### Two Modes:
**1. GOVERNANCE Mode**
```
- Objects protected from deletion
- Users with special permission can bypass
- Good for: Internal policies, testing
- Can be removed by: Users with s3:BypassGovernanceRetention
```

**2. COMPLIANCE Mode**
```
- Objects CANNOT be deleted by ANYONE
- Not even root account can remove
- Good for: Regulatory compliance
- Cannot be removed until: Retention period expires
```

## Use Cases
### Financial Services (SEC 17a-4, FINRA 4511)
```hcl
module "trading_records" {
  source = "./modules/object-lock"
  
  purpose           = "trading-records"
  object_lock_mode  = "COMPLIANCE"
  retention_years   = 7
  compliance_level  = "SEC17a-4"
}
```

### Healthcare (HIPAA)
```hcl
module "patient_records" {
  source = "./modules/object-lock"
  
  purpose           = "patient-records"
  object_lock_mode  = "COMPLIANCE"
  retention_years   = 6
  compliance_level  = "HIPAA"
}
```

### Audit Logs
```hcl
module "audit_logs" {
  source = "./modules/object-lock"
  
  purpose           = "audit-logs"
  object_lock_mode  = "COMPLIANCE"
  retention_days    = 2555  # 7 years
  compliance_level  = "SOC2"
}
```

### Legal Hold
```hcl
module "legal_documents" {
  source = "./modules/object-lock"
  
  purpose           = "legal-hold"
  object_lock_mode  = "GOVERNANCE"
  retention_years   = 10
}
```

## Governance vs Compliance

| Feature | GOVERNANCE | COMPLIANCE |
|---------|------------|------------|
| **Can delete?** | With permission | Never |
| **Can modify retention?** | With permission | Never |
| **Root can override?** | Yes | No |
| **Use case** | Internal policies | Regulatory |
| **Cost** | Same as normal | Same as normal |
| **Reversible?** | Yes | No |

## Complete Example

```hcl
module "compliance_bucket" {
  source = "./modules/object-lock"
  
  environment = "prod"
  purpose     = "financial-records"
  
  # Object Lock settings
  object_lock_mode = "COMPLIANCE"
  retention_years  = 7
  compliance_level = "SEC17a-4"
  
  # Security
  kms_master_key_id = module.kms_key.key_arn
  mfa_delete_enabled = true
  
  # Require object lock on all uploads
  require_object_lock_on_upload = true
  
  # Logging (7 year retention)
  enable_access_logging  = true
  logging_retention_days = 2555
  
  # Monitoring
  enable_monitoring = true
  enable_inventory  = true
  inventory_frequency = "Daily"
  
  # Lifecycle (applies after retention expires)
  lifecycle_rules = [
    {
      id      = "archive-after-retention"
      enabled = true
      
      transitions = [
        {
          days          = 2556  # After 7 years
          storage_class = "GLACIER"
        }
      ]
    }
  ]
  
  tags = {
    Compliance     = "SEC17a-4"
    DataRetention  = "7years"
    Immutable      = "true"
  }
}
```

## Important Limitations
### ⚠️ Cannot Change After Creation
```
Once created with Object Lock:
- Cannot disable Object Lock ✗
- Cannot change mode (Governance ↔ Compliance) ✗
- Cannot reduce retention period (Compliance) ✗
- Versioning always enabled ✗
```

### ⚠️ Deletion Behavior
```
GOVERNANCE mode:
- Can delete with s3:BypassGovernanceRetention permission
- Can extend retention period
- Can add legal hold

COMPLIANCE mode:
- CANNOT delete until retention expires
- CANNOT reduce retention
- Can only extend retention
- Root account has no special privileges
```

### ⚠️ Lifecycle Rules
```
Lifecycle rules apply ONLY after retention period:
- Cannot delete object under retention
- Can transition storage class
- Expiration waits for retention to expire
```

## Uploading Objects with Retention
### Via AWS CLI

```bash
# Upload with retention
aws s3api put-object \
  --bucket my-locked-bucket \
  --key important-file.pdf \
  --body file.pdf \
  --object-lock-mode COMPLIANCE \
  --object-lock-retain-until-date 2031-01-01T00:00:00Z

# Upload with legal hold
aws s3api put-object \
  --bucket my-locked-bucket \
  --key legal-file.pdf \
  --body file.pdf \
  --object-lock-legal-hold-status ON
```

### Via SDK (Python)

```python
import boto3
from datetime import datetime, timedelta

s3 = boto3.client('s3')

# Calculate retention date (7 years)
retain_until = datetime.now() + timedelta(days=2555)

# Upload with object lock
s3.put_object(
    Bucket='my-locked-bucket',
    Key='record.pdf',
    Body=open('record.pdf', 'rb'),
    ObjectLockMode='COMPLIANCE',
    ObjectLockRetainUntilDate=retain_until
)
```

## Legal Hold
**Legal Hold** is separate from retention:

```
Object Lock Retention:
- Time-based
- Expires automatically
- Set at upload or after

Legal Hold:
- Not time-based
- Lasts until manually removed
- Can be added anytime
- Independent of retention
```

**Example:**
```bash
# Add legal hold
aws s3api put-object-legal-hold \
  --bucket my-bucket \
  --key document.pdf \
  --legal-hold Status=ON

# Remove legal hold (when legal case resolves)
aws s3api put-object-legal-hold \
  --bucket my-bucket \
  --key document.pdf \
  --legal-hold Status=OFF
```

## Compliance Mapping
### SEC 17a-4 (Securities & Exchange Commission)
**Requirement:** 
- 6 years retention for broker-dealers
- Must be non-rewriteable, non-erasable

**Our Implementation:**
```hcl
object_lock_mode = "COMPLIANCE"
retention_years  = 6
```

### FINRA 4511 (Financial Industry Regulatory Authority)
**Requirement:**
- 6 years retention for communications
- Immutable storage

**Our Implementation:**
```hcl
object_lock_mode = "COMPLIANCE"
retention_years  = 6
compliance_level = "FINRA4511"
```

### HIPAA (Healthcare)
**Requirement:**
- 6 years minimum retention
- Audit controls required

**Our Implementation:**
```hcl
object_lock_mode = "COMPLIANCE"
retention_years  = 6
enable_access_logging = true
enable_inventory = true
```

## Cost Considerations
**Object Lock itself: FREE**
Same cost as normal S3:
- Storage: Standard S3 rates
- Requests: Standard S3 rates
- Retrieval: Standard S3 rates

**Additional costs:**
- Versioning overhead (~10% more storage)
- Cannot delete (storage accumulates)
- Logging bucket storage

**Cost Optimization:**
```hcl
# Transition to cheaper storage after retention
lifecycle_rules = [
  {
    transitions = [
      { days = 2556, storage_class = "GLACIER" }
    ]
  }
]

# Result: 95% cost reduction after 7 years
# Standard: $0.023/GB/month
# Glacier: $0.004/GB/month
```

## Testing
### Test Governance Mode

```bash
# Upload file
aws s3 cp test.txt s3://my-bucket/

# Try to delete (should fail)
aws s3 rm s3://my-bucket/test.txt
# Error: Access Denied

# Delete with bypass (if you have permission)
aws s3api delete-object \
  --bucket my-bucket \
  --key test.txt \
  --bypass-governance-retention
# Success (Governance allows bypass)
```

### Test Compliance Mode
```bash
# Upload file
aws s3 cp test.txt s3://my-compliance-bucket/

# Try to delete (should fail)
aws s3 rm s3://my-compliance-bucket/test.txt
# Error: Access Denied

# Try with bypass (should still fail)
aws s3api delete-object \
  --bucket my-compliance-bucket \
  --key test.txt \
  --bypass-governance-retention
# Still fails! Compliance cannot be bypassed
```

## Monitoring
### CloudWatch Metrics
Track:
- Delete attempts (should be 0)
- Failed API calls (bypass attempts)
- Object count (growing only)
- Storage usage (increasing)

### Inventory Reports
Daily inventory includes:
- Object lock mode
- Retention date
- Legal hold status
- Current version

### Alarms
We create alarms for:
- Delete attempts (any)
- Lock bypass attempts
- Unusual API activity

## Troubleshooting
### Cannot delete bucket
**Error:** `BucketNotEmpty`
**Cause:** Objects under retention
**Solution:** Wait for retention to expire, or:
```bash
# For Governance mode only:
aws s3api delete-objects \
  --bucket my-bucket \
  --delete "$(aws s3api list-object-versions \
    --bucket my-bucket \
    --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)" \
  --bypass-governance-retention
```

### Cannot modify retention
**Error:** `AccessDenied`
**Cause:** Compliance mode locks retention
**Solution:** Cannot reduce. Can only extend.

## Migration Guide
### Adding Object Lock to Existing Bucket
**⚠️ CANNOT be done!**
Object Lock must be enabled at bucket creation.

**Workaround:**
1. Create new bucket with Object Lock
2. Copy objects to new bucket
3. Verify copies
4. Decommission old bucket

## Security Best Practices
✅ **Do:**
- Use COMPLIANCE for regulatory data
- Enable MFA delete
- Monitor deletion attempts
- Use lifecycle rules for cost
- Enable inventory tracking
- Set up CloudWatch alarms

❌ **Don't:**
- Use Object Lock for temporary data
- Forget about storage costs
- Set retention too long
- Use Governance for compliance data
- Disable logging

## Additional Resources
- [AWS Object Lock Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html)
- [SEC 17a-4 Compliance](https://www.sec.gov/rules/interp/2003/34-47806.htm)
- [FINRA 4511 Requirements](https://www.finra.org/rules-guidance/rulebooks/finra-rules/4511)

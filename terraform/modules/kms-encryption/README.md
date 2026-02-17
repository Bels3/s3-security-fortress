# KMS Encryption Module
## Overview
This module creates and manages AWS KMS Customer Managed Keys (CMKs) with security best practices built-in.

## Features
- ✅ **Automatic Key Rotation**: Keys rotate every 365 days
- ✅ **Fine-Grained Access Control**: Separate administrators and users
- ✅ **Service Integration**: S3, CloudTrail, CloudWatch Logs
- ✅ **Monitoring**: CloudWatch alarms for suspicious activity
- ✅ **Multi-Region Support**: Optional multi-region keys
- ✅ **Encryption Context**: Additional security layer
- ✅ **Deletion Protection**: 7-30 day recovery window

## Usage
### Basic Example

```hcl
module "kms_key" {
  source = "../../modules/kms-encryption"
  
  environment = "dev"
  purpose     = "s3"
  key_name    = "dev-s3-encryption-key"
  
  key_description = "KMS key for S3 bucket encryption in dev"
  
  # Enable automatic rotation
  enable_key_rotation = true
  
  # Key administrators (can manage but not use)
  key_administrators = [
    "arn:aws:iam::123456789012:role/DevOps"
  ]
  
  # Key users (can encrypt/decrypt)
  key_users = [
    "arn:aws:iam::123456789012:role/Application"
  ]
  
  tags = {
    Application = "MyApp"
    Owner       = "Platform Team"
  }
}
```

### Advanced Example with Monitoring
```hcl
module "kms_key_with_monitoring" {
  source = "../../modules/kms-encryption"
  
  environment = "prod"
  purpose     = "s3"
  key_name    = "prod-s3-encryption-key"
  
  # Security settings
  enable_key_rotation     = true
  deletion_window_in_days = 30
  multi_region            = true
  
  # Access control
  key_administrators = [
    "arn:aws:iam::123456789012:role/SecurityTeam",
    "arn:aws:iam::123456789012:role/DevOps"
  ]
  
  key_users = [
    "arn:aws:iam::123456789012:role/Application",
    "arn:aws:iam::123456789012:role/DataProcessing"
  ]
  
  # Service integration
  allow_cloudtrail      = true
  allow_cloudwatch_logs = true
  
  # Monitoring
  enable_monitoring = true
  alarm_sns_topic_arns = [
    "arn:aws:sns:us-east-1:123456789012:security-alerts"
  ]
  
  # Additional security
  deny_unencrypted_uploads = true
  
  tags = {
    Application    = "CriticalApp"
    Owner          = "Security Team"
    Compliance     = "SOC2"
    DataClassification = "Confidential"
  }
}
```

### With Encryption Context
```hcl
module "kms_key_with_context" {
  source = "../../modules/kms-encryption"
  
  environment = "prod"
  purpose     = "s3"
  
  # Require encryption context
  encryption_context_keys   = ["Environment"]
  encryption_context_values = ["Production"]
  
  key_administrators = [var.admin_role_arn]
  key_users          = [var.app_role_arn]
}
```

## Security Considerations
### Key Rotation

**Why it matters**: Regular key rotation limits the impact of a key compromise.

```hcl
enable_key_rotation = true  # Rotates every 365 days
```

AWS automatically:
- Creates new key material
- Keeps old material for decryption
- Uses new material for encryption

### Separation of Duties
**Administrators** can manage keys but NOT use them:
- Create/delete keys
- Modify key policies
- Enable/disable rotation

**Users** can use keys but NOT manage them:
- Encrypt data
- Decrypt data
- Generate data keys

```hcl
key_administrators = ["arn:aws:iam::ACCOUNT:role/Admins"]
key_users          = ["arn:aws:iam::ACCOUNT:role/Users"]
```

### Deletion Protection
30-day window prevents accidental deletion:

```hcl
deletion_window_in_days = 30  # 7-30 days allowed
```

If deleted accidentally:
1. Key enters "Pending Deletion" state
2. You have 30 days to cancel
3. After 30 days, key is permanently deleted

### Encryption Context
Additional security layer - requires matching context:

```hcl
encryption_context_keys   = ["Department", "Project"]
encryption_context_values = ["Engineering", "SecureStorage"]
```

**Benefits**:
- Additional authentication check
- Helps with audit trails
- Prevents unauthorized decryption

## Monitoring
### CloudWatch Alarms

The module creates alarms for:
- Key deletion attempts
- Key disabling attempts
- Unusual usage patterns

```hcl
enable_monitoring = true
alarm_sns_topic_arns = ["arn:aws:sns:REGION:ACCOUNT:alerts"]
```

### CloudTrail Integration
All key usage is logged to CloudTrail:
- Who accessed the key
- When it was accessed
- What operation was performed
- Source IP address

## Cost Optimization
### KMS Pricing
- **Key Storage**: $1/month per key
- **API Requests**: $0.03 per 10,000 requests
- **Free Tier**: 20,000 requests/month

### Recommendations
1. **Reuse keys** across similar resources
   ```hcl
   # One key for all dev S3 buckets
   purpose = "s3-dev-general"
   ```

2. **Use multi-region keys** sparingly
   ```hcl
   multi_region = false  # Default
   ```

3. **Monitor usage** to avoid unnecessary requests

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| purpose | Key purpose | string | - | yes |
| key_name | Friendly name | string | "" | no |
| enable_key_rotation | Enable rotation | bool | true | no |
| key_administrators | Admin ARNs | list(string) | [] | no |
| key_users | User ARNs | list(string) | [] | no |

## Outputs
| Name | Description |
|------|-------------|
| key_id | KMS key ID |
| key_arn | KMS key ARN |
| key_alias | Key alias name |

## Testing
Run the included tests:
```bash
cd tests/terraform/unit
go test -v -run TestKMSModule
```

## Compliance
This module implements:
- ✅ SOC 2 Type II controls
- ✅ HIPAA encryption requirements
- ✅ PCI-DSS key management
- ✅ GDPR data protection

## Troubleshooting
### Issue: "Access Denied" when using key

**Solution**: Check key policy and ensure principal is listed in `key_users`

### Issue: Key rotation not working
**Solution**: Rotation only works with AWS-generated key material

### Issue: High KMS costs
**Solution**: Check API request volume, consider caching data keys

## Additional Resources

- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [Key Policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)
- [Monitoring KMS Keys](https://docs.aws.amazon.com/kms/latest/developerguide/monitoring-overview.html)

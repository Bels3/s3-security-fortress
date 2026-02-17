# Secure S3 Bucket Module
## Overview
A production-ready, secure S3 bucket module with all AWS security best practices built-in.

## Features
### 🔐 Security Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Encryption at Rest** | ✅ Required | KMS or AES256 encryption |
| **Encryption in Transit** | ✅ Enforced | TLS 1.2+ only |
| **Versioning** | ✅ Enabled | Protects against deletion |
| **Public Access Block** | ✅ All 4 settings | Prevents public access |
| **Bucket Policies** | ✅ Enforced | SSL, encryption required |
| **Access Logging** | ✅ Optional | Track all requests |
| **MFA Delete** | ✅ Optional | Require 2FA for deletion |

### 📊 Cost Optimization
| Feature | Benefit | Status |
|---------|---------|--------|
| **S3 Bucket Keys** | 99% reduction in KMS costs | ✅ Enabled |
| **Lifecycle Rules** | Automatic tiering | ✅ Configurable |
| **Intelligent Tiering** | Auto cost optimization | ✅ Optional |
| **Log Expiration** | Auto-delete old logs | ✅ Enabled |

### 📈 Monitoring & Compliance
| Feature | Purpose | Status |
|---------|---------|--------|
| **CloudWatch Metrics** | Request monitoring | ✅ Optional |
| **S3 Inventory** | Compliance reporting | ✅ Optional |
| **Access Logs** | Audit trail | ✅ Optional |
| **Replication** | DR/compliance | ✅ Optional |

## Usage Examples
### Example 1: Basic Secure Bucket

```hcl
module "secure_bucket" {
  source = "../../modules/secure-s3-bucket"
  
  environment = "dev"
  purpose     = "application-data"
  
  # Security
  versioning_enabled = true
  
  # Encryption (using KMS from Phase 1)
  kms_master_key_id = module.kms_key.key_arn
  
  # Logging
  enable_access_logging = true
  
  tags = {
    Application = "MyApp"
    Owner       = "Platform Team"
  }
}
```

**Creates**:
- Encrypted S3 bucket with versioning
- Separate logging bucket
- All public access blocked
- SSL/TLS enforced
- CloudWatch metrics enabled

**Cost**: ~$1-2/month (depending on storage)

### Example 2: High-Security Bucket (Production)
```hcl
module "prod_secure_bucket" {
  source = "../../modules/secure-s3-bucket"
  
  environment         = "prod"
  purpose             = "customer-data"
  security_level      = "critical"
  data_classification = "restricted"
  
  # Versioning with MFA delete
  versioning_enabled  = true
  mfa_delete_enabled  = true  # Requires MFA for deletion
  
  # KMS encryption
  kms_master_key_id = module.kms_key.key_arn
  bucket_key_enabled = true  # Reduce KMS costs
  
  # Enforce encryption
  enforce_encryption_in_transit = true
  
  # All public access blocked
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  # Comprehensive logging
  enable_access_logging = true
  logging_retention_days = 365  # 1 year retention
  
  # Monitoring
  enable_metrics    = true
  enable_inventory  = true
  inventory_frequency = "Daily"
  
  # Lifecycle rules for cost optimization
  lifecycle_rules = [
    {
      id      = "transition-old-data"
      enabled = true
      
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
      
      noncurrent_version_expiration_days = 90
      abort_incomplete_multipart_upload_days = 7
    }
  ]
  
  tags = {
    Application      = "CustomerPortal"
    Compliance       = "SOC2,HIPAA"
    BackupSchedule   = "Daily"
    DataRetention    = "7years"
    DisasterRecovery = "Required"
  }
}
```

**Creates**:
- Maximum security configuration
- KMS encryption with bucket keys
- MFA delete protection
- Comprehensive logging (1 year)
- Intelligent lifecycle management
- Daily inventory reports
- CloudWatch metrics

**Cost**: ~$5-10/month + storage costs
### Example 3: Static Website Hosting (Public)

```hcl
module "website_bucket" {
  source = "../../modules/secure-s3-bucket"
  
  environment = "prod"
  purpose     = "website"
  
  # Public website requires different settings
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  
  # Still enforce SSL
  enforce_encryption_in_transit = true
  
  # Versioning for rollback
  versioning_enabled = true
  
  # CORS for web access
  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://example.com"]
      allowed_headers = ["*"]
      max_age_seconds = 3600
    }
  ]
  
  # Lifecycle for old versions
  lifecycle_rules = [
    {
      id      = "cleanup-old-versions"
      enabled = true
      noncurrent_version_expiration_days = 30
    }
  ]
  
  tags = {
    Purpose = "StaticWebsite"
  }
}

# Add bucket policy for public read
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = module.website_bucket.bucket_id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${module.website_bucket.bucket_arn}/*"
      }
    ]
  })
}
```

### Example 4: Cross-Region Replication
```hcl
# Primary bucket
module "primary_bucket" {
  source = "../../modules/secure-s3-bucket"
  
  environment = "prod"
  purpose     = "primary-data"
  
  versioning_enabled = true
  kms_master_key_id  = module.kms_key_us_east.key_arn
  
  # Enable replication
  enable_replication = true
  replication_role_arn = aws_iam_role.replication.arn
  replication_destination_bucket_arn = module.replica_bucket.bucket_arn
  replication_storage_class = "STANDARD_IA"
  replication_kms_key_id = module.kms_key_us_west.key_id
  
  tags = {
    ReplicationRole = "Primary"
  }
}

# Replica bucket (in different region)
module "replica_bucket" {
  source = "../../modules/secure-s3-bucket"
  
  providers = {
    aws = aws.us_west_2
  }
  
  environment = "prod"
  purpose     = "replica-data"
  
  versioning_enabled = true
  kms_master_key_id  = module.kms_key_us_west.key_arn
  
  tags = {
    ReplicationRole = "Replica"
  }
}
```

### Example 5: Logging & Compliance
```hcl
module "audit_logs_bucket" {
  source = "../../modules/secure-s3-bucket"
  
  environment         = "prod"
  purpose             = "audit-logs"
  security_level      = "critical"
  data_classification = "restricted"
  
  # Prevent any deletion
  versioning_enabled = true
  mfa_delete_enabled = true
  force_destroy      = false  # Cannot destroy bucket with objects
  
  # Lock down access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  # Encryption
  kms_master_key_id = module.kms_key.key_arn
  
  # Lifecycle - keep forever (or per compliance)
  lifecycle_rules = [
    {
      id      = "archive-old-logs"
      enabled = true
      
      transitions = [
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 2555  # 7 years
          storage_class = "DEEP_ARCHIVE"
        }
      ]
    }
  ]
  
  # Custom policy - only CloudTrail can write
  custom_bucket_policy_statements = [
    {
      sid    = "AWSCloudTrailWrite"
      effect = "Allow"
      actions = ["s3:PutObject"]
      resources = ["${module.audit_logs_bucket.bucket_arn}/*"]
      principals = [
        {
          type        = "Service"
          identifiers = ["cloudtrail.amazonaws.com"]
        }
      ]
      conditions = [
        {
          test     = "StringEquals"
          variable = "s3:x-amz-acl"
          values   = ["bucket-owner-full-control"]
        }
      ]
    }
  ]
  
  tags = {
    Purpose    = "AuditLogs"
    Compliance = "SOC2,HIPAA,PCI-DSS"
    Retention  = "7years"
  }
}
```

## Module Inputs
### Required Inputs
| Name | Type | Description |
|------|------|-------------|
| `environment` | string | Environment (dev, staging, prod) |
| `purpose` | string | Purpose of the bucket |

### Security Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `security_level` | string | "high" | Security level (standard, high, critical) |
| `data_classification` | string | "confidential" | Data classification |
| `versioning_enabled` | bool | true | Enable versioning |
| `mfa_delete_enabled` | bool | false | Require MFA for deletion |
| `kms_master_key_id` | string | "" | KMS key ARN (empty = AES256) |
| `bucket_key_enabled` | bool | true | Enable S3 Bucket Keys |
| `block_public_acls` | bool | true | Block public ACLs |
| `block_public_policy` | bool | true | Block public policies |
| `ignore_public_acls` | bool | true | Ignore public ACLs |
| `restrict_public_buckets` | bool | true | Restrict public buckets |

### Logging Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enable_access_logging` | bool | true | Enable access logging |
| `logging_bucket_name` | string | "" | Logging bucket (empty = create new) |
| `logging_retention_days` | number | 90 | Log retention period |

### Lifecycle Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `lifecycle_rules` | list(object) | [] | Lifecycle rules (see examples) |
| `enable_intelligent_tiering` | bool | false | Enable intelligent tiering |

### Monitoring Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enable_metrics` | bool | true | Enable CloudWatch metrics |
| `enable_inventory` | bool | false | Enable S3 inventory |

## Module Outputs
| Name | Description |
|------|-------------|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN |
| `bucket_domain_name` | Bucket domain name |
| `bucket_regional_domain_name` | Regional domain name |
| `versioning_status` | Versioning state |
| `encryption_algorithm` | Encryption algorithm used |
| `logging_bucket_id` | Logging bucket name |

## Security Best Practices
### ✅ Always Enable
1. **Versioning** - Protects against accidental deletion
2. **Encryption** - Protects data at rest
3. **SSL/TLS** - Protects data in transit
4. **Block Public Access** - Prevents accidental exposure
5. **Access Logging** - Creates audit trail

### ⚠️ Use With Caution
1. **MFA Delete** - Hard to disable, requires root account
2. **force_destroy** - Can lose data if bucket destroyed
3. **Public Access** - Only for truly public content

### 🔒 Production Requirements
1. **Use KMS encryption** (not AES256)
2. **Enable all 4 public access blocks**
3. **Enable access logging**
4. **Enable versioning**
5. **Set up lifecycle rules**
6. **Enable CloudWatch metrics**
7. **Tag all resources**
8. **Document data classification**

## Cost Optimization
### S3 Bucket Keys
Reduces KMS API calls by 99%:

```hcl
bucket_key_enabled = true
```

**Savings**: $0.03 per 10,000 objects → $0.0003 per 10,000 objects

### Lifecycle Rules
Automatically transition to cheaper storage:

```hcl
lifecycle_rules = [
  {
    transitions = [
      { days = 30, storage_class = "STANDARD_IA" },     # $0.0125/GB
      { days = 90, storage_class = "GLACIER" },         # $0.004/GB
      { days = 180, storage_class = "DEEP_ARCHIVE" }    # $0.00099/GB
    ]
  }
]
```

**Savings**: Up to 95% on storage costs

### Intelligent Tiering
Automatic optimization:

```hcl
enable_intelligent_tiering = true
```

**Cost**: $0.0025 per 1,000 objects + automatic savings

## Compliance Mappings
### SOC 2 Type II

- ✅ CC6.1: Encryption at rest and transit
- ✅ CC6.6: Access logging enabled
- ✅ CC6.7: Versioning for data recovery
- ✅ CC7.2: Block public access

### HIPAA
- ✅ 164.312(a)(2)(iv): Encryption at rest (KMS)
- ✅ 164.312(e)(1): Encryption in transit (TLS)
- ✅ 164.308(a)(1)(ii)(D): Access logging
- ✅ 164.312(c)(1): Data integrity (versioning)

### PCI-DSS
- ✅ 3.4: Encryption at rest
- ✅ 4.1: Encryption in transit
- ✅ 10.1: Audit logging
- ✅ 10.7: Log retention

## Troubleshooting
### Issue: Cannot enable MFA delete
**Error**: `InvalidRequest: MFA Delete can only be enabled by root account`

**Solution**:
```bash
# Must use root account credentials
aws s3api put-bucket-versioning \
  --bucket bucket-name \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::ACCOUNT:mfa/root-account-mfa-device MFACODE"
```

### Issue: Bucket policy too large
**Error**: `MalformedPolicy: Policy size exceeds 20KB`

**Solution**: Use IAM policies instead of bucket policies for complex permissions

### Issue: Replication not working
**Check**:
1. Versioning enabled on both buckets
2. Replication role has correct permissions
3. KMS key policy allows replication role

## Testing
### Basic Functionality Test
```bash
cd terraform/modules/secure-s3-bucket/examples/basic
terraform init
terraform apply

# Test upload
BUCKET=$(terraform output -raw bucket_id)
echo "test" > test.txt
aws s3 cp test.txt s3://$BUCKET/

# Verify encryption
aws s3api head-object --bucket $BUCKET --key test.txt

# Test versioning
aws s3 cp test.txt s3://$BUCKET/
aws s3api list-object-versions --bucket $BUCKET --prefix test.txt
```

### Security Validation
```bash
# Check encryption
aws s3api get-bucket-encryption --bucket $BUCKET

# Check versioning
aws s3api get-bucket-versioning --bucket $BUCKET

# Check public access block
aws s3api get-public-access-block --bucket $BUCKET

# Check bucket policy
aws s3api get-bucket-policy --bucket $BUCKET
```

## Additional Resources

- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingEncryption.html)
- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [S3 Lifecycle](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)

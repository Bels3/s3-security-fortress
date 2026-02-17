# S3 Access Points Module
## Overview
This module creates S3 Access Points with advanced network isolation and access control features.

## What are S3 Access Points?
Access Points are **dedicated entry points** to S3 buckets that:
- Have their own policies
- Can be VPC-restricted (private network only)
- Provide application-specific access patterns
- Simplify permission management

## Benefits
### 1. **Network Isolation**
```
Instead of:
Everyone → S3 Bucket (complex policies)

Use:
Finance Team → Finance Access Point (VPC-only) → S3 Bucket
Analytics → Analytics Access Point (Internet) → S3 Bucket
Uploads → Upload Access Point (VPC-only, write) → S3 Bucket
```

### 2. **Simplified Permissions**
```
Bucket Policy: 500 lines of complex conditions
    ↓
Access Point 1: 50 lines (finance rules)
Access Point 2: 50 lines (analytics rules)
Access Point 3: 50 lines (upload rules)
```

### 3. **Security**
- VPC-only access (no internet exposure)
- Dedicated policies per use case
- IP whitelisting
- MFA support

## Usage Examples

### Example 1: Basic Internet-Accessible Access Point

```hcl
module "public_access_point" {
  source = "../../modules/s3-access-points"
  
  environment = "prod"
  purpose     = "public-downloads"
  bucket_name = module.secure_bucket.bucket_id
  
  # Allow read-only access
  allowed_actions = [
    "s3:GetObject",
    "s3:ListBucket"
  ]
  
  # Security
  require_secure_transport = true
  block_public_acls        = true
  
  tags = {
    Application = "Downloads"
  }
}
```

### Example 2: VPC-Restricted Access Point

```hcl
module "private_access_point" {
  source = "../../modules/s3-access-points"
  
  environment = "prod"
  purpose     = "internal-data"
  bucket_name = module.secure_bucket.bucket_id
  
  # VPC restriction
  vpc_configuration = {
    vpc_id = aws_vpc.main.id
  }
  
  # Create VPC endpoint
  create_vpc_endpoint         = true
  vpc_endpoint_route_table_ids = [aws_route_table.private.id]
  
  # Allowed actions
  allowed_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket"
  ]
  
  # Only specific principals
  allowed_principals = [
    aws_iam_role.application.arn
  ]
  
  tags = {
    Network = "Private"
  }
}
```

### Example 3: Upload-Only Access Point

```hcl
module "upload_access_point" {
  source = "../../modules/s3-access-points"
  
  environment = "prod"
  purpose     = "user-uploads"
  bucket_name = module.secure_bucket.bucket_id
  
  # Write-only access
  allowed_actions = [
    "s3:PutObject"
  ]
  
  # Source IP whitelist
  source_ip_whitelist = [
    "203.0.113.0/24",  # Office network
    "198.51.100.0/24"  # DR site
  ]
  
  # Security
  require_secure_transport   = true
  deny_unencrypted_uploads   = true
  require_mfa                = true
  
  # Monitoring
  enable_monitoring          = true
  alarm_sns_topic_arns       = [aws_sns_topic.security.arn]
  
  tags = {
    Purpose = "UserUploads"
  }
}
```

### Example 4: Multi-Region Access Point

```hcl
module "global_access_point" {
  source = "../../modules/s3-access-points"
  
  environment = "prod"
  purpose     = "global-assets"
  bucket_name = module.primary_bucket.bucket_id
  
  # Multi-region configuration
  create_multi_region_access_point = true
  multi_region_buckets = [
    module.us_east_bucket.bucket_id,
    module.eu_west_bucket.bucket_id,
    module.ap_southeast_bucket.bucket_id
  ]
  
  # Security
  block_public_acls    = true
  block_public_policy  = true
  
  tags = {
    Scope = "Global"
  }
}
```

### Example 5: Role-Based Access

```hcl
# Finance team access point
module "finance_ap" {
  source = "../../modules/s3-access-points"
  
  environment = "prod"
  purpose     = "finance-reports"
  bucket_name = module.data_lake.bucket_id
  
  vpc_configuration = {
    vpc_id = aws_vpc.main.id
  }
  
  allowed_principals = [
    aws_iam_role.finance_analysts.arn
  ]
  
  allowed_actions = [
    "s3:GetObject",
    "s3:ListBucket"
  ]
  
  # Custom policy for prefix restrictions
  custom_policy_statements = [
    {
      sid    = "RestrictToFinancePrefix"
      effect = "Allow"
      actions = ["s3:GetObject"]
      resources = [
        "arn:aws:s3:*:*:accesspoint/*/object/finance/*"
      ]
      principals = [
        {
          type        = "AWS"
          identifiers = [aws_iam_role.finance_analysts.arn]
        }
      ]
    }
  ]
}

# Analytics team access point
module "analytics_ap" {
  source = "../../modules/s3-access-points"
  
  environment = "prod"
  purpose     = "analytics-data"
  bucket_name = module.data_lake.bucket_id
  
  vpc_configuration = {
    vpc_id = aws_vpc.main.id
  }
  
  allowed_principals = [
    aws_iam_role.data_scientists.arn
  ]
  
  allowed_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket"
  ]
}
```

## How to Use Access Points
### Accessing via AWS CLI
```bash
# Standard S3 access
aws s3 cp file.txt s3://my-bucket/file.txt

# Access Point access
aws s3 cp file.txt s3://arn:aws:s3:us-east-1:123456789012:accesspoint/my-access-point/file.txt

# Using alias
aws s3 cp file.txt s3://my-access-point-alias/file.txt
```

### Accessing via SDK (Python)
```python
import boto3

s3 = boto3.client('s3')

# Upload via access point
s3.put_object(
    Bucket='arn:aws:s3:us-east-1:123456789012:accesspoint/my-access-point',
    Key='file.txt',
    Body=b'file contents'
)

# Download via access point
response = s3.get_object(
    Bucket='arn:aws:s3:us-east-1:123456789012:accesspoint/my-access-point',
    Key='file.txt'
)
```

## Architecture Patterns
### Pattern 1: Application Isolation
```
┌─────────────┐
│  S3 Bucket  │
└──────┬──────┘
       │
       ├─ Access Point: app-1-uploads (VPC-A only)
       ├─ Access Point: app-2-downloads (VPC-B only)
       └─ Access Point: analytics (VPC-C only)
```

### Pattern 2: Environment Separation
```
┌─────────────┐
│  S3 Bucket  │
└──────┬──────┘
       │
       ├─ Access Point: dev-access (Dev VPC)
       ├─ Access Point: staging-access (Staging VPC)
       └─ Access Point: prod-access (Prod VPC)
```

### Pattern 3: Permission Tiers
```
┌─────────────┐
│  S3 Bucket  │
└──────┬──────┘
       │
       ├─ Access Point: read-only (Get operations)
       ├─ Access Point: read-write (Get + Put)
       └─ Access Point: admin (All operations)
```

## Security Best Practices

### 1. VPC Restriction

```hcl
# Always use VPC for sensitive data
vpc_configuration = {
  vpc_id = aws_vpc.main.id
}

create_vpc_endpoint = true
```

### 2. Least Privilege

```hcl
# Grant minimum needed permissions
allowed_actions = [
  "s3:GetObject"  # Only read, no write
]
```

### 3. IP Whitelisting

```hcl
# Restrict to known sources
source_ip_whitelist = [
  "10.0.0.0/8"  # Corporate network only
]
```

### 4. Encryption Enforcement

```hcl
# Deny unencrypted uploads
deny_unencrypted_uploads = true
require_secure_transport = true
```

### 5. Monitoring

```hcl
# Alert on suspicious activity
enable_monitoring = true
unauthorized_access_threshold = 5
```

## Cost Considerations

### Access Point Costs

| Item | Cost |
|------|------|
| Access Point | **FREE** |
| Data transfer | Same as S3 |
| Requests | Same as S3 |
| VPC Endpoint | ~$7/month |

**Key Points:**
- Access Points themselves are free
- Only pay for S3 usage (same as without)
- VPC endpoints have minimal cost (~$0.01/hour)
- No performance penalty

## Monitoring & Troubleshooting
### CloudWatch Metrics

Available metrics:
- `AllRequests` - Total requests
- `GetRequests` - GET operations
- `PutRequests` - PUT operations
- `4xxErrors` - Client errors
- `5xxErrors` - Server errors

### Troubleshooting
**Issue: Access Denied**

```bash
# Check access point policy
aws s3control get-access-point-policy \
  --account-id 123456789012 \
  --name my-access-point

# Check bucket policy
aws s3api get-bucket-policy --bucket my-bucket

# Check IAM permissions
aws iam get-role-policy \
  --role-name my-role \
  --policy-name my-policy
```

**Issue: VPC Access Not Working**
```bash
# Verify VPC endpoint
aws ec2 describe-vpc-endpoints

# Check route tables
aws ec2 describe-route-tables

# Test from EC2 in VPC
aws s3 ls s3://arn:aws:s3:*:*:accesspoint/my-ap/
```

## Compliance
Access Points help with:

**SOC 2:**
- CC6.6: Network segmentation
- CC6.7: Access restrictions

**HIPAA:**
- 164.312(a)(2)(ii): Network isolation
- 164.308(a)(4)(ii)(A): Access controls

**PCI-DSS:**
- 1.3: Network segmentation
- 7.1: Access restrictions

## Migration Guide

### Migrating from Bucket Policies

**Before (Bucket Policy):**
```json
{
  "Statement": [
    {"Effect": "Allow", "Principal": "App1", "Action": "s3:GetObject"},
    {"Effect": "Allow", "Principal": "App2", "Action": "s3:PutObject"},
    {"Effect": "Allow", "Principal": "App3", "Action": "s3:*"}
  ]
}
```

**After (Access Points):**
```hcl
# Access Point for App1
module "app1_ap" {
  allowed_actions = ["s3:GetObject"]
  allowed_principals = ["App1"]
}

# Access Point for App2
module "app2_ap" {
  allowed_actions = ["s3:PutObject"]
  allowed_principals = ["App2"]
}

# Access Point for App3
module "app3_ap" {
  allowed_actions = ["s3:*"]
  allowed_principals = ["App3"]
}
```

## Additional Resources

- [AWS Access Points Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points.html)
- [VPC Endpoints for S3](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)
- [Multi-Region Access Points](https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPoints.html)

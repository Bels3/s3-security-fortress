## Terraform Backend Setup
This directory contains the infrastructure for storing Terraform state files securely.

### What Gets Created
1. **S3 Bucket** - Stores terraform.tfstate files
   - Versioning enabled (recover from mistakes)
   - Encryption enabled (AES256)
   - Public access blocked
   - Lifecycle policies (cost optimization)

2. **S3 Bucket (Logs)** - Stores access logs
   - Separate bucket for security
   - Lifecycle management
   - Encrypted

3. **DynamoDB Table** - State locking
   - Prevents concurrent modifications
   - Point-in-time recovery
   - Encrypted at rest

4. **IAM Policy** - Access control
   - Least privilege permissions
   - Can be attached to users/roles

### Prerequisites
- AWS CLI configured with credentials
- Terraform >= 1.6.0
- Appropriate AWS permissions (S3, DynamoDB, IAM)

### Initial Setup
**Step 1: Create terraform.tfvars**
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set a **globally unique** bucket name:

```hcl
state_bucket_name = "mycompany-tf-state-2024"  # Change this!
aws_region        = "us-east-1"
```

**Step 2: Initialize and Apply**
```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create the backend infrastructure
terraform apply
```

**Step 3: Save the Outputs**
```bash
terraform output -json > backend-config.json
```

### Using This Backend
After setup, add this to your Terraform configurations:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-state-bucket-name"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### Important Notes
⚠️ **State File Security**
- Never commit .tfstate files to git
- State files contain sensitive data (IPs, credentials, etc.)
- Always use encryption
- Restrict access via IAM policies

⚠️ **Prevent Destruction**
- Backend resources have `prevent_destroy = true`
- This protects against accidental deletion
- To delete, manually remove this lifecycle rule first

⚠️ **Team Access**
- Attach the generated IAM policy to your team members
- Consider using IAM roles instead of user credentials
- Enable MFA for production access

### Cost Estimation
**Monthly Costs:**
- S3 Storage: ~$0.10-$1.00 (for state files, very small)
- DynamoDB: ~$0.00 (pay-per-request, minimal usage)
- Data Transfer: ~$0.00 (minimal)

**Total: < $1/month**

### Troubleshooting
**Problem: Bucket name already exists**
```
Error: Error creating S3 bucket: BucketAlreadyExists
```
**Solution**: Change `state_bucket_name` to something unique

**Problem: Insufficient permissions**
```
Error: Error creating DynamoDB table: AccessDeniedException
```
**Solution**: Ensure your AWS credentials have:
- s3:CreateBucket
- dynamodb:CreateTable
- iam:CreatePolicy

**Problem: State locking fails**
```
Error: Error acquiring the state lock
```
**Solution**: 
1. Check DynamoDB table exists
2. Verify table name in backend config
3. Ensure IAM permissions for DynamoDB

### Maintenance
**Rotating Credentials:**
```bash
# Update AWS credentials
aws configure

# Re-initialize Terraform
terraform init -reconfigure
```

**Viewing State Versions:**
```bash
aws s3api list-object-versions \
  --bucket your-state-bucket-name \
  --prefix environments/dev/terraform.tfstate
```

**Recovering from State Issues:**
```bash
# List versions
aws s3api list-object-versions --bucket BUCKET --prefix KEY

# Restore specific version
aws s3api get-object \
  --bucket BUCKET \
  --key KEY \
  --version-id VERSION_ID \
  terraform.tfstate
```

### Security Best Practices
✅ **Implemented:**
- Encryption at rest (AES256)
- Versioning enabled
- Public access blocked
- Access logging enabled
- State locking via DynamoDB
- Lifecycle policies for cost control

✅ **Recommended:**
- Enable MFA delete (manual step required)
- Use IAM roles instead of access keys
- Implement SCPs for additional protection
- Regular access reviews
- Automated backup to separate region

### Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/backends/types/s3.html)
- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [State Locking](https://www.terraform.io/docs/state/locking.html)
